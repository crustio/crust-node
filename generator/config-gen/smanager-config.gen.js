async function genSmanagerConfig(config, outputCfg) {
    const smanagerConfig = {
      chain: {
        account: config.identity.backup.address,
        endPoint: config.api.ws
      },
      sworker: {
        endPoint: "http://127.0.0.1:12222"
      },
      ipfs: {
        endPoint: "http://127.0.0.1:5001"
      },
      node: {
        role: config.node.smanager
      },
      telemetry: {
        endPoint: "https://sm-submit.crust.network"
      },
      dataDir: "/data",
      scheduler: {
        minSrdRatio: 30,
        strategy: {
          existedFilesWeight: 0,
          newFilesWeight: 100
        }
      }
    }
  
    return {
      config: smanagerConfig,
      paths: [{
        required: true,
        path: '/opt/crust/data/smanager',
      }],
    }
  }
  
  async function genSmanagerComposeConfig(config) {
    return {
      image: 'crustio/crust-smanager:latest',
      network_mode: 'host',
      restart: 'unless-stopped',
      environment: {
        SMANAGER_CONFIG: "/config/smanager_config.json",
      },
      volumes: [
        './smanager:/config',
        '/opt/crust/data/smanager:/data'
      ],
      logging: {
        driver: "json-file",
        options: {
          "max-size": "500m"
        }
      },
    }
  }
  
  module.exports = {
    genSmanagerConfig,
    genSmanagerComposeConfig,
  }
  
