import base64
import boto3
from botocore.exceptions import ClientError

from os import getenv
APPROOV_BASE64_SECRET_STORAGE = getenv('APPROOV_BASE64_SECRET_STORAGE')

import sys
sys.path.append('/app')

import logger
log = logger.build(__name__)


def fetchFromAwsSecretManager(secret_name):
    secretsmanager_client = boto3.client('secretsmanager')

    try:
        response = secretsmanager_client.get_secret_value(SecretId=secret_name)

        if not response['SecretString']:
            # This may happen when the token is not created via the AWS CLI.
            log.error('AWS Secrets Manager: the secret is missing in the response key `SecretString`')
            return None

        return response['SecretString']

    except ClientError:
        log.error(f'AWS Secrets Manager: unknown secret {secret_name}')
        return None

def fetchApproovBase64Secret(secret_name):
    if APPROOV_BASE64_SECRET_STORAGE == "ENV_VAR":
        log.debug('The Approov Base64 Secret is being fetched from an environment variable.')
        return getenv(secret_name)

    log.debug('The Approov Base64 Secret is being fetched from the AWS Secret Manager')
    return fetchFromAwsSecretManager(secret_name)

def fetchApproovSecret():
    approov_base64_secret = fetchApproovBase64Secret('APPROOV_BASE64_SECRET')

    if approov_base64_secret == None:
        return None

    return base64.b64decode(approov_base64_secret)

# APPROOV_SECRET = fetchApproovSecret()
