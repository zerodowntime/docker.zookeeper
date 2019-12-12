#!/bin/bash

export USER=`whoami`
export HOST=`hostname -s`
export DOMAIN=`hostname -d`
export DATA_DIR="/var/lib/zookeeper/data"
export DATA_LOG_DIR="/var/lib/zookeeper/log"
export LOG_DIR="/var/log/zookeeper"
export CONF_DIR="/opt/zookeeper/conf"
export CLIENT_PORT=2181
export SERVER_PORT=2888
export ELECTION_PORT=3888

export ZOOKEEPER_LOG_LEVEL=INFO
export ZOOKEEPER_TICK_TIME=2000
export ZOOKEEPER_MIN_SESSION_TIMEOUT=${ZOOKEEPER_MIN_SESSION_TIMEOUT:-$((ZOOKEEPER_TICK_TIME*2))}
export ZOOKEEPER_MAX_SESSION_TIMEOUT=${ZOOKEEPER_MAX_SESSION_TIMEOUT:-$((ZOOKEEPER_TICK_TIME*20))}
export ZOOKEEPER_INIT_LIMIT=10
export ZOOKEEPER_SYNC_LIMIT=5
export ZOOKEEPER_HEAP=2G
export ZOOKEEPER_MAX_CLIENT_CNXNS=60
export ZOOKEEPER_SNAP_RETAIN_COUNT=3
export ZOOKEEPER_PURGE_INTERVAL=0

# set ownership
chown -R zookeeper:root /opt/zookeeper/
chown -R zookeeper:root /var/lib/zookeeper/

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
echo $MY_ID >> $ID_FILE

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

#export SERVERS=$(cat $JSONFILE | jq '.spec.replicas')

re='^[0-9]+$'
if ! [[ $SERVERS =~ $re ]] ; then
    export SERVERS="$MY_ID"
fi

echo $SERVERS

# confd
confd -onetime -log-level debug || exit 1
cat /opt/zookeeper/conf/zoo.cfg

# create password for superuser
SUPER_CRED=$(java -cp "/opt/zookeeper/*:/opt/zookeeper/lib/*" org.apache.zookeeper.server.auth.DigestAuthenticationProvider $(cat /etc/zookeeper-super/username):$(cat /etc/zookeeper-super/password) \
     | awk 'BEGIN{ FS="->" } { print $2}')

# insert password to server variables
sed -i 's#export SERVER_JVMFLAGS=.*#export SERVER_JVMFLAGS="-Xmx${ZK_SERVER_HEAP}m -Dzookeeper.DigestAuthenticationProvider.superDigest='"$SUPER_CRED"' $SERVER_JVMFLAGS"#' /opt/zookeeper/bin/zkEnv.sh

# start zookeeper
exec su-exec zookeeper /opt/zookeeper/bin/zkServer.sh start-foreground
