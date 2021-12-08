#!/bin/sh

wget $1

git clone --depth 1 https://github.com/kdrag0n/proton-clang

export PATH=${PWD}/proton-clang/bin:$PATH

dpkg-deb --extract *.deb .
tar -xf usr/src/linux-source-*.*

rm -rf *.deb usr

#wget https://apt.llvm.org/llvm.sh
#chmod +x llvm.sh
#sudo ./llvm.sh 12

sudo apt install libelf-dev libssl-dev dwarves bc jitterentropy-rngd schedtool

cd $(find -type d -name linux-source-*)

cp ../config .config

for a in ../*.patch
do
patch -i $a -s -f -p1
done
export KCFLAGS="-mllvm -polly"
schedtool -B -e make bindeb-pkg -j2 CC=clang LD=ld.lld AS=llvm-as NM=llvm-nm AR=llvm-ar
