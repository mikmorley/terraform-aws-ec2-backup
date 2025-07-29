module.exports = {
  env: {
    node: true,
    es2020: true,
    jest: true
  },
  extends: [
    'eslint:recommended'
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module'
  },
  rules: {
    // Code quality rules
    'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    'no-console': 'off', // Allow console.log in Lambda functions
    'prefer-const': 'error',
    'no-var': 'error',
    
    // Best practices
    'eqeqeq': 'error',
    'curly': 'error',
    'no-eval': 'error',
    'no-implied-eval': 'error',
    
    // Style rules
    'indent': ['error', 4],
    'quotes': ['error', 'single', { avoidEscape: true }],
    'semi': ['error', 'always'],
    'comma-dangle': ['error', 'never'],
    
    // AWS Lambda specific
    'no-process-exit': 'off', // Allow process.exit in Lambda
    'no-sync': 'off' // Allow sync operations in Lambda
  },
  globals: {
    // AWS Lambda globals
    'exports': 'readonly',
    'module': 'readonly',
    'require': 'readonly',
    'process': 'readonly',
    '__dirname': 'readonly',
    '__filename': 'readonly',
    'Buffer': 'readonly',
    'global': 'readonly'
  }
};