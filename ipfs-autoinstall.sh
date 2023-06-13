#!/bin/bash
# v1.1.1

# Variables
IPFS_GATEWAY=${IPFS_GATEWAY:-"https://gateway.ipns.tech"}
IPFS_ARCHIVE="$IPFS_GATEWAY/ipns/ipfs-file.ipns.network/ipfs-file.tar.gz"

# Echo function with color
echo_func() {
    case $1 in
        "ERROR")
            echo -e "\033[1;31m$2\033[0m"
            ;;
        "INFO")
            echo -e "\033[1;36m$2\033[0m"
            ;;
        "SUCCESS")
            echo -e "\033[1;32m$2\033[0m"
            ;;
    esac
}

# Check if required tools are installed
for cmd in curl wget tar systemctl; do
    if ! command -v $cmd &>/dev/null; then
        echo_func ERROR "$cmd is not installed. Please install it first."
        exit 1
    fi
done

# Check the distribution
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -q -E -i "raspbian|debian"; then
    release="debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -q -E -i "deepin"; then
    release="deepin"
else
    echo_func ERROR "Unsupported operating system!"
    exit 1
fi
echo_func INFO "System check done"

# Install IPFS Binary File
set -e

INSTALL_DIR="/tmp/ipfs_install"
IPFS_BIN="/usr/bin/ipfs"

# Cleanup previous installation attempts
rm -rf $INSTALL_DIR
mkdir $INSTALL_DIR
cd $INSTALL_DIR

# Remove the existing IPFS binary if it exists
if [ -e $IPFS_BIN ]; then
    rm -rf $IPFS_BIN
fi

wget "$IPFS_ARCHIVE"
tar zxvf ipfs-file.tar.gz
cp -f ipfs $IPFS_BIN
chmod +x $IPFS_BIN

# Cleanup the installation directory
rm -rf $INSTALL_DIR

echo_func INFO "Installation done"

# Set service file
cat >/etc/systemd/system/ipfs-daemon.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/bin/ipfs daemon --enable-gc --enable-pubsub-experiment
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo_func INFO "Set service done"

# Configure IPFS
public_ip=$(curl -s -4 ip.sb)
if [ ! -e /root/.ipfs/config ]; then
    ipfs init
fi

systemctl stop ipfs-daemon

# Allow external access
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin "[\"http://$public_ip:5010\", \"http://localhost:3000\", \"http://127.0.0.1:5001\"]"
ipfs config --json Addresses.API '"/ip4/0.0.0.0/tcp/5010"'

# Improve BitSwap efficiency
ipfs config --json Swarm.ConnMgr '{"Type": "basic", "LowWater": 500, "HighWater": 1000, "GracePeriod": "20s"}'
ipfs config --json Datastore.GCPeriod '"12h"'

systemctl enable --now ipfs-daemon
sleep 15s

echo_func INFO "The installation is completed, enjoy your node!"

exit 0
