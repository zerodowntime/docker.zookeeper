#!/bin/bash

export HOST=`hostname -s`
export DOMAIN=`hostname -d`
export DATA_DIR="/var/lib/zookeeper/data"
export CLIENT_PORT=2181
export SERVER_PORT=2888
export ELECTION_PORT=3888

# cut hostname from stateful set into name and ordinal
if [[ $HOST =~ (.*)-([0-9]+)$ ]]; then
    export NAME=${BASH_REMATCH[1]}
    export ORD=${BASH_REMATCH[2]}
else
    echo "Failed to parse name and ordinal of Pod"
    exit 1
fi

# get and set id
export MY_ID=$((ORD+1))
ID_FILE="$DATA_DIR/myid"
echo $MY_ID > $ID_FILE

# get number of servers
METADATA_NAMESPACE=$(cat /run/secrets/kubernetes.io/serviceaccount/namespace)
BEARER_TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
STATEFULSET_NAME="${HOSTNAME%-*}"
POD_ORDINAL="${HOSTNAME##*-}"

JSONFILE="$(mktemp)"
curl -s -o "$JSONFILE" \
     --cacert "/run/secrets/kubernetes.io/serviceaccount/ca.crt" \
     --header "Authorization: Bearer $BEARER_TOKEN" \
     "https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT/apis/apps/v1/namespaces/$METADATA_NAMESPACE/statefulsets/$STATEFULSET_NAME"

export SERVERS=$(cat $JSONFILE | jq '.spec.replicas')

# the meat: add server to the cluster
# targeted for statefulset - try to add to ids lower than my own
# prevents creating separate clusters
for ((ID=0; ID<=MY_ID; ID++))
do
    /opt/zookeeper/bin/zkCli.sh -server $NAME-$ID.$DOMAIN:$CLIENT_PORT <<EOF
addauth digest super:superpwd
reconfig -add $MY_ID=$NAME-$ORD.$DOMAIN:$SERVER_PORT:$ELECTION_PORT:participant;$CLIENT_PORT
quit
EOF
    if [ $? -eq "0" ]; then
	break
    fi
done
