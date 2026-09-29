#!/bin/sh

apt-get install -y iproute2

if [ ! -d /user ]; then
echo No User volume mount !
echo mount host root user to container in yaml !
exit 0
fi

mkdir -p /user/.ssh
chmod 700 /user/.ssh
if [ ! -f /user/.ssh/id_docker ]; then
printf '\n\n\n' | ssh-keygen -q -N "" -f /user/.ssh/id_docker
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
# swap is (re)created below, after the disk cleanup (it needs free space, and
# /mnt already holds the image's own swapfile which we replace).
# Doing it on the HOST (not inside the container) is what avoids
# "mkswap: /swapfile is mounted; will not make swapspace" -- that error happens
# because the swap table is kernel-global, so the container sees the host's
# already-active swap. GitHub x86_64 runners ship an active 4G /mnt/swapfile
# (arm64: 3G /swapfile) -- 4G is not enough for the GCC LTO WPA/link phase.
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
# NOTE: the remote command MUST be quoted, otherwise '> /sys/...' redirection and
# '*' globs are evaluated by the *container* shell instead of the host shell.
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'chmod 0755 /sys /sys/* /sys/module /sys/module/* /sys/kernel/debug'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'chmod 0755 /sys/module/zswap/parameters'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'chmod 0644 /sys/module/zswap/parameters/*'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo N > /sys/module/zswap/parameters/enabled'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo lz4 > /sys/module/zswap/parameters/compressor'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo zsmalloc > /sys/module/zswap/parameters/zpool'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo Y > /sys/module/zswap/parameters/enabled'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo 4100000 > /sys/kernel/debug/sched/latency_ns'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo 620000 > /sys/kernel/debug/sched/min_granularity_ns'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo 360000 > /sys/kernel/debug/sched/wakeup_granularity_ns'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'echo 400000 > /sys/kernel/debug/sched/migration_cost_ns'
# dpkg-query format must stay single-quoted on the HOST (its ${...} are dpkg
# substitutions, not shell vars) -- hence the '\'' quoting dance.
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'dpkg-query -Wf '\''${Installed-Size}\t${Package}\n'\'' | sort -n | tail -n 100'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker rm -rf /usr/local/lib/android
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker rm -rf /usr/share/dotnet
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker rm -rf /opt/ghc
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker rm -rf /usr/local/.ghcup
# '$AGENT_TOOLSDIRECTORY' must expand on the HOST (it is a runner env var there),
# so the whole remote command has to be quoted.
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'rm -rf "$AGENT_TOOLSDIRECTORY"'
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker apt-get purge -y '^aspnetcore-.*' '^dotnet-.*' '^llvm-.*' 'php.*' '^mongodb-.*' '^mysql-.*' '^ghc-.*' azure-cli google-chrome-stable firefox powershell hhvm mono-devel libgl1-mesa-dri google-cloud-sdk google-cloud-cli --autoremove --purge --fix-missing
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker apt-get clean
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker docker image prune --all --force

echo "=> Replace the default 4G swap with a 7G one on ${DOCKER_HOST}"
# Runs last so the disk cleanup above already freed space. Everything must happen
# on the HOST: the swap table is kernel-global, which is why a container-side
# "mkswap /swapfile" fails with "is mounted; will not make swapspace" and "swapon"
# would fail with EBUSY.
# 'swapoff FILE && rm -f FILE' per file: never delete a swapfile that is still
# active (swapoff can fail under memory pressure; rm'ing an in-use one would
# orphan it and leak the space).
# Then try, in order: 7G on /swapfile (OS disk, roomiest), 7G on /mnt/swapfile
# (the local temp disk, where the image puts its own 4G), then 3G on each.
# The 3G pass matters because the original 4G swap is already gone by then --
# ending up with *zero* swap would turn the LTO link into a guaranteed OOM.
# Each attempt removes any partial file first/afterwards so a failed dd cannot
# make the next fallocate on the same path fail.
ssh root@$DOCKER_HOST -o "StrictHostKeyChecking=no" -i /user/.ssh/id_docker 'swapoff /swapfile 2>/dev/null && rm -f /swapfile; swapoff /mnt/swapfile 2>/dev/null && rm -f /mnt/swapfile; for SPEC in 7:/swapfile 7:/mnt/swapfile 3:/swapfile 3:/mnt/swapfile; do S=${SPEC%%:*}; T=${SPEC#*:}; rm -f $T; fallocate -l ${S}G $T || { dd if=/dev/zero of=$T bs=1M count=$((S*1024)) || { rm -f $T; continue; }; }; chmod 600 $T; mkswap $T && swapon $T && break; rm -f $T; done; echo "--- swap now ---"; swapon --show; free -h'
exit 0
