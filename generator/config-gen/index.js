/**
 * config generators
 */
const path = require('path')
const { createDir, writeConfig, } = require('../utils')
const { genApiConfig, genApiComposeConfig } = require('./api-config.gen')
const { genChainConfig, genChainComposeConfig } = require('./chain-config.gen')
const { genKarstConfig, genKarstComposeConfig } = require('./karst-config.gen')
const { genSworkerConfig, genSworkerComposeConfig } = require('./sworker-config.gen')
const { logger } = require('../logger')

/**
 * configuration of generators to use
 * name: the generator name
 *
 * async configFun(config, outputOptions) => {file, paths}
 * file: the result filename
 * paths: an array of files/directories should be verified later
 *    required: boolean whether this file is a mandontary requirement
 *    path: the file path
 *
 * composeName: the compose service name of this generator
 * async composeFunc(config) => composeConfig
 * return the service definition for this generator
 */
const configGenerators = [{
  name: 'chain',
  configFunc: genChainConfig,
  to: path.join('chain', 'chain_config.json'),
  composeName: 'crust',
  composeFunc: genChainComposeConfig,
}, {
  name: 'api',
  configFunc: genApiConfig,
  to: path.join('api', 'api_config.json'),
  composeName: 'crust-api',
  composeFunc: genApiComposeConfig,
},{
  name: 'sworker',
  configFunc: genSworkerConfig,
  to: path.join('sworker', 'sworker_config.json'),
  composeName: 'crust-sworker',
  composeFunc: genSworkerComposeConfig,
}, {
  name: 'karst',
  configFunc: genKarstConfig,
  to: path.join('karst', 'karst_config.json'),
  composeName: 'karst',
  composeFunc: genKarstComposeConfig,
}]

async function genConfig(config, outputOpts) {
  //
  // application config generation
  let outputs = []
  const { baseDir } = outputOpts
  for (const cg of configGenerators) {
    logger.info('generating config for %s', cg.name)
    const ret = await cg.configFunc(config, outputOpts)
    await writeConfig(path.join(baseDir, cg.to), ret.config)
    outputs.push({
      generator: cg.name,
      ...ret,
    })
  }
  logger.info('done generating application configs')
  return outputs
}

async function genComposeConfig(config) {
  //
  // docker compose config generation
  let output = {
    version: '2.0',
    services: {},
  }

  for (const cg of configGenerators) {
    logger.info('generating compose config for %s', cg.name)
    const cfg = await cg.composeFunc(config)
    output = {
      ...output,
      services: {
        ...output.services,
        [cg.composeName]: cfg,
      }
    }
  }

  logger.info('done generating compose configs')
  return output
}

module.exports = {
  genConfig,
  genComposeConfig,
}
