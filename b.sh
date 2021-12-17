#!/bin/sh

wget $1

git clone --depth 1 https://github.com/kdrag0n/proton-clang

export PATH=${PWD}/proton-clang/bin:$PATH

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
export KCFLAGS="-mllvm -polly-run-inliner -mllvm -polly-opt-fusion=max -mllvm -polly-ast-use-context -mllvm -polly-invariant-load-hoisting"
schedtool -B -e make bindeb-pkg -j3 CC=clang LLVM=1
