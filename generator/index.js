
const _ = require('lodash')
const fs = require('fs-extra')
const path = require('path')
const yaml = require('js-yaml')
const { genConfig, genComposeConfig } = require('./config-gen')
const { getConfigSchema } = require('./schema')
const { validate } = require('./config-validator')
const { logger } = require('./logger')
const { inspectKey } = require('./key-utils')
const { writeYaml } = require('./utils')

console.log('crust config generator')

async function loadConfig(file) {
  logger.debug('loading config file: %s', file)
  const c = await fs.readFile('config.yaml', 'utf8')
  const config = yaml.safeLoad(c)
  const configSchema = getConfigSchema(config)
  const value = await configSchema.validateAsync(config, {
    allowUnknown: true,
    stripUnknown: true,
  })

  if (value.node.sworker == "enable") {
    const keyInfo = await inspectKey(value.identity.backup.address)
    value.identity.account_id = keyInfo.accountId
  }

  const data = await genConfig(value, {
    baseDir: '.tmp',
  })
  const composeConfig = await genComposeConfig(value)
  await writeYaml(path.join('.tmp','docker-compose.yaml'), composeConfig)
  await dumpConfigPaths(path.join('.tmp', '.paths'), data)
}

async function dumpConfigPaths(toFile, data) {
  const paths = _(data).map(d => _.get(d, 'paths', [])).flatten().map(p => {
    let mark = '|'
    if (p.required) {
      mark = '+'
    }
    return `${mark} ${p.path}`
  }).uniq()
  logger.debug('paths to validate', paths.value())

  await fs.outputFile(toFile, paths.join('\n'))
}

function getConfigFileName() {
  const args = process.argv.slice(2);
  if (args.length >= 1) {
    return args[0]
  }
  return 'config.yaml'
}

async function main(){
  try {
    await loadConfig(getConfigFileName())
  } catch(e) {
    logger.error('failed to load config: %o', e)
    process.exit(1)
  }
}

main()
