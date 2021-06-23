const _ = require('lodash')
const { getSharedChainConfig } = require('./chain-config.gen')

async function genSworkerConfig(config, outputCfg) {
  var dataPaths = []

  for (i = 1; i <= 128; i++) {
    dataPaths.push("/opt/crust/disks/" + i)
  }

  const sworkerConfig = {
    base_path: "/opt/crust/data/sworker",
    base_url: "http://127.0.0.1:12222/api/v0",
    chain: getSharedChainConfig(config),
    data_path: dataPaths,
    ipfs_url: "http://127.0.0.1:5001/api/v0",
  }
  return {
    config: sworkerConfig,
    paths: [{
      required: true,
      path: '/opt/crust/data/sworker',
    }, {
      required: true,
      path: '/opt/crust/disks',
    }],
  }
}

async function genSworkerComposeConfig(config) {
  let tempVolumes = [
    '/opt/crust/data/sworker:/opt/crust/data/sworker',
    '/opt/crust/disks:/opt/crust/disks',
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
    logging: {
      driver: "json-file",
      options: {
        "max-size": "500m"
      }
    },
  }
}

module.exports = {
  genSworkerConfig,
  genSworkerComposeConfig,
}
