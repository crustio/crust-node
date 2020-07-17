# Crust client
On one hand, this project is used to install all crust related programs, including chain, TEE, API, etc. On the other hand, it provides the corresponding command line to assist the startup of the crust programs.

## Preparation work
- Hardware requirements: 

  CPU must contain **SGX module**, and make sure the SGX function is turned on in the bios, please click [this page](https://github.com/crustio/crust/wiki/Check-TEE-supportive) to check if your machine supports SGX

- Operating system requirements:

  Ubuntu 16.04
  
- Other configurations

  - **Secure Boot** in BIOS needs to be turned off
  - Need use ordinary account, **cannot support root account**

## Install crust-client
Step 0. Install gcc, git, openssl, boost, curl, elf, nodejs and yarn
```shell
sudo apt install build-essential
sudo apt install git
sudo apt install libboost-all-dev
sudo apt install openssl
sudo apt install libssl-dev
sudo apt install curl
sudo apt install libelf-dev
sudo apt install libleveldb-dev
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt install nodejs
sudo apt install yarn
```

### Git mode
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
Then you need move installation packages into this directory ( resource ), include 'crust-api.tar' 'crust.tar'  'crust-tee.tar' ( for now, you can get resource.tar from [release page](https://github.com/crustio/crust-client/releases) ).

Step 4. Run install script
```shell
sudo ./install
```

### Package mode
Step 1. Download source code in release

[release page](https://github.com/crustio/crust-client/releases)

Step 2. Unzip crust-client-x.x.x-alpha.tar.gz
```shell
tar -zxf crust-client-x.x.x-alpha.tar.gz
```

Step 3. Into directory
```shell
cd crust-client-x.x.x-alpha
```

Step 4. Preparing the installation packages
```shell
mkdir resource # create resource directory
```
Then you need move installation packages into this directory ( resource ), include 'crust-api.tar' 'crust.tar'  'crust-tee.tar' ( for now, you can get resource.tar from [release page](https://github.com/crustio/crust-client/releases) ).

Step 5. Run install script
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
node_key=                                    # only the genesis node need this, for example:0000000000000000000000000000000000000000000000000000000000000001
bootnodes=(address1 address2 ...)            # the bootnodes for connect to the exist chain (if you are first node, you don't need this)
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
```shell
{
    "base_path" : "/home/user/crust-alphanet/crust_store/node1/tee/",    # All files will be stored in this directory, must be absolute path
    "empty_capacity" : 4,                                                # empty disk storage in Gb
    
    "api_base_url": "http://127.0.0.1:12222/api/v0",                     # your tee node api address
    "validator_api_base_url": "http://127.0.0.1:12222/api/v0",           # the tee validator address (**if you are genesis node, this url must equal to 'api_base_url'**)
    "karst_url":  "ws://0.0.0.0:17000/api/v0/node/data",
    "websocket_url" : "wss://0.0.0.0:19002",
    "websocket_thread_num" : 3,

    "chain_api_base_url" : "http://127.0.0.1:56666/api/v1",              # the address of crust api
    "chain_address" : "",                                                # your crust chain identity
    "chain_account_id" : "",
    "chain_password" : "",
    "chain_backup" : "",
    ......
}
```

## Run

### Run genesis node
The genesis node refers to the initial nodes of the chain written in the genesis spec. These nodes have a very important meaning as the core of the chain startup. They are also the initial validators. Generally genesis node's identity file is issued by crust organization.

#### Chain
- Launch
```shell
   crust-client chain-launch-genesis genesis1_config/chain-launch.config genesis1_config/chain-identity-file -b logs/genesis1-chain.log
```
- Monitor
```shell
   tail -f logs/genesis1-chain.log.pid
```

#### TEE
- Launch
```shell
   crust-client tee-launch genesis1_config/tee-launch.json -b logs/genesis1-tee.log
```
- Monitor
```shell
   tail -f logs/genesis1-tee.log
```

#### API
- Launch
```shell
   crust-client api-launch genesis1_config/api-launch.config -b logs/genesis1-api.log
```
- Monitor
```shell
   tail -f logs/genesis1-api.log.pid
```

- Test
```shell
   curl --location --request GET 'http://localhost:56667/api/v1/block/header'
```

### Run normal node
Normal node cannot be a validator, it is only an access node of the chain, and it can be connected to the chain browser by setting external_rpc_ws=true

#### Chain
- Launch
```shell
   crust-client chain-launch-normal normal1_config/chain-lanuch.config -b logs/normal1-chain.log
```
- Monitor
```shell
   tail -f logs/normal1-chain.log.pid
```

#### Chain browser
Connet to normal node ws like: ws://139.196.122.228:6013/ to see crust chain status.

### Run validator node
If you are not genesis node but want to apply to become a validator, please follow the instructions below. Of course you need a tee to report your workload

#### Chain
- Launch
```shell
   crust-client chain-launch-validator validator1_config/chain-launch.config -b logs/validator1-chain.log
```
- Monitor
```shell
   tail -f logs/validator1-chain.log.pid
```
- Get session keys
you will see a warning like:
```shell
   2020/02/21 14:51:30.023 [WARN] Please go to chain web page to bond your account with the session keys: "0x3715f28f8e3c5cbbd82e490525df9aaff49fbb8e0e4a527498a810a0ace3d01b4c1a15741ebbecf4d402c88ac87fdbaf92f013191cc8720adfa21275dad71f08763a5996258e336f995ff72b94e2cee776de5fbfbae365e344ef6ce347d767284619c7ba6078d7e59ab555399ad81a9b2cc89b0d43b8bc40f6df047d21014215"
```

#### Bond your account with the session keys

- Need two accounts and have some CRUs in those accounts, like:
![validator1 and stash accounts](doc/img/validator1_and_stash_accounts.PNG)

- Go to **Staking/Account actions/New stake** to Bond two accounts, like:
![bond validator1](doc/img/bond_validator1.PNG)

- Click **session key** to set session key, like:
![set session key](doc/img/set_session_key.PNG)

#### TEE

- Configuration
   - Need create two account (controller and stash account) in crust chain browser and put some CRU in them, like:
   ![validator1 and stash accounts](doc/img/validator1_and_stash_accounts.PNG) 
  
   - Please select tee of a validator node on chain to validate your tee by fill 'validator_api_base_url' and use controller account (not stash account) to configure crust chain identity.

   - Use this command to get 'chain_account_id' by convert 'chain_address', please note that you need to remove the initial '0x' when filling 'chain_account_id' in the TEE configuration.
      ```shell
      crust-subkey inspect "chain_address"
      ```

- Launch
```shell
   crust-client tee-launch validator1_config/tee-launch.json -b logs/validator1-tee.log
```

- Monitor
```shell
   tail -f logs/validator1-tee.log
```

#### API
- Launch
```shell
   crust-client api-launch validator1_config/api-launch.config -b logs/validator1-api.log
```
- Monitor
```shell
   tail -f logs/validator1-api.log.pid
```

- Test
```shell
   curl --location --request GET 'http://localhost:56669/api/v1/block/header'
```

#### Start validate

- Waiting TEE
  
  Need to make sure your tee has plotted your empty disk and reported your first work report.

- Waiting one era

- Click "Validate" button, like:
![set session key](doc/img/start_validate.PNG)

- Waiting one era, you will see magic!

## Command line usage
```
    help                                                                show help information   
    version                                                             show crust-client version   
    chain-launch-genesis <chain-launch.config> <chain-identity-file>    launch crust-chain as a genesis node   
    chain-launch-normal <chain-launch.config>                           launch crust-chain as a normal node
    chain-launch-validator <chain-launch.config>                        launch crust-chain as a validator node   
    chain-stop <chain-launch.config>                                    stop crust-chain with same configuration
    api-launch <api-launch.config>                                      launch crust-api
    api-stop <api-launch.config>                                        stop crust-api with same configuration   
    tee-launch <tee-launch.json>                                        launch crust-tee (if you set 
                                                                            api_base_url==validator_api_base_url
                                                                            in config file, you need to be genesis node)
    tee-stop <tee-launch.json>                                          stop crust-tee with same configuration   
    -b <log-file>                                                       launch commands will be started in backend
                                                                            with "chain-launch-genesis", "chain-launch-normal",
                                                                            "chain-launch-validator", "api-launch", "tee-launch"  
```
## License

[GPL v3](LICENSE)
