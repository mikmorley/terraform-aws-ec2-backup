const { 
    EC2Client, 
    DescribeInstancesCommand,
    CreateImageCommand,
    DescribeImagesCommand,
    DeregisterImageCommand,
    DescribeSnapshotsCommand,
    DeleteSnapshotCommand
} = require('@aws-sdk/client-ec2');

const { 
    CloudWatchClient, 
    PutMetricDataCommand 
} = require('@aws-sdk/client-cloudwatch');

const ec2 = new EC2Client({});
const cloudWatch = new CloudWatchClient({});
const helpers = require('aws-lambda-nodejs-helpers');
const config = helpers.getConfig(process.env, [
    'backup_tag',
    'backup_retention',
]);
const image_date_tag = "BackupDate";

let backup_instances_arr = [];
let image_deletion_arr = [];

// Metrics tracking
let metrics = {
    backupsAttempted: 0,
    backupsSuccessful: 0,
    backupsFailed: 0,
    amisCreated: 0,
    amis: 0,
    snapshotsDeleted: 0,
    errors: []
};

exports.handler = handler;
async function handler(event, context) {
    const startTime = Date.now();
    
    try {
        console.log('Starting AMI backup process...');
        
        // Reset metrics for this execution
        metrics = {
            backupsAttempted: 0,
            backupsSuccessful: 0,
            backupsFailed: 0,
            amisCreated: 0,
            amisDeleted: 0,
            snapshotsDeleted: 0,
            errors: []
        };

        // Get instances and save to array
        console.log('Discovering instances to backup...');
        await getInstanceDetails(config.backup_tag);
        console.log(`Found ${backup_instances_arr.length} instances to backup`);

        // If array is not empty, create AMI snapshots
        if (backup_instances_arr.length > 0) {
            metrics.backupsAttempted = backup_instances_arr.length;
            await createAMISnapshots();
        }

        // Get existing images and save to array
        console.log('Checking for AMIs to clean up...');
        await getAMIDetails();
        console.log(`Found ${image_deletion_arr.length} AMIs to evaluate for cleanup`);

        // If array is not empty, analyse images to determine if retention time has passed.
        if (image_deletion_arr.length > 0) {
            for (let i = 0; i < image_deletion_arr.length; i++) {
                let days_since_backup = dateDiff(image_deletion_arr[i].image_backup_date);
                if (days_since_backup > config.backup_retention) {
                    let image_id = image_deletion_arr[i].image_id;
                    let image_name = image_deletion_arr[i].image_name;
                    let image_backup_date = image_deletion_arr[i].image_backup_date;
                    console.log(`Retention time has passed for: ${image_name} (${days_since_backup} days old)`);
                    await deleteBackup(image_id, image_name, image_backup_date);
                }
            }
        }

        // Publish success metrics
        const duration = Date.now() - startTime;
        await publishMetrics(duration, true);
        
        console.log('AMI backup process completed successfully');
        console.log(`Summary: ${metrics.backupsSuccessful}/${metrics.backupsAttempted} backups successful, ${metrics.amisCreated} AMIs created, ${metrics.amisDeleted} AMIs deleted, ${metrics.snapshotsDeleted} snapshots deleted`);
        
        return {
            statusCode: 200,
            body: {
                message: 'Backup process completed successfully',
                metrics: metrics
            }
        };

    } catch (error) {
        console.error('AMI backup process failed:', error);
        metrics.errors.push(error.message);
        
        // Publish failure metrics
        const duration = Date.now() - startTime;
        await publishMetrics(duration, false);
        
        // Re-throw the error so Lambda marks the execution as failed
        throw error;
    }
}

async function deleteBackup(image_id, image_name, image_backup_date) {
    try {
        // Remove AMI
        const deregisterCommand = new DeregisterImageCommand({
            ImageId: image_id
        });
        let remove_ami = await ec2.send(deregisterCommand);
        console.log(`AMI deregistered successfully: ${image_id}`);
        metrics.amisDeleted++;

        // Identify Associated Snapshots
        const describeSnapshotsCommand = new DescribeSnapshotsCommand({
            Filters: [
                {
                    Name: "tag:Name",
                    Values: [image_name]
                },
                {
                    Name: "tag:BackupDate", 
                    Values: [image_backup_date]
                }
            ]
        });
        let describe_snapshots = await ec2.send(describeSnapshotsCommand);
        console.log(`Found ${describe_snapshots.Snapshots.length} snapshots to delete`);

        // Delete Snapshot(s)
        for (let i = 0; i < describe_snapshots.Snapshots.length; i++) {
            let snapshot_id = describe_snapshots.Snapshots[i].SnapshotId;
            const deleteSnapshotCommand = new DeleteSnapshotCommand({
                SnapshotId: snapshot_id
            });
            let delete_snapshot = await ec2.send(deleteSnapshotCommand);
            console.log(`Snapshot deleted successfully: ${snapshot_id}`);
            metrics.snapshotsDeleted++;
        }

        return "Done";
    } catch (error) {
        console.error(`Error deleting backup ${image_name}:`, error);
        metrics.errors.push(`Failed to delete backup ${image_name}: ${error.message}`);
        throw error;
    }
}

async function getInstanceDetails(backup_tag) {

    const describeInstancesCommand = new DescribeInstancesCommand({
        Filters: [
            {
                Name: "tag:" + backup_tag,
                Values: ["yes"]
            }
        ]
    });
    let instance_details = await ec2.send(describeInstancesCommand);

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
            try {
                const createImageCommand = new CreateImageCommand(params);
                let create_image = await ec2.send(createImageCommand);
                console.log(`AMI created successfully: ${create_image.ImageId} for instance ${instance_id}`);
                metrics.amisCreated++;
                metrics.backupsSuccessful++;
            } catch (error) {
                console.error(`Failed to create AMI for instance ${instance_id}:`, error);
                metrics.backupsFailed++;
                metrics.errors.push(`Failed to create AMI for ${instance_name}: ${error.message}`);
                // Continue with other instances rather than failing completely
            }
        } else {
            console.log(`AMI already exists for ${instance_name}, skipping`);
            metrics.backupsSuccessful++; // Count as successful since backup exists
        }

    }

    return "Done";
}

async function checkAMIExists(image_name) {

    const describeImagesCommand = new DescribeImagesCommand({
        Filters: [
            {
                Name: 'name',
                Values: [image_name]
            },
        ],
    });
    let image_exists = await ec2.send(describeImagesCommand);

    return image_exists.Images;
}

async function getAMIDetails() {

    const describeImagesCommand = new DescribeImagesCommand({
        Filters: [
            {
                Name: 'tag-key',
                Values: [
                    config.backup_tag,
                    image_date_tag
                ]
            }
        ],
    });
    let amis = await ec2.send(describeImagesCommand);

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

async function publishMetrics(duration, success) {
    try {
        const namespace = 'AWS/Lambda/AMIBackup';
        const timestamp = new Date();
        
        const metricData = [
            {
                MetricName: 'ExecutionDuration',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: duration,
                Unit: 'Milliseconds',
                Timestamp: timestamp
            },
            {
                MetricName: 'BackupsAttempted',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.backupsAttempted,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'BackupsSuccessful',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.backupsSuccessful,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'BackupsFailed',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.backupsFailed,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'AMIsCreated',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.amisCreated,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'AMIsDeleted',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.amisDeleted,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'SnapshotsDeleted',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: metrics.snapshotsDeleted,
                Unit: 'Count',
                Timestamp: timestamp
            },
            {
                MetricName: 'ExecutionSuccess',
                Dimensions: [
                    { Name: 'FunctionName', Value: process.env.AWS_LAMBDA_FUNCTION_NAME || 'ami-backup' }
                ],
                Value: success ? 1 : 0,
                Unit: 'Count',
                Timestamp: timestamp
            }
        ];

        const command = new PutMetricDataCommand({
            Namespace: namespace,
            MetricData: metricData
        });

        await cloudWatch.send(command);
        console.log('Custom metrics published successfully');
        
    } catch (error) {
        console.error('Failed to publish custom metrics:', error);
        // Don't throw error here as metrics publishing failure shouldn't fail the backup
    }
}
