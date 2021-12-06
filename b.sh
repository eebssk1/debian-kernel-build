#!/bin/sh

wget $1

dpkg-deb --extract *.deb .
tar -xf usr/src/linux-source-*.*

rm -rf *.deb usr

wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 12

sudo apt install libelf-dev libssl-dev dwarves bc lld

cd $(find -type d -name linux-source-*)

cp ../config .config

for a in ../*.patch
do
patch -i $a -s -f -p1
done

make bindeb-pkg -j CC=clang-12 LD=ld.lld-12 AS=llvm-as-12 NM=llvm-nm-12 AR=llvm-ar-12
