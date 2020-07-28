
async function genChainConfig(config, outputCfg) {
  const chainConfig = config.chain
  return {
    config: chainConfig,
    paths: [{
      required: true,
      path: config.chain.base_path,
    }],
  }
}

async function genChainComposeConfig(config) {
  const args = [
    `--base-path ${config.chain.base_path}`,
    '--chain maxwell',
    '--validator',
    `--port ${config.chain.port}`,
    `--name ${config.chain.name}`,
    `--rpc-port ${config.chain.rpc_port}`,
    `--ws-port ${config.chain.ws_port}`,
    '--pruning archive'
  ].join(' ')
  return {
    image: 'crustio/crust:0.7.0',
    network_mode: 'host',
    volumes: [
      `${config.chain.base_path}:${config.chain.base_path}`
    ],
    environment: {
      ARGS: args,
    },
    container_name: 'crust-0.7.0',
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

function getSharedChainConfigForKarst(config) {
  return {
    ...config.identity,
    base_url: `127.0.0.1:${config.api.port}/api/v1`,
    address: config.identity.backup.address,
    backup: JSON.stringify(config.identity.backup),
  }
}

module.exports = {
  genChainConfig,
  genChainComposeConfig,
  getSharedChainConfig,
  getSharedChainConfigForKarst,
}
