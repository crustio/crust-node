const _ = require('lodash')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genSworkerConfig(config, outputCfg) {
  const sworkerConfig = {
    ..._.omit(config.sworker, ['port']),
    base_path: `/opt/crust/data/sworker`,
    base_url: `http://0.0.0.0:12222/api/v0`,
    karst_url: `ws://127.0.0.1:17000/api/v0/node/data`,
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
      path: '/opt/crust/data/sworker',
    }, ...srdPaths],
  }
}

async function genSworkerComposeConfig(config) {
  const srdVolumes = _.get(config, 'sworker.srd_paths', [])
        .map((p) => `${p}:${p}`)

  let tempVolumes = [
    '/opt/crust/data/sworker:/opt/crust/data/sworker',
    ...srdVolumes,
    './sworker:/config',
    '/opt/crust/data/karst:/opt/crust/data/karst'
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
