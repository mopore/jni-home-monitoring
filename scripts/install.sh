#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root."
    exit 1
fi

INSTALL_DIR=$PWD

# Grafana needs to access innodb via local ip address
LOCAL_IP_ADDRESS="192.168.199.214"

TELEGRAF_PWD=admin
# printf "Please enter a password for the telegraf innodb user: "
# read -s TELEGRAF_PWD

HOSTNAME=$(hostname)
echo "Hostname is: ${HOSTNAME}"
MON_DIR=/usr/local/jni-home-monitoring

echo "Creating directories..."
mkdir -p $MON_DIR/influxdb/data
mkdir -p $MON_DIR/influxdb/init
mkdir -p $MON_DIR/compose-files
mkdir -p $MON_DIR/grafana/data
mkdir -p $MON_DIR/grafana/provisioning/datasources
mkdir -p $MON_DIR/grafana/provisioning/plugins
mkdir -p $MON_DIR/grafana/provisioning/notifiers
# mkdir -p $MON_DIR/grafana/provisioning/dashboards
chown 472:472 $MON_DIR/grafana/data

echo "Copying files..."
cp ../influxdb/create-telegraf.iql $MON_DIR/influxdb/init
sed -i 's/XXXXX/'${TELEGRAF_PWD}'/g' $MON_DIR/influxdb/init/create-telegraf.iql

cp ../docker-compose/docker-compose.yml $MON_DIR/compose-files
# cp ../docker-compose/env $MON_DIR/compose-files/.env
# sed -i 's/XXXXX/'${TELEGRAF_PWD}'/g' $MON_DIR/compose-files/.env

cp ../grafana/provisioning/datasources/datasource.yaml $MON_DIR/grafana/provisioning/datasources
sed -i 's/XXXXX/'${TELEGRAF_PWD}'/g' $MON_DIR/grafana/provisioning/datasources/datasource.yaml
sed -i 's/IIIII/'${LOCAL_IP_ADDRESS}'/g' $MON_DIR/grafana/provisioning/datasources/datasource.yaml
# cp ../grafana/provisioning/dashboards/* $MON_DIR/grafana/provisioning/dashboards

echo "Creating files..."
cd $MON_DIR/influxdb
docker run --rm influxdb:1.8 influxd config > influxdb.conf
# next do some modifications to the default config
# enable HTTP auth
sed -i 's/^  auth-enabled = false$/  auth-enabled = true/g' influxdb.conf
# do any other changes you want, or replace with your own config entirely

docker run --rm telegraf telegraf config > telegraf.conf
# now modify it to tell it how to authenticate against influxdb
sed -i 's/^  # urls = \["http:\/\/127\.0\.0\.1:8086"\]$/  urls = \["http:\/\/'${LOCAL_IP_ADDRESS}':8086"\]/g' telegraf.conf
sed -i 's/^  # database = "telegraf"$/  database = "telegraf"/' telegraf.conf
sed -i 's/^  # username = "telegraf"$/  username = "telegraf"/' telegraf.conf
sed -i 's/^  # password = "metricsmetricsmetricsmetrics"$/  password = "'${TELEGRAF_PWD}'"/' telegraf.conf
# as we run inside docker, the telegraf hostname is different from our hostname, let's change it
sed -i 's/^  hostname = ""$/  hostname = "'${HOSTNAME}'"/' telegraf.conf

cat $INSTALL_DIR/../telegraf/telegraf.conf >> telegraf.conf

docker run --rm --entrypoint /bin/bash grafana/grafana:latest -c 'cat $GF_PATHS_CONFIG' > grafana.ini
mv grafana.ini $MON_DIR/grafana

echo "Monitoring directory prepared: ${MON_DIR}"


cd $MON_DIR/compose-files
docker compose up -d
# docker stack deploy -c ./docker-compose.yml pan_grafana_monitoring
exit 0
