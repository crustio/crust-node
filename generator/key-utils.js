const _ = require('lodash')
const execa = require('execa')
const { logger } = require('./logger')

async function inspectKey(address) {
  const keyTool = process.env['KEY_TOOL']
  if (!keyTool) {
    throw 'key tool path not specified'
  }
	const {stdout} = await execa(keyTool, ['inspect', address]);

  const rows = _.chain(stdout).split('\n').map(_.trim)
  const accountId = extractAccountId(rows)
  if (!accountId) {
    logger.warn('Invalid address: %s!', address)
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
