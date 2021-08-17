import jwt # https://github.com/jpadilla/pyjwt/

import sys
sys.path.append('/app')

import logger
log = logger.build(__name__)

from config import fetchApproovSecret
APPROOV_SECRET = fetchApproovSecret()

def generateResponse(is_valid, approov_token_claims):
    return {
        "isAuthorized": is_valid,
        "context": {
          "approovTokenClaims": approov_token_claims
        }
    }

# @link https://approov.io/docs/latest/approov-usage-documentation/#backend-integration
def verifyJwtToken(approov_token):
    if not APPROOV_SECRET:
        log.critical('An unauthorized response will be sent due to the missing Approov Secret.')
        return None

    try:
        #Verify with the HS256 algorithm to prevent the algorithm None attack.
        approov_token_claims = jwt.decode(approov_token, APPROOV_SECRET, algorithms=['HS256'])
        return approov_token_claims
    except jwt.ExpiredSignatureError as e:
        log.info('Approov Token Verification: token has expired.')
        return None
    except jwt.InvalidTokenError as e:
        log.info(f'Approov Token Verification: {e}')
        return None

def handler(event, context):
    if not event['headers'] or not event['headers']['approov-token']:
        log.info('Missing the `Approov-Token` header in the request.')
        return generateResponse(False, None)

    approov_token_claims = verifyJwtToken(event['headers']['approov-token'])

    if approov_token_claims:
        return generateResponse(True, approov_token_claims)

    return generateResponse(False, None)
