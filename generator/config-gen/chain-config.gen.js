const path = require('path')
const shell = require('shelljs')
const { createDir, writeConfig, } = require('../utils')

async function genChainConfig(config, outputCfg) {
  const { baseDir } = outputCfg
  const outputDir = path.join(baseDir, 'chain')
  await createDir(outputDir)

  const outputFile = path.join(outputDir, 'chain_config.json')
  const chainConfig = config.chain
  await writeConfig(outputFile, chainConfig)
  return {
    file: outputFile,
    paths: [{
      required: true,
      path: config.chain.base_path,
    }],
  }
}

async function genChainComposeConfig(config) {
  const args = [
    '--base-path /home/crust/crust/chain',
    '--chain rocky',
    '--validator',
    `--port ${config.chain.port}`,
    `--name ${config.chain.name}`,
    `--rpc-port ${config.chain.rpc_port}`,
    `--ws-port ${config.chain.ws_port}`,
    '--pruning archive'
  ].join(' ')
  return {
    image: 'crustio/crust:0.6.0',
    network_mode: 'host',
    volumes: [
      `${config.chain.base_path}:/home/crust/crust/chain`
    ],
    environment: {
      ARGS: args,
    },
    container_name: 'crust-0.6.0',
    restart: 'always',
  }
}

function getSharedChainConfig(config) {
  return {
    ...config.identity,
    base_url: `http://127.0.0.1:${config.api.port}/api/v1`,
    address: config.identity.backup.address,
    account_id: config.identity.account_id,
    backup: JSON.stringify(config.identity.backup),
  }
}

module.exports = {
  genChainConfig,
  genChainComposeConfig,
  getSharedChainConfig,
}
