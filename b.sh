#!/bin/sh

if [ "x$1" = "x" ]; then
echo "No target!"
exit 1
fi

apt-get install -y libelf-dev libssl-dev dwarves bc kmod cpio python3 zstd|| exit 1

curl -L "$(cat url)" | tar --bzip2 -xf - || exit 1

cd linux-* || exit 1

for a in ../*.patch; do
patch -f -p1 -i $a
done

KCFLAGS="-Wno-ignored-optimization-argument -mllvm --polly=true -mllvm --polly-run-inliner=true -mllvm --polly-opt-max-constant-term=31 -mllvm --polly-opt-max-coefficient=31 -mllvm --polly-register-tiling=true -mllvm --polly-run-dce=true -mllvm --slp-min-reg-size=64 -mllvm --enable-partial-inlining=true -mllvm --extra-vectorizer-passes=true -mllvm --enable-loop-flatten=true -mllvm --hot-cold-split=true -mllvm --enable-gvn-hoist=true -mllvm --enable-matrix=true -mllvm --enable-constraint-elimination=true -mllvm --reroll-loops=true"

if [ "$1" = "desktop" ]; then
export KCFLAGS="$KCFLAGS -mtune=skylake"
cp ../config_desk .config || exit 1
elif [ "$1" = "server_large" ]; then
export KCFLAGS="$KCFLAGS -mtune=broadwell"
cp ../config_serl .config || exit 1
elif [ "$1" = "server_small" ]; then
export KCFLAGS="$KCFLAGS -mtune=broadwell"
cp ../config_serm .config || exit 1
elif [ "$1" = "server_small_2" ]; then
export KCFLAGS="$KCFLAGS -mtune=sandybridge"
cp ../config_ser2 .config || exit 1
else
echo "No such target!"
exit 1
fi

if [ "x$(which ccache)" != "x" ]; then
export CC="ccache clang"
fi

make oldconfig LLVM=1  || exit 1

make bindeb-pkg -j2 LLVM=1
