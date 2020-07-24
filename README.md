# Crust node
Official crust node service for running crust protocol.

## Preparation work
- Hardware requirements: 

  CPU must contain **SGX module**, and make sure the SGX function is turned on in the bios, please click [this page](https://github.com/crustio/crust/wiki/Check-TEE-supportive) to check if your machine supports SGX

- Operating system requirements:

  Ubuntu 16.04/18.04
  
- Other configurations

  - **Secure Boot** in BIOS needs to be turned off
  - Need use ordinary account, **cannot support root account**

## Install dependencies

### Install docker and docker-compose
```shell
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
sudo apt install docker-compose
```

### Install sgx driver
```shell
sudo ./scripts/install_sgx_driver.sh
```

### Generate application configuration

#### Modify config.yaml
You need to modify config.yaml

### Run the config gen script
Run ```sudo ./scripts/gen_config.sh``` Configrations and docker compose will generated in the build directory.

### Run docker

```shell
cd build
sudo docker-compose up crust
sudo docker-compose up crust-api
sudo docker-compose up crust-sworker
sudo docker-compose up karst # if your want to start karst, please make sure fastdfs is running in your computer
```

## License

[GPL v3](LICENSE)
