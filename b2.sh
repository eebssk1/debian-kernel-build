#!/bin/sh

wget $1

sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install gcc-11
sudo apt-get upgrade binutils

dpkg-deb --extract *.deb .
tar -xf usr/src/linux-source-*.*

rm -rf *.deb usr

wget https://salsa.debian.org/kernel-team/linux/-/raw/master/debian/certs/debian-uefi-certs.pem

sudo apt install libelf-dev libssl-dev dwarves bc jitterentropy-rngd schedtool

cd $(find -type d -name linux-source-*)

cp ../config .config

mkdir -p debian/certs
mv ../debian-uefi-certs.pem debian/certs/

for a in ../*.patch
do
patch -i $a -s -f -p1
done

export XXYH="-fipa-pta -fira-loop-pressure -fira-region=all -flive-range-shrinkage -flimit-function-alignment -floop-nest-optimize -fschedule-insns -fsched-pressure -fsched-spec-load -fsched-stalled-insns=1 -ftree-lrs --param=predictable-branch-outcome=6 --param=max-crossjump-edges=160 --param=max-delay-slot-insn-search=132 --param=max-gcse-insertion-ratio=22 --param=max-pending-list-length=36 --param=max-inline-insns-auto=40 --param=inline-heuristics-hint-percent=672 --param=inline-min-speedup=12 --param=large-function-growth=112 --param=inline-unit-growth=46 --param=ipa-cp-unit-growth=14 --param=max-inline-insns-recursive=500 --param=max-inline-insns-recursive-auto=500 --param=max-inline-recursive-depth-auto=10 --param=max-inline-recursive-depth=10 --param=gcse-cost-distance-ratio=12 --param=max-hoist-depth=50 --param=max-tail-merge-comparisons=12 --param=max-tail-merge-iterations=4 --param=max-stores-to-merge=80 --param=avg-loop-niter=12 --param=dse-max-alias-queries-per-store=274 --param=dse-max-object-size=274 --param=max-reload-search-insns=132 --param=max-sched-ready-insns=160 --param analyzer-max-recursion-depth=4 --param sched-autopref-queue-depth=2 --param uninit-control-dep-attempts=1280 --param max-slsr-cand-scan=76 --param sched-pressure-algorithm=2 --param=parloops-schedule=dynamic"
export KCFLAGS="-fgraphite -fgraphite-identity $XXYH"
make oldconfig CC=gcc-11
schedtool -B -e make bindeb-pkg -j3 CC=gcc-11
