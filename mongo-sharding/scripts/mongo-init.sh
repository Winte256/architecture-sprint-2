#!/bin/bash

# Function to check if a container is running
check_container_running() {
  container_name=$1
  if [ $(docker ps -q -f name=$container_name) ]; then
    echo "$container_name is running"
  else
    echo "$container_name is not running. Exiting..."
    exit 1
  fi
}

# Function to wait for a few seconds
wait_for() {
  seconds=$1
  echo "Waiting for $seconds seconds..."
  sleep $seconds
}

# Initialize the config server
check_container_running "configSrv"
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

wait_for 3

# Initialize shard1
check_container_running "shard1"
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1:27018" }
    ]
  }
);
exit();
EOF

wait_for 3

# Initialize shard2
check_container_running "shard2"
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 1, host : "shard2:27019" }
    ]
  }
);
exit();
EOF

wait_for 3

# Configure sharding in mongos_router
check_container_running "mongos_router"
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1:27018");
sh.addShard("shard2/shard2:27019");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" });

use somedb;

for (var i = 0; i < 1000; i++) {
  db.helloDoc.insert({age: i, name: "ly" + i});
}

db.helloDoc.countDocuments();
exit();
EOF

wait_for 3

# Check the document count on shard1
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
exit();
EOF

wait_for 3

# Check the document count on shard2
docker compose exec -T shard2 mongosh --port 27019 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
exit();
EOF