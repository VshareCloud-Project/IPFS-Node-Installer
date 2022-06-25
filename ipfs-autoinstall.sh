#!/bin/bash

## todo: 打包
## 这个脚本的目的真的不是把简单的东西复杂化吗？

OUT_ALERT() {
	printf "\033[1;33m$1\033[0m"
}

OUT_ERROR() {
	printf "\033[1;31m$1\033[0m"
}

OUT_INFO() {
	printf "\033[1;36m$1\033[0m"
}

OUT() {
	printf "${i}"
}

# $1: return value when user input a empty string.
# return: "yes" "no" "unknown"
YES_NO() {
	read line
	status="unknown"
	if [ -z "${line}" ]; then
		OUT "$1\n"
		return
	fi
	for i in "y Y yes YES Yes 是 好"; do
		if [ "$i" == "${line}" ]; then
			OUT "yes\n"
			return
		fi
	done
	for i in "n N no NO No 否 不 别"; do
		if [ "$i" == "${line}" ]; then
			OUT "no\n"
			return
		fi
	done
	OUT "unknown\n"
}


if [ `uname` == 'Linux' ]; then
	OUT_INFO "System Check Done, current kernel: "`uname -r`"\n"
else
	OUT_ERROR "[错误] 真的是 Linux 吗？\n"
	exit 1
fi

if ! [ `ps --no-headers -o comm 1` == "systemd" ]; then
	OUT_ERROR "[错误] 此系统没有使用 systemd，pid 1 为 "`ps --no-headers -o comm 1`"。\n"
	exit 1
fi

required_commands="cd rm mkdir mktemp tar id"
command_check_status="nothing_err_yet"

for i in ${required_commands}
do
	if ! command -v ${i} &> /dev/null
	then
			OUT_ERROR "找不到指令: "${i}"。\n"
			command_check_status="failed"
	fi
done

if [ "${command_check_status}" == "failed" ]; then
	OUT_INFO "请先安装依赖后重新执行脚本。\n"
	exit 1
fi

support_download_commands="aria2c wget curl"
download_command=""

for i in ${support_download_commands} ; do
	if command -v ${i} &> /dev/null
	then
		download_command=${i}
		break
	fi
done

if [ -z "${download_command}" ]; then
	OUT_ERROR "没有能用于下载的工具，请至少安装以下任意一个：\n"${support_download_commands}"\n"
fi

if [ `id -u` == 0 ]; then
	OUT_ALERT "你正在使用 root 权限执行此脚本，确认为整个系统安装 ipfs？[y/n]（默认=n）\n"
	yn=$(YES_NO no)
	if [ $yn == "no" ];then
		exit 0
	fi
fi

if command -v ipfs &> /dev/null
then
	OUT_INFO "ipfs 已经安装，你希望继续安装吗？[y/n]（默认=y）\n"
	yn=$(YES_NO yes)
	if [ "${yn}" == "no" ]; then
		exit 0
	fi
	if [ "${yn}" == "unknown" ]; then
		OUT_ERROR "无法识别的输入:"${line}"\n"
		exit 1
	fi
fi




# Install IPFS Binary File

## set -e: Exit immediately if a command exits with a non-zero status.
set -e

tmpdir=`mktemp --directory /tmp/ipfs_install_temp_dir_XXXXXXXX`
OUT_INFO "generate install temp dir: "${tmpdir}"\n"

cd ${tmpdir}

tar_file_url="https://gateway.ipns.tech/ipns/ipfs-file.ipns.network/ipfs-file.tar.gz"

tar_file_name="ipfs-file.tar.gz"
# 防止重复下载
if [ -f "/tmp/${tar_file_name}" ]; then
	cp "/tmp/${tar_file_name}" ${tmpdir}
fi


if [ "${download_command}" == "aria2c" ]; then
	aria2c --continue=true -d ${tmpdir} -o ${tar_file_name} ${tar_file_url}
fi
if [ "${download_command}" == "wget" ]; then
	wget --continue --output-file=${tmpdir}/${tar_file_name} ${tar_file_url}
fi
if [ "${download_command}" == "curl" ]; then
	curl -C - --verbose --output ${tmpdir}/${tar_file_name} ${tar_file_url}
fi

tar -zxvf ipfs-file.tar.gz

systemd_user_arg=""
if [ `id -u` == 0 ]; then
	bin_install_dir="/usr/bin/"
	cp -f ipfs ${bin_install_dir}
	chmod 755 ${bin_install_dir}"ipfs"
	OUT_INFO "ipfs 二进制文件已经被脏安装到 "${bin_install_dir}"ipfs。\n"
	OUT_ALERT """选择 systemd servise 安装位置：\n"
	OUT_INFO "	1) /etc/systemd/system (默认)
	2) /usr/local/lib/systemd/system
	3) /run/systemd/system (作为 Runtime units 安装，没有实际影响)
	4) /usr/lib/systemd/system (如果你在制作一个软件包而非真正安装，请选择此项)\n"
	systemd_service_path=""
	read line
	if [ -z "${line}" ]; then
		line=1
	fi
	if [ "${line}" == 1 ];then
		systemd_service_path="/etc/systemd/system"
	fi
	if [ "${line}" == 2 ];then
			systemd_service_path="/usr/local/lib/systemd/system"
	fi
	if [ "${line}" == 3 ];then
			systemd_service_path="/run/systemd/system"
	fi
	if [ "${line}" == 4 ];then
			systemd_service_path="/usr/lib/systemd/system"
	fi		
	
	if [ -z "${systemd_service_path}" ]; then
		OUT_ERROR "未知的输入。\n"
		return 1
	fi
	
	cat >${tmpdir}/ipfs-daemon-root.service <<EOF
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
	cp ${tmpdir}/ipfs-daemon-root.service ${systemd_service_path}/ipfs-daemon.service

else
	bin_install_dir="$HOME/.local/bin/"
	if [ -d "${bin_install_dir}" ]; then
		mkdir -p ${bin_install_dir}
	fi

	cp -f ipfs ${bin_install_dir}
	chmod 755 ${bin_install_dir}"ipfs"

	# 对于有些发行版，bashrc 检查不到 ~/.local/bin 时不会将其加入 PATH，因此为了脚本继续运行，将其临时性加入，并等待用户下一次加入
	if ! command -v $ipfs &> /dev/null; then
		OUT_ERROR "${bin_install_dir} 没有被加入 PATH 变量中，如果出现“ipfs：未找到命令”的提示，尝试开一个新的命令行。
对于一些偷懒的系统(即使打开新的命令行也无济于事)，请修改 ~/.bashrc 文件，在末尾加入：
	PATH=\$PATH:${bin_install_dir}\n"
		PATH=$PATH:${bin_install_dir}
	fi

	

	OUT_INFO "ipfs 二进制文件已经被安装到 "${bin_install_dir}"ipfs。\n"

	systemd_service_path=""
	if [ -d "${XDG_CONFIG_HOME}/.config/systemd/user" ];then
		systemd_service_path="${XDG_CONFIG_HOME}/.config/systemd/user"
		OUT_INFO "发现 \$XDG_CONFIG_HOME 变量，systemd user servise 将被安装到 ${systemd_service_path}。\n"
	else
		systemd_service_path="${HOME}/.config/systemd/user"
		OUT_INFO "systemd user servise 将被安装到 ${systemd_service_path}。\n"
	fi

	cat >${tmpdir}/ipfs-daemon-user.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target
[Service]
ExecStart=$HOME/.local/bin/ipfs daemon --enable-gc --enable-pubsub-experiment
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOF
	cp ${tmpdir}/ipfs-daemon-user.service ${systemd_service_path}/ipfs-daemon.service
	systemd_user_arg="--user"
fi

# 督促 systemd 阅读 service 文件
systemctl $systemd_user_arg daemon-reload

# 干掉旧服务
systemctl $systemd_user_arg stop ipfs-daemon

# 初始化 ipfs
if [ ! -e $HOME/.ipfs/config ]; then
	ipfs init
	OUT_INFO "ipfs Initialized\n"
fi

# 询问外部访问
OUT_ALERT "是否需要设置外部访问？[y/n](默认=n,请在拥有公网ip且确保自己能设置好权限后使用。注意：此指令会向 ip.sb 暴露你的 ipv4 地址)\n"
yn=$(YES_NO no)
if [ $yn == yes ]; then
	public_ip=`curl -s -4 ip.sb`
	ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "POST"]'
	ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://'$public_ip':5010", "http://localhost:3000", "http://127.0.0.1:5001"]'
	ipfs config --json Addresses.API '"/ip4/0.0.0.0/tcp/5010"'
fi


# 提高 BitSwap 效率
OUT_INFO "配置 BitSwap...\n"
ipfs config --json Internal.Bitswap.TaskWorkerCount 256
ipfs config --json Internal.Bitswap.TaskWorkerCount 512
ipfs config --json Internal.Bitswap.EngineBlockstoreWorkerCount 4096
ipfs config --json Internal.Bitswap.EngineTaskWorkerCount 512
ipfs config --json Swarm.RelayService.Enabled true
ipfs config --json Reprovider.Interval '"1h"'


# 配置 Tracker
OUT_INFO "配置 Tracker...\n"
ipfs bootstrap add /dns4/checkpoint-hk.ipns.network/tcp/4001/p2p/12D3KooWQzZ931qqFJHER6wmmafMdV3ykxULczRsW83o5pJaBMTV
ipfs bootstrap add /dns4/checkpoint-sg.ipns.network/tcp/4001/p2p/12D3KooWNke2bS34fxQrGrnx27UbWMNsWLKDNPEEo8tLyS1K22Ee
ipfs bootstrap add /dns4/checkpoint-us.ipns.network/tcp/4001/p2p/12D3KooWSgRgfLxfDdi2eDRVBpBYFuTZp39HEBYnJm1upCUJ2GYz
ipfs config --json Peering.Peers '[{"Addrs": ["/dns4/checkpoint-hk.ipns.network/tcp/4001", "/dns4/checkpoint-hk.ipns.network/udp/4001/quic"], "ID": "12D3KooWQzZ931qqFJHER6wmmafMdV3ykxULczRsW83o5pJaBMTV"}, {"Addrs": ["/dns4/checkpoint-sg.ipns.network/tcp/4001", "/dns4/checkpoint-sg.ipns.network/udp/4001/quic"], "ID": "12D3KooWNke2bS34fxQrGrnx27UbWMNsWLKDNPEEo8tLyS1K22Ee"}, {"Addrs": ["/dns4/checkpoint-us.ipns.network/tcp/4001", "/dns4/checkpoint-us.ipns.network/udp/4001/quic"], "ID": "12D3KooWSgRgfLxfDdi2eDRVBpBYFuTZp39HEBYnJm1upCUJ2GYz"}]'
ipfs config --json Swarm.ConnMgr '{"GracePeriod": "30s","HighWater": 1024,"LowWater": 512,"Type": "basic"}'
ipfs config --json Datastore.GCPeriod '"12h"'

OUT_INFO "启动服务...\n"
systemctl $systemd_user_arg enable --now ipfs-daemon

# 说真的，这个等待真的有意义吗？
OUT_ALERT "稍等片刻"
for i in {1..15};do
	sleep 1s
	OUT_INFO "."
done
OUT "\n"

OUT_INFO "pin /ipns/ipfs-file.ipns.network and /ipns/install-sh.ipns.network...\n"
ipfs pin add /ipns/ipfs-file.ipns.network
ipfs pin add /ipns/install-sh.ipns.network
OUT_ALERT "安装完成"
