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
  let args = [
    './crust',
    '--base-path',
    '/opt/crust/data/chain',
    '--chain',
    'maxwell',
    '--port',
    `${config.chain.port}`,
    '--name',
    `${config.chain.name}`,
    '--rpc-port',
    '19933',
    '--ws-port',
    '19944',
    '--wasm-execution',
    'compiled',
    '--in-peers',
    '75',
    '--out-peers',
    '75'
  ]

  if (config.node.chain == "authority") {
    args.push('--validator', '--pruning', 'archive')
  }

  if (config.node.chain == "full") {
    args.push('--no-telemetry', '--pruning', '8000')
  }

  return {
    image: 'crustio/crust:latest',
    network_mode: 'host',
    volumes: [
      '/opt/crust/data/chain:/opt/crust/data/chain'
    ],
    command: args,
    logging: {
      driver: "json-file",
      options: {
        "max-size": "500m"
      }
    },
  }
}

function getSharedChainConfig(config) {
  return {
    ...config.identity,
    base_url: `http://127.0.0.1:56666/api/v1`,
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
