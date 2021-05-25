async function genIpfsConfig(config, outputCfg) {
  const ipfsConfig = {
    swarm_port: 4001,
    api_port: 5001,
    gateway_port: 37773,
    path: '/opt/crust/data/ipfs'
  }
  return {
    config: ipfsConfig,
    paths: [{
      required: true,
      path: '/opt/crust/data/ipfs',
    }],
  }
}

async function genIpfsComposeConfig(config) {
  return {
    image: 'crustio/go-ipfs:latest',
    network_mode: 'host',
    restart: 'always',
    volumes: [
      '/opt/crust/data/ipfs:/data/ipfs'
    ],
    entrypoint: '/sbin/tini --',
    environment: {
      IPFS_PROFILE: 'badgerds',
    },
    command: '/bin/sh -c "/usr/local/bin/start_ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/37773 && /usr/local/bin/start_ipfs config Datastore.StorageMax 50000GB && /usr/local/bin/start_ipfs bootstrap add /ip4/101.33.32.103/tcp/4001/p2p/12D3KooWEVFe1uGbgsDCgt9GV5sAC864RNPPDJLTnX9phoWHuV2d && /usr/local/bin/start_ipfs daemon --migrate=true"',
  }
}

module.exports = {
  genIpfsConfig,
  genIpfsComposeConfig,
}
