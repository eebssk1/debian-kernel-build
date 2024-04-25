#!/bin/sh

if [ "x$1" = "x" ]; then
echo "No target!"
exit 1
fi

apt-get update
apt-get upgrade -y
apt-get install -y libelf-dev libssl-dev dwarves bc kmod cpio python3 zstd debhelper|| exit 1

curl -L https://gitlab.com/xanmod/linux/-/archive/$(cat version)-xanmod1.tar.bz2 | tar --bzip2 -xf - || exit 1

curl -L https://github.com/eebssk1/aio_tc_build/releases/download/20240425_llvm/llvm_18.1.4.tgz | tar -zxf -

mv llvm_18.1.4 /opt/newclang
chown -R root:root /opt/newclang

echo VER=$(cat version) >> $GITHUB_ENV

cd linux-* || exit 1

for a in ../patch/cp/*.patch; do
[ -f "$a" ] || continue
echo Applying $a
patch -f -p1 -i $a
done

for a in ../patch/cl/*.patch; do
[ -f "$a" ] || continue
echo Applying $a
patch -f -p1 -i $a
done

for a in ../patch/rev/*.patch; do
[ -f "$a" ] || continue
echo Revesing $a
patch -R -p1 -i $a
done


if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
fi

if [ -e /opt/newclang/bin ]; then
export PATH=/opt/newclang/bin:$PATH
fi


KCFLAGS="-O3 -mllvm --enable-knowledge-retention=true -mllvm --polly=true -mllvm --polly-vectorizer=stripmine -mllvm --polly-default-tile-size=36 -mllvm --polly-2nd-level-default-tile-size=10  -mllvm --polly-2nd-level-tiling=true -mllvm --polly-run-inliner=true -mllvm --polly-opt-max-constant-term=51 -mllvm --polly-opt-max-coefficient=51  -mllvm --polly-register-tiling=true -mllvm --polly-run-dce=true -mllvm --polly-detect-profitability-min-per-loop-insts=50 -mllvm --polly-invariant-load-hoisting=true -mllvm --enable-partial-inlining=true -mllvm --extra-vectorizer-passes=true -mllvm --enable-loop-flatten=true -mllvm --enable-gvn-hoist=true -mllvm --enable-matrix=true -mllvm --enable-constraint-elimination=true -mllvm --hot-cold-split=true -mllvm --hotcoldsplit-threshold=4 -mllvm --hotcoldsplit-max-params=2 -mllvm --hotcoldsplit-cold-probability-denom=85 -mllvm --enable-module-inliner=true -mllvm --thinlto-synthesize-entry-counts=true"

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
export KCFLAGS="$KCFLAGS -mtune=broadwell"
cp ../config_ser2 .config || exit 1
else
echo "No such target!"
exit 1
fi

if [ "x$(which ccache)" != "x" ]; then
ccache -o compression_level=2
ccache -o sloppiness=locale
make bindeb-pkg -j3 LLVM=1 CC="ccache clang"
else
make bindeb-pkg -j3 LLVM=1
fi
