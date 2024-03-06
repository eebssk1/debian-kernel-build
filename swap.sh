#!/bin/sh

apt-get install -y iproute2

if [ ! -d /user ]; then
echo No User volume mount !
exit 0
fi

mkdir -p /user/.ssh
chmod 700 /user/.ssh
if [ ! -f /user/.ssh/id_docker ]; then
echo -e "\n\n\n" | ssh-keygen -N "" -f /user/.ssh/id_docker
echo "=> Updating Authorized Keys"
touch /user/.ssh/authorized_keys
chmod 600 /user/.ssh/authorized_keys
cat /user/.ssh/id_docker.pub >> /user/.ssh/authorized_keys
fi
echo Container Inf
mount
ip addr
DOCKER_HOST=$(ip route|awk '/default/ { print $3  }')
echo Host Inf
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker ip addr
echo "=> Creating swap on ${DOCKER_HOST}"
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker fallocate -l 7G /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker chmod 600 /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mkswap /swapfile
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker swapon /swapfile
echo "=> Setting sysctl on ${DOCKER_HOST}"
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.swappiness=66
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.vfs_cache_pressure=70
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.page-cluster=1
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.dirty_background_ratio=15
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl vm.dirty_ratio=15
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl kernel.io_delay_type=2
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker sysctl net.ipv4.tcp_congestion_control=bbr

echo "=> try enable zswap and tune on ${DOCKER_HOST}"
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker apt-get install -y jitterentropy-rngd
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -o remount,rw /
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -o remount,rw /sys
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker mount -o remount,rw /sys/kernel/debug
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker chmod 0755 /sys /sys/* /sys/module  /sys/module/* /sys/kernel/debug
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker chmod 0755 /sys/module/zswap/parameters/
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker chmod 0644 /sys/module/zswap/parameters/*
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo lz4 > /sys/module/zswap/parameters/compressor
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo zsmalloc > /sys/module/zswap/parameters/zpool
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo Y > /sys/module/zswap/parameters/enabled
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 4100000 > /sys/kernel/debug/sched/latency_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 620000 > /sys/kernel/debug/sched/min_granularity_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 360000 > /sys/kernel/debug/sched/wakeup_granularity_ns
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker echo 400000 > /sys/kernel/debug/sched/migration_cost_ns
exit 0
