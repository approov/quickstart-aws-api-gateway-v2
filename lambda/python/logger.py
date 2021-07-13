import logging

from os import getenv
LOG_LEVEL = getenv('LAMBDA_LOG_LEVEL', 'ERROR')

def build(name):
    log = logging.getLogger(__name__)
    log.setLevel(getattr(logging, LOG_LEVEL))
    return log

