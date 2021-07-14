FROM "node:12-buster" 

RUN apt-get update && apt-get install -y wget
RUN wget https://github.com/crustio/crust-node/releases/download/subkey-2.0.1/subkey -O /usr/local/bin/subkey
RUN chmod +x /usr/local/bin/subkey

ENV KEY_TOOL /usr/local/bin/subkey

COPY . /opt/app
WORKDIR /opt/app
RUN npm i 
