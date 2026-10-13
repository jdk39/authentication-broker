#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
read -rp "Broker host (Tailscale IP or name): " BROKER_HOST
read -rp "Broker vhost [serverHost]: " VHOST; VHOST=${VHOST:-serverHost}
read -rp "Broker user [WebServer]: " RMQ_USER; RMQ_USER=${RMQ_USER:-WebServer}
read -rsp "Broker password: " RMQ_PASS; echo
read -rp "Exchange [serverExchange]: " EXCHANGE; EXCHANGE=${EXCHANGE:-serverExchange}
read -rp "Queue [serverQueue]: " QUEUE; QUEUE=${QUEUE:-serverQueue}

sudo apt update
sudo apt install -y apache2 libapache2-mod-php php-cli php-amqp

touch "$HERE/broker/host.ini"
cat > "$HERE/broker/WebServer.ini" <<EOF
[broker]
BROKER_HOST = $BROKER_HOST
BROKER_PORT = 5672
USER = $RMQ_USER
PASSWORD = $RMQ_PASS
VHOST = $VHOST
EXCHANGE_TYPE = topic
EXCHANGE = $EXCHANGE
QUEUE = $QUEUE
EOF
# Apache runs as www-data, so it needs to read the file.
sudo chgrp www-data "$HERE/broker/WebServer.ini"
chmod 640 "$HERE/broker/WebServer.ini"

echo 'DirectoryIndex login.php' | sudo tee /etc/apache2/conf-available/webapp.conf >/dev/null
sudo a2enconf webapp
sudo rm -rf /var/www/html
sudo ln -sfn "$HERE/public" /var/www/html
chmod o+x "$HOME"
sudo systemctl restart apache2

echo "Web VM ready: http://localhost/"