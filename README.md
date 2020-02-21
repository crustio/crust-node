# Crust client
On one hand, this project is used to install all crust related programs, including chain, TEE, API, IPFS, etc. On the other hand, it provides the corresponding command line to assist the startup of the crust programs.

## Preparation work
- Hardware requirements: 

  CPU must contain SGX module, and make sure the SGX function is turned on in the bios
- Operating system requirements:

  Unbantu 16.04

## Install crust-client
Step 1. Download crust-client
```shell
git clone https://github.com/crustio/crust-client.git
```
Step 2. Into directory
```shell
cd crust-client
```
Step 3. Preparing the installation packages
```shell
mkdir resource # create resource directory
```
Then you need move installation packages into this directory(resource), include 'crust-api.tar' 'crust.tar'  'crust-tee.tar' (for now, you can get those packages from crust organization)

Step 4. Run install stcript
```shell
sudo ./install
```

