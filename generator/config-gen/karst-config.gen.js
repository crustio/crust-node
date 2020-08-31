const _ = require('lodash')
const { getSharedChainConfigForKarst } = require('./chain-config.gen')

async function genKarstConfig(config, outputCfg) {
  const karstConfig = {
    base_path: config.karst.base_path,
    port: config.karst.port,
    debug: true,
    crust: getSharedChainConfigForKarst(config),
    sworker: {
      base_url: `127.0.0.1:${config.sworker.port}`
    },
    file_system: {
      fastdfs: {
        tracker_addrs: config.karst.tracker_addrs
      },
      ipfs: {
        base_url: ""
      }
    }
  }
  const basePaths = _.isEmpty(config.karst.base_path) ? [] : [{
    required: true,
    path: config.karst.base_path,
  }]
  return {
    config: karstConfig,
    paths: [...basePaths],
  }
}

async function genKarstComposeConfig(config) {
  const basePath = _.isEmpty(config.karst.base_path) ? '/home/crust/crust/karst' : config.karst.base_path
  const baseVolume = _.isEmpty(config.karst.base_path) ? [] : [ `${basePath}:${basePath}` ]

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
