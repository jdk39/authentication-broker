#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
L="$HERE/listener"
DB_NAME=${DB_NAME:-appdb}
DB_USER=${DB_USER:-appuser}
[ -n "$DB_PASS" ] || { read -rsp "Password for MySQL user $DB_USER: " DB_PASS; echo; }
read -rp "Broker host (Tailscale IP or name): " BROKER_HOST
read -rp "Broker vhost [serverHost]: " VHOST; VHOST=${VHOST:-serverHost}
read -rp "Broker user [WebServer]: " RMQ_USER; RMQ_USER=${RMQ_USER:-WebServer}
read -rsp "Broker password: " RMQ_PASS; echo
read -rp "Exchange [serverExchange]: " EXCHANGE; EXCHANGE=${EXCHANGE:-serverExchange}
read -rp "Queue [serverQueue]: " QUEUE; QUEUE=${QUEUE:-serverQueue}

sudo apt update
sudo apt install -y mysql-server php-cli php-mysql php-amqp
sudo systemctl enable --now mysql

sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT SELECT, INSERT, UPDATE, DELETE ON $DB_NAME.* TO '$DB_USER'@'localhost';
SQL
sudo mysql "$DB_NAME" < "$HERE/schema.sql"

mkdir -p "$L/config"
touch "$L/config/host.ini"
cat > "$L/config/db.ini" <<EOF
host = "127.0.0.1"
user = "$DB_USER"
pass = "$DB_PASS"
name = "$DB_NAME"
EOF
cat > "$L/config/RabbitMQ.ini" <<EOF
[testServer]
BROKER_HOST = $BROKER_HOST
BROKER_PORT = 5672
USER = $RMQ_USER
PASSWORD = $RMQ_PASS
VHOST = $VHOST
EXCHANGE_TYPE = topic
EXCHANGE = $EXCHANGE
QUEUE = $QUEUE
EOF
chmod 600 "$L/config/"*.ini

# Run the listener as a service so it survives logouts and reboots.
sudo tee /etc/systemd/system/sqllistener.service >/dev/null <<EOF
[Unit]
Description=SQL listener
After=network-online.target mysql.service

[Service]
User=$USER
ExecStart=/usr/bin/php $L/listener.php
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now sqllistener

echo "DB VM ready. Logs: journalctl -u sqllistener -f"