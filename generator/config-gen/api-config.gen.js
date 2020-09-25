
async function genApiConfig(config, outputCfg) {
  const apiConfig = {
    port: 56666,
    chain_ws_url: `ws://127.0.0.1:${config.chain.ws_port}`,
  }
  return {
    config: apiConfig,
    paths: [],
  }
}

async function genApiComposeConfig(config) {
  const args = [
    '56666',
    `ws://127.0.0.1:19944`,
  ].join(' ')
  return {
    image: 'crustio/crust-api:latest',
    network_mode: 'host',
    environment: {
      ARGS: args,
    }
  }
}

module.exports = {
  genApiConfig,
  genApiComposeConfig,
}
