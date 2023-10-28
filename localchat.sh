#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


## conduit
wget -O /usr/local/bin/matrix-conduit https://gitlab.com/famedly/conduit/-/jobs/artifacts/master/raw/build-output/linux_arm64/conduit?job=docker:master
chmod +x /usr/local/bin/matrix-conduit

## create user
adduser --system conduit --group --disabled-login --no-create-home
chown -R conduit:conduit /usr/local/bin/matrix-conduit

## create service
echo '[Unit]
Description=Conduit Matrix Server
After=network.target

[Service]
Environment="CONDUIT_CONFIG=/etc/matrix-conduit/conduit.toml"
User=conduit
Group=conduit
Restart=always
ExecStart=/usr/local/bin/matrix-conduit

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/matrix-conduit.service

## create config
mkdir /etc/matrix-conduit
echo '[global]
server_name = "chat.local"
database_path = "/var/lib/matrix-conduit/"
database_backend = "rocksdb"
port = 6167
max_request_size = 20_000_000 # in bytes
allow_registration = true
allow_federation = false
allow_check_for_updates = false
trusted_servers = ["matrix.org"]
address = "0.0.0.0"
' > /etc/matrix-conduit/conduit.toml
chown -R conduit:conduit /etc/matrix-conduit

## create database
mkdir -p /var/lib/matrix-conduit
chown -R conduit:conduit /var/lib/matrix-conduit

## set systemctl service
systemctl enable matrix-conduit
systemctl start matrix-conduit

echo "Conduit setup complete."

## lighttpd
apt-get install lighttpd
rm -rf /var/www/html

## cinny
wget -O /tmp/cinny https://github.com/cinnyapp/cinny/releases/download/v3.1.0/cinny-v3.1.0.tar.gz
tar -xvf /tmp/cinny -C /var/www/
mv /var/www/dist /var/www/html
echo '{
  "defaultHomeserver": 0,
  "homeserverList": [
    "http://chat.local:6167/"
  ],
  "allowCustomHomeservers": true
}' > /var/www/html/config.json
chown -R www-data:www-data /var/www/html

echo "Cinny setup complete."

## hotspot config
EX = $(nmcli con | grep wlan0 | awk '{print $1}')
nmcli connection modify $EX connection.autoconnect no

nmcli device wifi hotspot ssid chat.local password ChangeMe
nmcli connection modify Hotspot autoconnect yes

echo "Hotspot setup complete."


# setup hostname
echo "chat" > /etc/hostname
echo '127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

127.0.1.1       chat' > /etc/hosts

echo "Hostname setup complete."

echo "Connect to the hotspot and visit http://chat.local to start chatting."