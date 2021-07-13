const jwt = require('jsonwebtoken')
const log = require('./logger')
const config = require('./config')

const generateResponse = function(isValid, tokenClaims = "") {
  return {
    isAuthorized: isValid,
    context: {
      approovTokenClaims: tokenClaims
    }
  }
}

// @link https://approov.io/docs/latest/approov-usage-documentation/#backend-integration
const verifyJwtToken = async function(approovToken) {
  const approovSecret = await config.APPROOV_SECRET

  if (!approovSecret) {
    log.error('An unauthorized response will be sent due to the missing Approov Secret.')
    return ""
  }

  // Verify with the HS256 algorithm to prevent the algorithm None attack.
  return jwt.verify(approovToken, approovSecret, { algorithms: ['HS256'] }, function(err, tokenClaims) {
    if (err) {
      log.info('JWT VERIFY FAILURE: ' + err.toString())
      return ""
    }

    return tokenClaims
  })
}

exports.handler = async function(event, context, callback) {
  if (!event.headers || !event.headers['approov-token']) {
    log.info('The Approov Token header is missing or is empty.')
    return callback(null, generateResponse(false))
  }

  const approovTokenClaims = await verifyJwtToken(event.headers['approov-token'])

  if (approovTokenClaims) {
    return callback(null, generateResponse(true, approovTokenClaims))
  }

  return callback(null, generateResponse(false))
}
