# Crust client
On one hand, this project is used to install and run all crust related programs, including chain, TEE, API, karst etc.

## Preparation work
- Hardware requirements: 

  CPU must contain **SGX module**, and make sure the SGX function is turned on in the bios, please click [this page](https://github.com/crustio/crust/wiki/Check-TEE-supportive) to check if your machine supports SGX

- Operating system requirements:

  Ubuntu 16.04
  
- Other configurations

  - **Secure Boot** in BIOS needs to be turned off
  - Need use ordinary account, **cannot support root account**

## Install dependencies

### Install docker
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

### Install docker-compose
sudo apt install docker-compose

## License

[GPL v3](LICENSE)
