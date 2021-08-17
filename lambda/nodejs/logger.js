const LOG_LEVEL = {
  DEBUG: 10,
  INFO: 20,
  WARN: 30,
  ERROR: 40
}

const LAMBDA_LOG_LEVEL = process.env.LAMBDA_LOG_LEVEL || 'ERROR'

const log = function(level, message) {

  if (LOG_LEVEL[level] < LOG_LEVEL[LAMBDA_LOG_LEVEL]) {
    return
  }

  switch(level) {
    case 'DEBUG':
      console.debug(message)
      break
    case 'INFO':
      console.info(message)
      break
    case 'WARN':
      console.warn(message)
      break
    case 'ERROR':
      console.error(message)
      break
  }
}

exports.debug = function(message) {
  log('DEBUG', message)
}

exports.info = function(message) {
  log('INFO', message)
}

exports.warn = function(message) {
  log('WARN', message)
}

exports.error = function(message) {
  log('ERROR', message)
}
