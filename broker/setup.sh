#!/bin/bash
set -e
VHOST=${VHOST:-serverHost}
RMQ_USER=${RMQ_USER:-WebServer}
EXCHANGE=${EXCHANGE:-serverExchange}
QUEUE=${QUEUE:-serverQueue}
if [ -z "$RMQ_PASS" ]; then
        read -rsp "Password for RabbitMQ user $RMQ_USER: " RMQ_PASS; echo
fi

sudo apt update
sudo apt install -y rabbitmq-server curl
sudo systemctl enable --now rabbitmq-server
sudo rabbitmq-plugins enable rabbitmq_management

sudo rabbitmqctl add_vhost "$VHOST" 2>/dev/null || true
sudo rabbitmqctl add_user "$RMQ_USER" "$RMQ_PASS" 2>/dev/null \
        || sudo rabbitmqctl change_password "$RMQ_USER" "$RMQ_PASS"
sudo rabbitmqctl set_user_tags "$RMQ_USER" administrator
sudo rabbitmqctl set_permissions -p "$VHOST" "$RMQ_USER" ".*" ".*" ".*"

# Exchanges, queues and bindings go through the management API.
API=http://localhost:15672/api
until curl -sf -u "$RMQ_USER:$RMQ_PASS" "$API/overview" >/dev/null; do sleep 2; done
put() { curl -sf -u "$RMQ_USER:$RMQ_PASS" -X PUT -H 'content-type: application/json' -d "$2" "$API/$1"; }
put "exchanges/$VHOST/$EXCHANGE" '{"type":"topic","durable":true}'
put "queues/$VHOST/$QUEUE" '{"durable":true}'
curl -sf -u "$RMQ_USER:$RMQ_PASS" -X POST -H 'content-type: application/json' \
        -d '{"routing_key":"*"}' "$API/bindings/$VHOST/e/$EXCHANGE/q/$QUEUE"

echo "Broker ready: vhost=$VHOST exchange=$EXCHANGE queue=$QUEUE user=$RMQ_USER"