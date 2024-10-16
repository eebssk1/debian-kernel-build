#!/bin/sh

if [ "x$1" = "x" ]; then
echo "No target!"
exit 1
fi

apt-get update
apt-get upgrade -y
apt-get install -y libelf-dev libssl-dev dwarves bc kmod cpio python3 zstd debhelper|| exit 1

FILE=$(cat version)-xanmod1.tar.bz2

wget https://gitlab.com/xanmod/linux/-/archive/$FILE
tar --bzip2 -xf $FILE || exit 1
rm $FILE

if [ x$2 = xgcc ]; then
curl -L https://github.com/eebssk1/aio_tc_build/releases/latest/download/x86_64-linux-gnu-native.tb2 | tar --bz -xf -
mv x86_64-linux-gnu /opt/newcc
chown -R root:root /opt/newcc
else
curl -L https://github.com/eebssk1/aio_tc_build/releases/download/20240425_llvm/llvm_18.1.4.tgz | tar -zxf -
mv llvm_18.1.4 /opt/newclang
chown -R root:root /opt/newclang
fi

echo VER=$(cat version) >> $GITHUB_ENV

cd linux-* || exit 1

for a in ../patch/rev/*.patch; do
[ -f "$a" ] || continue
echo Revesing $a
patch -R -p1 -i $a || exit 128
done

for a in ../patch/cp/*.patch; do
[ -f "$a" ] || continue
echo Applying $a
patch -f -p1 -i $a || exit 128
done

for a in ../patch/cl/*.patch; do
[ -f "$a" ] || continue
echo Applying $a
patch -f -p1 -i $a || exit 128
done

for a in ../patch/bbr/*.patch; do
[ -f "$a" ] || continue
echo Revesing $a
patch -R -p1 -i $a || exit 128
done

if [ -e ../bbr.c ]; then
mv ../bbr.c net/ipv4/tcp_bbr.c
fi

if [ -e /opt/newcc/bin ]; then
export PATH=/opt/newcc/bin:$PATH
fi

if [ -e /opt/newclang/bin ]; then
export PATH=/opt/newclang/bin:$PATH
fi

hash -r

if [ x$2 = xgcc ]; then
KCFLAGS="-fipa-pta -D__1ENABLE_AGGRESSIVE_GRAPHITE9__ @$PWD/../gp.txt"
else
KCFLAGS="-mllvm --enable-knowledge-retention=true -mllvm --polly=true -mllvm --polly-vectorizer=stripmine -mllvm --polly-default-tile-size=32 -mllvm --polly-2nd-level-default-tile-size=8  -mllvm --polly-2nd-level-tiling=true -mllvm --polly-run-inliner=true -mllvm --polly-opt-max-constant-term=48 -mllvm --polly-opt-max-coefficient=48  -mllvm --polly-register-tiling=true -mllvm --polly-run-dce=true -mllvm --polly-detect-profitability-min-per-loop-insts=52 -mllvm --polly-invariant-load-hoisting=true -mllvm --extra-vectorizer-passes=true -mllvm --enable-loop-flatten=true -mllvm --enable-gvn-hoist=true -mllvm --enable-matrix=true -mllvm --enable-constraint-elimination=true -mllvm --enable-module-inliner=true -mllvm --thinlto-synthesize-entry-counts=true"
fi

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
export KCFLAGS="$KCFLAGS -mtune=westmere"
cp ../config_ser2 .config || exit 1
else
echo "No such target!"
exit 1
fi

if [ x$2 = xgcc ]; then
export CC=gcc
else
export CC=clang
export LLVM=1
fi

if [ "x$(which ccache)" != "x" ]; then
echo "Found ccache !"
ccache -o compression_level=3
ccache -o sloppiness=locale
export CC="ccache $CC"
fi

make olddefconfig CC="$CC"
make bindeb-pkg -j3 V=1 CC="$CC"
