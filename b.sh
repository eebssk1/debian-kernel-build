#!/bin/sh

if [ "x$1" = "x" ]; then
echo "No target!"
exit 1
fi

apt-get update
apt-get upgrade -y
apt-get install -y libelf-dev libssl-dev dwarves bc kmod cpio python3 zstd|| exit 1

curl -L "$(cat url)" | tar --bzip2 -xf - || exit 1

cd linux-* || exit 1

for a in ../*.patch; do
patch -f -p1 -i $a
done

KCFLAGS="-mllvm --polly=true -mllvm --polly-vectorizer=stripmine -mllvm --polly-2nd-level-tiling=true -mllvm --polly-run-inliner=true -mllvm --polly-opt-max-constant-term=30 -mllvm --polly-opt-max-coefficient=30 -mllvm --polly-register-tiling=true -mllvm --polly-run-dce=true -mllvm --polly-detect-profitability-min-per-loop-insts=45 -mllvm --polly-invariant-load-hoisting=true -mllvm --slp-min-reg-size=64 -mllvm --enable-partial-inlining=true -mllvm --extra-vectorizer-passes=true -mllvm --enable-loop-flatten=true -mllvm --enable-gvn-hoist=true -mllvm --enable-matrix=true -mllvm --enable-constraint-elimination=true -mllvm --reroll-loops=true -mllvm --hot-cold-split=true -mllvm --cost-kind=size-latency"

if [ "$1" = "desktop" ]; then
export KCFLAGS="$KCFLAGS -mtune=skylake"
cp ../config_desk .config || exit 1
elif [ "$1" = "server_large" ]; then
export KCFLAGS="$KCFLAGS -mtune=broadwell"
cp ../config_serl .config || exit 1
elif [ "$1" = "server_small" ]; then
export KCFLAGS="$KCFLAGS -mtune=skylake"
cp ../config_serm .config || exit 1
elif [ "$1" = "server_small_2" ]; then
export KCFLAGS="$KCFLAGS -mtune=sandybridge"
cp ../config_ser2 .config || exit 1
else
echo "No such target!"
exit 1
fi

make oldconfig LLVM=1  || exit 1

if [ "x$(which ccache)" != "x" ]; then
make bindeb-pkg -j2 LLVM=1 CC="ccache clang"
else
make bindeb-pkg -j2 LLVM=1
fi
