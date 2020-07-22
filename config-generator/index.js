
const fs = require('fs-extra')
const yaml = require('js-yaml')
const { configSchema } = require('./schema')
const { validate } = require('./config-validator')
const { logger } = require('./logger')

console.log('crust config generator')

async function loadConfig(file) {
  logger.debug('loading config file: %s', file)
  const c = await fs.readFile('config.yaml', 'utf8')
  const config = yaml.safeLoad(c)
  const value = await configSchema.validateAsync(config, {
    allowUnknown: true,
  })
  logger.debug('got config: %o', value)
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
  }
}

main()
