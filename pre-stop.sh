#!/bin/bash

export HOST=`hostname -s`
export DOMAIN=`hostname -d`
export DATA_DIR="/var/lib/zookeeper/data"
export CLIENT_PORT=2181
export SERVER_PORT=2888
export ELECTION_PORT=3888
export ZK_SUPERUSER=$(cat /etc/zookeeper-super/username)
export ZK_SUPERPASS=$(cat /etc/zookeeper-super/password)

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

# the meat: remove server from cluster
for ((ID=0; ID<=MY_ID; ID++))
do
    /opt/zookeeper/bin/zkCli.sh -server $NAME-$ID.$DOMAIN:$CLIENT_PORT <<EOF
addauth digest $ZK_SUPERUSER:$ZK_SUPERPASS
reconfig -remove $MY_ID
quit
EOF
    if [ $? -eq "0" ]; then
	break
    fi
done
