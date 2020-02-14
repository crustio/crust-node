/opt/crust/crust/bin/crust \
--base-path nodes/node1 \
--chain /opt/crust/crust-client/etc/crust_chain_spec_raw.json \
--port 30333 \
--ws-port 9944 \
--rpc-port 9933 \
--telemetry-url ws://telemetry.polkadot.io:1024 \
--validator \
--name Node1