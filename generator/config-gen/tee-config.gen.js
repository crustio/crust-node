const _ = require('lodash')
const { createDir, writeConfig, } = require('../utils')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genTeeConfig(config, outputCfg) {
  const teeConfig = {
    ..._.omit(config.tee, ['port']),
    base_url: `http://0.0.0.0:${config.tee.port}/api/v0`,
    karst_url: `ws://127.0.0.1:${config.karst.port}/api/v0/node/data`,
    chain: getSharedChainConfig(config),
  }
  const srdPaths = _.map(config.tee.srdPaths, (p) => ({
    required: true,
    path: p,
  }))
  return {
    config: teeConfig,
    paths: [{
      required: true,
      path: config.tee.base_path,
    }, ...srdPaths],
  }
}

async function genTeeComposeConfig(config) {
  const srdVolumes = _.get(config, 'tee.srd_paths', [])
        .map((p) => `${p}:${p}`)

  let tempVolumes = [
    `${config.tee.base_path}:${config.tee.base_path}`,
    ...srdVolumes,
    './tee:/config'
  ]

  if (config.karst.base_path) {
    tempVolumes.push(`${config.karst.base_path}:${config.karst.base_path}`)
  }

  return {
    image: 'crustio/crust-tee:0.5.0',
    network_mode: 'host',
    devices: [
      '/dev/isgx:/dev/isgx'
    ],
    volumes: tempVolumes,
    environment: {
      ARGS: '-c /config/tee_config.json --debug',
    },
    container_name: 'crust-tee-0.5.0',
    restart: 'always',
  }
}

module.exports = {
  genTeeConfig,
  genTeeComposeConfig,
}
