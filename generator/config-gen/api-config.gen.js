
async function genApiConfig(config, outputCfg) {
  const apiConfig = {
    ...config.api,
    chain_ws_url: `ws://127.0.0.1:${config.chain.ws_port}`,
  }
  return {
    config: apiConfig,
    paths: [],
  }
}

async function genApiComposeConfig(config) {
  const args = [
    `${config.api.port}`,
    `ws://127.0.0.1:${config.chain.ws_port}`,
  ].join(' ')
  return {
    image: 'crustio/crust-api:latest',
    network_mode: 'host',
    environment: {
      ARGS: args,
    },
    depends_on: crust,
  }
}

module.exports = {
  genApiConfig,
  genApiComposeConfig,
}
