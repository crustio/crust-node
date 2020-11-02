async function genIpfsConfig(config, outputCfg) {
  const ipfsConfig = {
    swarm_port: 4001,
    api_port: 5001,
    gateway_port: 18081,
  }
  return {
    config: apiConfig,
    paths: [],
  }
}

async function genIpfsComposeConfig(config) {
  return {
    image: 'ipfs/go-ipfs:latest',
    ports: [
      `${config.ipfs.swarm_port}:4001`,
      `${config.ipfs.api_port}:5001`,
      `${config.ipfs.gateway_port}:8080`,
    ],
    volumes: [
      '/opt/crust/data/ipfs:/data/ipfs'
    ]
  }
}

module.exports = {
  genIpfsConfig,
  genIpfsComposeConfig,
}
