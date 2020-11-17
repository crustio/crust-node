async function genSmanagerConfig(config, outputCfg) {
    const smanagerConfig = {
      chain_addr: 'ws://127.0.0.1:19944',
      ipfs_addr: 'http://127.0.0.1:5001',
      sworker_addr: 'http://127.0.0.1:12222',
    }
    return {
      config: smanagerConfig,
      paths: [],
    }
  }
  
  async function genSmanagerComposeConfig(config) {
    const args = [
      'ws://127.0.0.1:19944',
      'http://127.0.0.1:5001',
      'http://127.0.0.1:12222',
    ].join(' ')
    return {
      image: 'crustio/crust-smanager:latest',
      network_mode: 'host',
      restart: 'always',
      environment: {
        ARGS: args,
      }
    }
  }
  
  module.exports = {
    genSmanagerConfig,
    genSmanagerComposeConfig,
  }
  