const _ = require('lodash')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genSworkerConfig(config, outputCfg) {
  const sworkerConfig = {
    srd_paths: [
      "/opt/crust/data/files/srd"
    ],
    srd_init_capacity: 1,
    base_path: `/opt/crust/data/sworker`,
    base_url: `http://0.0.0.0:12222/api/v0`,
    chain: getSharedChainConfig(config),
  }
  return {
    config: sworkerConfig,
    paths: [{
      required: true,
      path: '/opt/crust/data/sworker',
    }, {
      required: true,
      path: '/opt/crust/data/files/srd',
    }],
  }
}

async function genSworkerComposeConfig(config) {
  let tempVolumes = [
    '/opt/crust/data/sworker:/opt/crust/data/sworker',
    '/opt/crust/data/files/srd:/opt/crust/data/files/srd',
    './sworker:/config'
  ]

  return {
    image: 'crustio/crust-sworker:latest',
    network_mode: 'host',
    devices: [
      '/dev/isgx:/dev/isgx'
    ],
    volumes: tempVolumes,
    environment: {
      ARGS: '-c /config/sworker_config.json --debug $EX_SWORKER_ARGS',
    },
  }
}

module.exports = {
  genSworkerConfig,
  genSworkerComposeConfig,
}
