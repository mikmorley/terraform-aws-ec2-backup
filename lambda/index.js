const aws = require('aws-sdk');
const ec2 = new aws.EC2();
const helpers = require('aws-lambda-nodejs-helpers');
const config = helpers.getConfig(process.env, [
    'backup_tag',
    'backup_retention',
]);
const image_date_tag = "BackupDate";

let backup_instances_arr = [];
let image_deletion_arr = [];

exports.handler = handler;
async function handler(event, context) {

    // Get instances and save to array
    await getInstanceDetails(config.backup_tag);

    // If array is not empty, create AMI snapshots
    if (backup_instances_arr.length > 0) {
        await createAMISnapshots();
    }

    // Get existing images and save to array
    await getAMIDetails();

    // If array is not empty, analyse images to determine if retention time has passed.
    if (image_deletion_arr.length > 0) {

        for (let i = 0; i < image_deletion_arr.length; i++) {
            let days_since_backup = dateDiff(image_deletion_arr[i].image_backup_date);
            if (days_since_backup > config.backup_retention) {
                let image_id = image_deletion_arr[i].image_id;
                let image_name = image_deletion_arr[i].image_name;
                let image_backup_date = image_deletion_arr[i].image_backup_date;
                console.log("Retention time has passed for:", image_name);
                await deleteBackup(image_id, image_name, image_backup_date);
            }
        }
    }

}

async function deleteBackup(image_id, image_name, image_backup_date) {

    // Remove AMI
    let ami_params = {
        ImageId: image_id
    };
    let remove_ami = await ec2.deregisterImage(ami_params).promise();
    console.log("remove_ami", remove_ami);

    // Identify Associated Snapshots
    let snapshot_params = {
        Filters: [
            {
                Name: "tag:Name",
                Values: [
                    image_name
                ]
            },
            {
                Name: "tag:BackupDate",
                Values: [
                    image_backup_date
                ]
            }
        ]
    };
    let describe_snapshots = await ec2.describeSnapshots(snapshot_params).promise();
    console.log("describe_snapshots", describe_snapshots);

    // Delete Snapshot(s)
    for (let i = 0; i < describe_snapshots.Snapshots.length; i++) {
        let snapshot_id = describe_snapshots.Snapshots[i].SnapshotId;
        let delete_snapshot_params = {
            SnapshotId: snapshot_id
        };
        let delete_snapshot = await ec2.deleteSnapshot(delete_snapshot_params).promise();
        console.log("delete_snapshot", delete_snapshot);
    }

    return "Done";
}

async function getInstanceDetails(backup_tag) {

    let params = {
        Filters: [
            {
                Name: "tag:" + backup_tag,
                Values: ["yes"]
            }
        ]
    };
    let instance_details = await ec2.describeInstances(params).promise();

    for (let i = 0; i < instance_details.Reservations.length; i++) {

        let instances = instance_details.Reservations[i].Instances;

        for (let j = 0; j < instances.length; j++) {

            let instance_id = instances[j].InstanceId;
            let instance_tags = instances[j].Tags;
            let instance_name = "";

            for (let k = 0; k < instance_tags.length; k++) {
                if (instance_tags[k].Key == "Name") {
                    instance_name = instance_tags[k].Value;
                }
            }

            backup_instances_arr.push(
                {
                    "InstanceId": instance_id,
                    "InstanceName": instance_name
                }
            );
        }
    }

    return "Done";
}

async function createAMISnapshots() {

    for (let i = 0; i < backup_instances_arr.length; i++) {

        let instance_id = backup_instances_arr[i].InstanceId;
        let instance_name = backup_instances_arr[i].InstanceName;
        let instance_id_suffix = instance_id.substr(instance_id.length - 4);
        let full_date_now = new Date().toISOString();
        let date_now = yyyymmdd();
        let image_name = instance_name + "-" + instance_id_suffix + "-" + date_now;

        let params = {
            InstanceId: instance_id,
            Description: "AMI Backup of " + instance_id,
            Name: image_name,
            NoReboot: true,
            TagSpecifications: [
                {
                    ResourceType: 'image',
                    Tags: [
                        {
                            Key: 'Name',
                            Value: instance_name
                        },
                        {
                            Key: image_date_tag,
                            Value: full_date_now
                        },
                        {
                            Key: 'BackupInstanceId',
                            Value: instance_id
                        }
                    ]
                },
                {
                    ResourceType: 'snapshot',
                    Tags: [
                        {
                            Key: 'Name',
                            Value: image_name
                        },
                        {
                            Key: image_date_tag,
                            Value: full_date_now
                        },
                        {
                            Key: 'BackupInstanceId',
                            Value: instance_id
                        }
                    ]
                }
            ]
        };

        // If image already exists, skip.
        let image_exist_check = await checkAMIExists(image_name);
        if (image_exist_check.length < 1) {
            let create_image = await ec2.createImage(params).promise();
            console.log(create_image);
        }

    }

    return "Done";
}

async function checkAMIExists(image_name) {

    let params = {
        Filters: [
            {
                Name: 'name',
                Values: [image_name]
            },
        ],
    };
    let image_exists = await ec2.describeImages(params).promise();

    return image_exists.Images;
}

async function getAMIDetails() {

    let params = {
        Filters: [
            {
                Name: 'tag-key',
                Values: [
                    config.backup_tag,
                    image_date_tag
                ]
            }
        ],
    };
    let amis = await ec2.describeImages(params).promise();

    for (let i = 0; i < amis.Images.length; i++) {

        let image_id = amis.Images[i].ImageId;
        let image_name = amis.Images[i].Name;
        let image_tags = amis.Images[i].Tags;
        let image_backup_date = "";

        for (let j = 0; j < image_tags.length; j++) {
            if (image_tags[j].Key == image_date_tag) {
                image_backup_date = image_tags[j].Value
            }
        }

        // Add to array
        image_deletion_arr.push(
            {
                "image_id": image_id,
                "image_name": image_name,
                "image_backup_date": image_backup_date
            }
        )
    }

    return "Done"
}

function yyyymmdd() {

    let now = new Date();
    let y = now.getFullYear();
    let m = now.getMonth() + 1;
    let d = now.getDate();
    let hrs = now.getHours();
    let min = now.getMinutes();
    let sec = now.getSeconds();

    return '' + y + (m < 10 ? '0' : '') + m + (d < 10 ? '0' : '') + d + (hrs < 10 ? '0' : '') + hrs + (min < 10 ? '0' : '') + min;
}

function dateDiff(date_string) {

    // Referrence:
    // one day = 1000*60*60*24
    // one hour = 1000*60*60
    // one minute = 1000*60
    // one second = 1000

    let date1 = new Date();
    let date2 = new Date(date_string);
    let diffDays = parseInt((date1 - date2) / (1000 * 60 * 60 * 24));
    console.log("diffDays", diffDays);

    return diffDays;
}
