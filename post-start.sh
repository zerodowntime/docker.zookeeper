#!/bin/bash

export HOST=`hostname -s`
export DOMAIN=`hostname -d`
export DATA_DIR="/var/lib/zookeeper/data"
export CLIENT_PORT=2181
export SERVER_PORT=2888
export ELECTION_PORT=3888
export ZK_SUPERUSER=$(cat /etc/zookeeper-super/username)
export ZK_SUPERPASS=$(cat /etc/zookeeper-super/password)

# check if service is up, if not it means this is the first pod to start
if [[ $(dig +short "$DOMAIN") ]]; then
    echo "There are other pods in service. Attempting to join."
else
    echo "I am the first pod to start. Skipping cluster insertion."
    exit 0
fi

# cut hostname from stateful set into name and ordinal
if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
    export NAME=${BASH_REMATCH[1]}
    export ORD=${BASH_REMATCH[2]}
else
    echo "Failed to parse name and ordinal of Pod"
    exit 1
fi

# get id
export MY_ID=$((ORD+1))

# the meat: add server to the cluster
# targeted for statefulset - try to add to ids lower than my own
# prevents creating separate clusters
echo "Trying $DOMAIN..."
sleep 1

/opt/zookeeper/bin/zkCli.sh -server $DOMAIN:$CLIENT_PORT <<EOF
addauth digest $ZK_SUPERUSER:$ZK_SUPERPASS
reconfig -add $MY_ID=$NAME-$ORD.$DOMAIN:$SERVER_PORT:$ELECTION_PORT:participant;$CLIENT_PORT
quit
EOF

if [ $? -eq "0" ]; then
	echo "Done"
	exit 0
fi

echo "Connection broken"
echo "Trying again..."
sleep 1

/opt/zookeeper/bin/zkCli.sh -server $DOMAIN:$CLIENT_PORT <<EOF
addauth digest $ZK_SUPERUSER:$ZK_SUPERPASS
reconfig -add $MY_ID=$NAME-$ORD.$DOMAIN:$SERVER_PORT:$ELECTION_PORT:participant;$CLIENT_PORT
quit
EOF

if [ $? -eq "0" ]; then
    echo "Done"
    exit 0
fi
