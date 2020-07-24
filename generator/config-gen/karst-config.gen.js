const _ = require('lodash')
const { getSharedChainConfigForKarst } = require('./chain-config.gen')

async function genKarstConfig(config, outputCfg) {
  const karstConfig = {
    base_path: config.karst.base_path,
    base_url: `0.0.0.0:${config.karst.port}`,
    crust: getSharedChainConfigForKarst(config),
    fastdfs: {
      max_conns: 100,
      tracker_addrs: config.karst.tracker_addrs,
    },
    log_level: 'debug',
    tee_base_url: `127.0.0.1:${config.sworker.port}/api/v0`,
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
    image: 'crustio/karst:0.2.0',
    network_mode: 'host',
    volumes: [
      ...baseVolume,
      './karst:/config'
    ],
    environment: {
      KARST_PATH: basePath,
      INIT_ARGS: '-c /config/karst_config.json'
    },
    container_name: 'karst-0.2.0',
    restart: 'always',
  }
}

module.exports = {
  genKarstConfig,
  genKarstComposeConfig,
}
