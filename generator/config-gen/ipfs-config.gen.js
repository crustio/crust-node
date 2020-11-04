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
    network_mode: 'host',
    volumes: [
      '/opt/crust/data/ipfs:/data/ipfs'
    ],
    entrypoint: '/sbin/tini --',
    command: '/bin/sh -c "if [ ! -e \'/data/ipfs/config\' ]; then ipfs init; ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/37773; fi && /usr/local/bin/start_ipfs daemon --migrate=true"',
  }
}

module.exports = {
  genIpfsConfig,
  genIpfsComposeConfig,
}
