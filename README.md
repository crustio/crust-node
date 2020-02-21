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
Then you need move installation packages into this directory ( resource ), include 'crust-api.tar' 'crust.tar'  'crust-tee.tar' ( for now, you can get those packages from crust organization ).

Step 4. Run install stcript
```shell
sudo ./install
```

## Configurations

### chain-launch.config
```shell
base_path=crust_store/node1/chain            # the base path of chain
port=30333                                   # the port for p2p
ws_port=9944                                 # the port for ws
rpc_port=9933                                # the port for rpc
name=node1                                   # the name of chain
bootnodes=/ip4/<ip>/tcp/<port>/p2p/<node-id> # the bootnodes for connect to the exist chain (if you are first node, you don't need this)
external_rpc_ws=false                        # Whether to publicize the ws and rpc interface (if you are genesis node or validator node, this configuration must be false)
```

### chain-identity-file

Only genesis node need this file, please connect to crust organization to get it.

### api-launch.config
```shell
crust_api_port=56666                         # the api port
crust_chain_endpoint="ws://127.0.0.1:9944/"  # the ws address of chain
```

### tee-launch.json
```json
{
    "empty_path" : "crust_store/node1/tee/empty_path",
    "empty_capacity" : 4,
    
    "ipfs_api_base_url" : "http://127.0.0.1:5001/api/v0",
    "api_base_url": "http://127.0.0.1:12222/api/v0",
    "validator_api_base_url": "http://127.0.0.1:12222/api/v0",

    "crust_api_base_url" : "http://127.0.0.1:56666/api/v1",
    "crust_address" : "",
    "crust_account_id" : "",
    "crust_password" : "",
    "crust_backup" : "",
    ......
}
```
empty_path -> plot file will be stored in this directory

empty_capacity -> empty disk storage in Gb

ipfs_api_base_url -> for connect to ipfs

api_base_url -> your tee node api address

validator_api_base_url -> the tee validator address (if you are genesis node, this url must equal to 'api_base_url')

crust_api_base_url -> the address of crust api

crust_address, crust_account_id, crust_password, crust_backup -> your crust chain identity

## Run

### Run genesis node
The genesis node refers to the initial nodes of the chain written in the genesis spec. These nodes have a very important meaning as the core of the chain startup. They are also the initial validators. Generally genesis node's identity file is issued by crust organization.
