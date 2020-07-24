const _ = require('lodash')
const { createDir, writeConfig, } = require('../utils')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genSworkerConfig(config, outputCfg) {
  const sworkerConfig = {
    ..._.omit(config.sworker, ['port']),
    base_url: `http://0.0.0.0:${config.sworker.port}/api/v0`,
    karst_url: `ws://127.0.0.1:${config.karst.port}/api/v0/node/data`,
    chain: getSharedChainConfig(config),
  }
  const srdPaths = _.map(config.sworker.srdPaths, (p) => ({
    required: true,
    path: p,
  }))
  return {
    config: sworkerConfig,
    paths: [{
      required: true,
      path: config.sworker.base_path,
    }, ...srdPaths],
  }
}

async function genSworkerComposeConfig(config) {
  const srdVolumes = _.get(config, 'sworker.srd_paths', [])
        .map((p) => `${p}:${p}`)

  let tempVolumes = [
    `${config.sworker.base_path}:${config.sworker.base_path}`,
    ...srdVolumes,
    './sworker:/config'
  ]

  if (config.karst.base_path) {
    tempVolumes.push(`${config.karst.base_path}:${config.karst.base_path}`)
  }

  return {
    image: 'crustio/crust-sworker:0.5.0',
    network_mode: 'host',
    devices: [
      '/dev/isgx:/dev/isgx'
    ],
    volumes: tempVolumes,
    environment: {
      ARGS: '-c /config/sworker_config.json --debug',
    },
    container_name: 'crust-sworker-0.5.0',
    restart: 'always',
  }
}

module.exports = {
  genSworkerConfig,
  genSworkerComposeConfig,
}
