async function genIpfsConfig(config, outputCfg) {
  const ipfsConfig = {
    swarm_port: 4001,
    api_port: 5001,
    gateway_port: 37773,
  }
  return {
    config: ipfsConfig,
    paths: [],
  }
}

async function genIpfsComposeConfig(config) {
  return {
    image: 'ipfs/go-ipfs:latest',
    ports: [
      '4001:4001',
      '5001:5001',
      '37773:8080',
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
