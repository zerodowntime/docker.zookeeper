#!/bin/bash

export HOST=`hostname -s`
export DOMAIN=`hostname -d`
export DATA_DIR="/var/lib/zookeeper/data"
export CLIENT_PORT=2181
export SERVER_PORT=2888
export ELECTION_PORT=3888
export ZK_SUPERUSER=$(cat /etc/zookeeper-super/username)
export ZK_SUPERPASS=$(cat /etc/zookeeker-super/password)

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
for ((ID=0; ID<MY_ID; ID++))
do
    echo "Trying $NAME-$ID.$DOMAIN..."
    sleep 1
    /opt/zookeeper/bin/zkCli.sh -server $NAME-$ID.$DOMAIN:$CLIENT_PORT <<EOF
addauth digest super:superpwd
reconfig -add $MY_ID=$NAME-$ORD.$DOMAIN:$SERVER_PORT:$ELECTION_PORT:participant;$CLIENT_PORT
quit
EOF
    if [ $? -eq "0" ]; then
	echo "Done"
	break
    fi
    echo "Connection broken"
    echo "Trying again..."
    sleep 1
    /opt/zookeeper/bin/zkCli.sh -server $NAME-$ID.$DOMAIN:$CLIENT_PORT <<EOF
addauth digest super:superpwd
reconfig -add $MY_ID=$NAME-$ORD.$DOMAIN:$SERVER_PORT:$ELECTION_PORT:participant;$CLIENT_PORT
quit
EOF
    if [ $? -eq "0" ]; then
	echo "Done"
	break
    fi
done
