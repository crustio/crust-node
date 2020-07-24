const _ = require('lodash')
const execa = require('execa')
const { logger } = require('./logger')

async function inspectKey(address) {
  const keyTool = process.env['KEY_TOOL']
  if (!keyTool) {
    throw 'key tool path not specified'
  }
  logger.info('checking identity information, using keytool: %s', keyTool)
	const {stdout} = await execa(keyTool, ['inspect', address]);
  logger.debug('keytool output: %s', stdout)

  const rows = _.chain(stdout).split('\n').map(_.trim)
  const accountId = extractAccountId(rows)
  logger.info('accountId: %s', accountId)
  if (!accountId) {
    logger.warn('invalid address: %s!', address)
    throw `address is invalid ${address}`
  }
  return {
    address,
    accountId,
  }
}

function extractAccountId(outputs) {
  const accountIdPrefix = 'Account ID:'
  const ids = outputs.filter(v =>_.startsWith(v, accountIdPrefix)).map(v => v.substr(accountIdPrefix.length)).map(_.trim).value()
  if (_.isEmpty(ids)) {
    return null
  }

  return ids[0]
}


module.exports = {
  inspectKey,
}
