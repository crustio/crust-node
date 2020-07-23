
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
    image: 'crustio/crust-api:0.5.0',
    network_mode: 'host',
    environment: {
      ARGS: args,
    },
    container_name: 'crust-api-0.5.0',
    restart: 'always',
  }
}

module.exports = {
  genApiConfig,
  genApiComposeConfig,
}
