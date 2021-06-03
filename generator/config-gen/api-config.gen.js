async function genApiConfig(config, outputCfg) {
  const apiConfig = {
    port: 56666,
    chain_ws_url: config.api.ws,
  }
  return {
    config: apiConfig,
    paths: [],
  }
}

async function genApiComposeConfig(config) {
  const args = [
    '56666',
    `${config.api.ws}`,
  ].join(' ')
  return {
    image: 'crustio/crust-api:latest',
    network_mode: 'host',
    restart: 'always',
    environment: {
      ARGS: args,
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
  genApiConfig,
  genApiComposeConfig,
}
