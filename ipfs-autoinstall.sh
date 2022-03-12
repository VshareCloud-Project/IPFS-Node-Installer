#!/bin/bash
# v1.0.5
echo=echo
for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue

    if ! $cmd -e "" | grep -qE '^-e'; then
        echo=$cmd
        break
    fi
done

CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"

OUT_ALERT() {
    echo -e "${CYELLOW}$1${CEND}"
}

OUT_ERROR() {
    echo -e "${CRED}$1${CEND}"
}

OUT_INFO() {
    echo -e "${CCYAN}$1${CEND}"
}

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
else
    OUT_ERROR "[错误] 不支持的操作系统！"
    exit 1
fi
echo "System Check Done"

# Install IPFS Binary File
set -e

if [ -e /tmp/ipfs_install ]; then
    rm -rf /tmp/ipfs_install
fi
mkdir /tmp/ipfs_install
cd /tmp/ipfs_install
if [ ! -e /usr/bin/ipfs ]; then
wget "https://gateway.ipns.tech//ipns/ipfs-file.ipns.network/ipfs-file.tar.gz"
tar zxvf ipfs-file.tar.gz
cp -f ipfs /usr/bin/
chmod +x /usr/bin/ipfs
rm -rf /tmp/ipfs_install
fi
echo "Install Done"

# Set Service File
cat >/etc/systemd/system/ipfs-daemon.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
User=root
Group=root
LimitCPU=infinity
LimitFSIZE=infinity
LimitDATA=infinity
LimitSTACK=infinity
LimitCORE=infinity
LimitRSS=infinity
LimitNOFILE=infinity
LimitAS=infinity
LimitNPROC=infinity
LimitMEMLOCK=infinity
LimitLOCKS=infinity
LimitSIGPENDING=infinity
LimitMSGQUEUE=infinity
LimitRTPRIO=infinity
LimitRTTIME=infinity
ExecStart=/usr/bin/ipfs daemon --enable-gc --enable-pubsub-experiment
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "Set service Done"

# Set IPFS
public_ip=`curl -s https://api-ipv4.ip.sb/ip`
if [ ! -e /root/.ipfs ]; then
ipfs init
fi
systemctl stop ipfs-daemon
#配置外部访问
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://'$public_ip':5010", "http://localhost:3000", "http://127.0.0.1:5001"]'
ipfs config --json Addresses.API '"/ip4/0.0.0.0/tcp/5010"'
# 提高BitSwap效率
ipfs config --json Internal.Bitswap.TaskWorkerCount 256
ipfs config --json Internal.Bitswap.TaskWorkerCount 512
ipfs config --json Internal.Bitswap.EngineBlockstoreWorkerCount 4096
ipfs config --json Internal.Bitswap.EngineTaskWorkerCount 512
ipfs config --json Swarm.RelayService.Enabled true
ipfs config --json Reprovider.Interval '"1h"'
#配置Traacker
ipfs bootstrap add /dns4/checkpoint-hk.ipns.network/tcp/4001/p2p/12D3KooWQzZ931qqFJHER6wmmafMdV3ykxULczRsW83o5pJaBMTV
ipfs bootstrap add /dns4/checkpoint-sg.ipns.network/tcp/4001/p2p/12D3KooWNke2bS34fxQrGrnx27UbWMNsWLKDNPEEo8tLyS1K22Ee
ipfs bootstrap add /dns4/checkpoint-us.ipns.network/tcp/4001/p2p/12D3KooWSgRgfLxfDdi2eDRVBpBYFuTZp39HEBYnJm1upCUJ2GYz
ipfs config --json Peering.Peers '[{"Addrs": ["/dns4/checkpoint-hk.ipns.network/tcp/4001", "/dns4/checkpoint-hk.ipns.network/udp/4001/quic"], "ID": "12D3KooWQzZ931qqFJHER6wmmafMdV3ykxULczRsW83o5pJaBMTV"}, {"Addrs": ["/dns4/checkpoint-sg.ipns.network/tcp/4001", "/dns4/checkpoint-sg.ipns.network/udp/4001/quic"], "ID": "12D3KooWNke2bS34fxQrGrnx27UbWMNsWLKDNPEEo8tLyS1K22Ee"}, {"Addrs": ["/dns4/checkpoint-us.ipns.network/tcp/4001", "/dns4/checkpoint-us.ipns.network/udp/4001/quic"], "ID": "12D3KooWSgRgfLxfDdi2eDRVBpBYFuTZp39HEBYnJm1upCUJ2GYz"}]'
ipfs config --json Swarm.ConnMgr '{"GracePeriod": "30s","HighWater": 1024,"LowWater": 512,"Type": "basic"}'
ipfs config --json Datastore.GCPeriod '"12h"'
systemctl enable --now ipfs-daemon
sleep 15s
ipfs pin add /ipns/ipfs-file.ipns.network
ipfs pin add /ipns/install-sh.ipns.network
echo "The installation is complete, enjoy your node!"

exit 0