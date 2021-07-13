const log = require('./logger')
const AWS = require('aws-sdk')

const fecthFromEnv = function(envVarName, defaultValue = "") {
  return process.env[envVarName] || defaultValue
}

// @link https://docs.aws.amazon.com/code-samples/latest/catalog/javascript-secrets-secrets_getsecretvalue.js.html
// @link https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/setting-credentials-node.htmldk
const fetchFromAwsSecretManager = function(secretName) {
  const client = new AWS.SecretsManager();

  const response = client.getSecretValue({SecretId: secretName}, function(err, data) {
    if (err) {
      log.error('AWS SECRET MANAGER ERROR: ' + err.toString())
      return ""
    }

    return data
  }).promise()

  return response.then(data => {
    if ('SecretString' in data) {
      return data.SecretString
    }

    // This may happen when the token is not created via the AWS CLI.
    log.error('AWS SECRET MANAGER: the secret is missing in the response key `SecretString`')
    return ""
  }).catch(err => {
    log.error('AWS SECRET MANAGER ERROR: unknown secret ' + secretName)
    return ""
  })
}

const fetchApproovBase64Secret = function(secretName) {
  switch(fecthFromEnv('APPROOV_BASE64_SECRET_STORAGE')) {
    case 'ENV_VAR':
      storage = 'ENV_VAR'
      log.debug('The Approov Base64 Secret is being fetched from an environment variable.')
      return fecthFromEnv(secretName)
      break
    default:
      log.debug('The Approov Base64 Secret is being fetched from the AWS Secret Manager')
      return fetchFromAwsSecretManager(secretName)
  }
}

const fetchApproovSecret = async function() {
  const approovSecret = await fetchApproovBase64Secret('APPROOV_BASE64_SECRET')

  if (!approovSecret) {
    return
  }

  return Buffer.from(approovSecret, 'base64')
}

exports.APPROOV_SECRET = fetchApproovSecret()
