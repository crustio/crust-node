const _ = require('lodash')
const { getSharedChainConfigForKarst } = require('./chain-config.gen')

async function genKarstConfig(config, outputCfg) {
  const karstConfig = {
    base_path: '/opt/crust/data/karst',
    port: 17000,
    debug: true,
    crust: getSharedChainConfigForKarst(config),
    sworker: {
      base_url: `127.0.0.1:12222`
    },
    file_system: {
      fastdfs: {
        tracker_addrs: config.karst.tracker_addrs,
        outer_tracker_addrs: config.karst.outer_tracker_addrs
      },
      ipfs: {
        base_url: "",
        outer_base_url: ""
      }
    }
  }
  const basePaths = [{
    required: true,
    path: '/opt/crust/data/karst',
  }]
  return {
    config: karstConfig,
    paths: [...basePaths],
  }
}

async function genKarstComposeConfig(config) {
  const basePath = '/opt/crust/data/karst'
  const baseVolume =[ `${basePath}:${basePath}` ]

  return {
    image: 'crustio/karst:latest',
    network_mode: 'host',
    volumes: [
      ...baseVolume,
      './karst:/config'
    ],
    environment: {
      KARST_PATH: basePath,
      INIT_ARGS: '-c /config/karst_config.json'
    },
  }
}

module.exports = {
  genKarstConfig,
  genKarstComposeConfig,
}
