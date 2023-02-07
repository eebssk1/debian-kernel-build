#!/bin/sh

wget $1

sudo apt-get update
sudo apt-get install gcc-12
sudo apt-get upgrade binutils

dpkg-deb --extract *.deb .
tar -xf usr/src/linux-source-*.*

rm -rf *.deb usr

wget https://salsa.debian.org/kernel-team/linux/-/raw/master/debian/certs/debian-uefi-certs.pem

sudo apt install libelf-dev libssl-dev dwarves bc

cd $(find -type d -name linux-source-*)

cp ../config .config

mkdir -p debian/certs
mv ../debian-uefi-certs.pem debian/certs/

for a in ../*.patch
do
patch -i $a -s -f -p1
done

export KCFLAGS="-falign-jumps=16 -falign-labels=8 -falign-loops=16 -fgcse-las -fgcse-sm -fgraphite -fgraphite-identity -fipa-pta -fira-region=all -flimit-function-alignment -flive-range-shrinkage -fsched-pressure -fsched-spec-load -fsched-stalled-insns -fsched-stalled-insns-dep=2 -fschedule-insns -fsimd-cost-model=dynamic -ftree-cselim -ftree-lrs -ftree-vectorize -fweb -malign-data=cacheline -momit-leaf-frame-pointer -mrelax-cmpxchg-loop --param=predictable-branch-outcome=4 --param=max-crossjump-edges=300 --param=max-delay-slot-insn-search=325 --param=inline-heuristics-hint-percent=615 --param=inline-min-speedup=35 --param=max-inline-recursive-depth-auto=10 --param=max-inline-recursive-depth=12 --param=min-inline-recursive-probability=12 --param=modref-max-adjustments=15 --param=modref-max-depth=325 --param=min-vect-loop-bound=2 --param=gcse-cost-distance-ratio=13 --param=gcse-unrestricted-cost=2 --param=max-hoist-depth=90 --param=avg-loop-niter=6 --param=dse-max-object-size=368 --param=dse-max-alias-queries-per-store=320 --param=scev-max-expr-size=128 --param=scev-max-expr-complexity=12 --param=max-predicted-iterations=154 --param=max-reload-search-insns=185 --param=max-cselib-memory-locations=600 --param=max-sched-ready-insns=190 --param=sched-autopref-queue-depth=3 --param=analyzer-max-recursion-depth=5 --param=gimple-fe-computed-hot-bb-threshold=3 --param=max-cse-path-length=16 --param=max-rtl-if-conversion-insns=20 --param=max-sched-extend-regions-iters=4 --param=max-stores-to-sink=3 --param=ranger-logical-depth=12 --param=vect-partial-vector-usage=1 --param=analyzer-bb-explosion-factor=6 --param=analyzer-max-enodes-per-program-point=10 --param=hash-table-verification-limit=16 --param=fsm-scale-path-blocks=4 --param=fsm-scale-path-stmts=3 --param=graphite-max-arrays-per-scop=160 --param=sms-max-ii-factor=3 --param=sms-dfa-history=2 --param=sms-loop-average-count-threshold=5 --param=unroll-jam-min-percent=3 --param=max-ssa-name-query-depth=4  --param=max-slsr-cand-scan=120 --param=max-sched-extend-regions-iters=3 --param=scev-max-expr-complexity=16 --param=scev-max-expr-size=128 --param=min-vect-loop-bound=3"

export CC=gcc-12
export CXX=g++-12
if [ "x$(which ccache)" != "x" ]; then
export CC="ccache gcc-12"
export CXX="ccache g++-12"
ccache -o compression_level=4
ccache -o limit_multiple=0.9
ccache -o sloppiness=random_seed
fi

make oldconfig
make bindeb-pkg -j3 CC="$CC" CXX="$CXX"
