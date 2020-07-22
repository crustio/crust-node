const _ = require('lodash')
const path = require('path')
const shell = require('shelljs')
const { createDir, writeConfig, } = require('../utils')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genTeeConfig(config, outputCfg) {
  const { baseDir } = outputCfg
  const outputDir = path.join(baseDir, 'tee')
  await createDir(outputDir)

  const outputFile = path.join(outputDir, 'tee_config.json')
  const teeConfig = {
    ...config.tee,
    karst_url: `ws://127.0.0.1:${config.karst.port}/api/v0/node/data`,
    chain: getSharedChainConfig(config),
  }
  await writeConfig(outputFile, teeConfig)
  const srdPaths = _.map(config.tee.srdPaths, (p) => ({
    required: true,
    path: p,
  }))
  return {
    file: outputFile,
    paths: [{
      required: true,
      path: config.tee.base_path,
    }, ...srdPaths],
  }
}

async function genTeeComposeConfig(config) {
  const srdVolumes = _.get(config, 'tee.srd_paths', [])
        .map((p) => `${p}:${p}`)

  return {
    image: 'crustio/crust-tee:0.5.0',
    network_mode: 'host',
    devices: [
      '/dev/isgx:/dev/isgx'
    ],
    volumes: [
      `${config.tee.base_path}:${config.tee.base_path}`,
      ...srdVolumes,
      './tee:/config'
    ],
    environment: {
      ARGS: '-c /config/tee_config.json, --debug',
    },
    container_name: 'crust-tee-0.5.0',
    restart: 'always',
  }
}

module.exports = {
  genTeeConfig,
  genTeeComposeConfig,
}
