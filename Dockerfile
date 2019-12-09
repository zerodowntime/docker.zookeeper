##
## author: Adam Ćwiertnia
##

FROM zerodowntime/openjdk:1.8.0-centos7

RUN curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o /usr/local/bin/jq \
	&& chmod +x /usr/local/bin/jq \
	&& yum install -y nc

ARG ZOOKEEPER_VERSION

# Get zookeeper
RUN curl -L https://www.apache.org/dist/zookeeper/zookeeper-$ZOOKEEPER_VERSION/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz \
	-o /opt/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz \
	&& curl -L https://www.apache.org/dist/zookeeper/zookeeper-$ZOOKEEPER_VERSION/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz.sha512 \
	-o /opt/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz.sha512 \
	&& cd /opt \
	&& sha512sum apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz \
	&& tar xzf apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz \
	&& useradd zookeeper \
	&& chown -R zookeeper /opt/apache-zookeeper-$ZOOKEEPER_VERSION-bin \
	&& ln -s /opt/apache-zookeeper-$ZOOKEEPER_VERSION-bin /opt/zookeeper \
	&& chown -h zookeeper /opt/zookeeper

# Configuration /opt/zookeeper/conf
# Data /var/lib/zookeeper/data"
# Data logs /var/lib/zookeeper/log
# Logs /var/log/zookeeper
VOLUME ["/var/lib/zookeeper", "/var/log/zookeeper"]

# 2181: client port
# 3888: election port
# 2888: server port
EXPOSE 2181 2888 3888

#COPY start-zookeeper.sh /opt/zookeeper/bin/start-zookeeper
COPY confd/ /etc/confd
COPY docker-entrypoint.sh /

COPY post-start.sh /opt/
COPY pre-stop.sh /opt/
COPY liveness-probe.sh /opt/
COPY readiness-probe.sh /opt/

COPY --chown=zookeeper zoo.cfg /opt/zookeeper/conf/

ENTRYPOINT ["/docker-entrypoint.sh"]
