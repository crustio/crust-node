async function genIpfsConfig(config, outputCfg) {
  const ipfsConfig = {
    swarm_port: 4001,
    api_port: 5001,
    gateway_port: 37773,
    path: '/opt/crust/data/files/ipfs'
  }
  return {
    config: ipfsConfig,
    paths: [{
      required: true,
      path: '/opt/crust/data/files/ipfs',
    }],
  }
}

async function genIpfsComposeConfig(config) {
  return {
    image: 'ipfs/go-ipfs:latest',
    network_mode: 'host',
    volumes: [
      '/opt/crust/data/files/ipfs:/data/ipfs'
    ],
    entrypoint: '/sbin/tini --',
    environment: {
      IPFS_PROFILE: 'badgerds',
    },
    command: '/bin/sh -c "/usr/local/bin/start_ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/37773 && /usr/local/bin/start_ipfs daemon --migrate=true"',
  }
}

module.exports = {
  genIpfsConfig,
  genIpfsComposeConfig,
}
