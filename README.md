# Crust node
Official crust node service for running crust protocol.

## Preparation work
- Hardware requirements: 

  CPU must contain **SGX module**, and make sure the SGX function is turned on in the bios, please click [this page](https://github.com/crustio/crust/wiki/Check-TEE-supportive) to check if your machine supports SGX

- Operating system requirements:

  Ubuntu 16.04/18.04/20.04
  
- Other configurations

  - **Secure Boot** in BIOS needs to be turned off

## Install dependencies

### Install crust service
```shell
sudo ./install.sh # Use 'sudo ./install.sh --registry cn' to accelerate installation in some areas
```

### Modify config.yaml
```shell
sudo crust config set
```

### Run service

- Please make sure the following ports are not occupied before starting：
  - 30888 19933 19944 (for crust chain)
  - 56666 (for crust API)
  - 12222 (for crust sWorker)
  - 5001 4001 37773 (for IPFS)

```shell
sudo crust help
sudo crust start
sudo crust status
```

### Stop service

```shell
sudo crust stop
```

## License

[GPL v3](LICENSE)
