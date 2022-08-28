#!/bin/bash

if (( $EUID != 0 )); then
    echo "Please run as root."
    exit 1
fi

MON_DIR=/usr/local/jni-home-monitoring

cd $MON_DIR/compose-files
# docker stack rm pan_grafana_monitoring
docker compose down

rm -rf $MON_DIR
echo "All is cleared in: $MON_DIR"
