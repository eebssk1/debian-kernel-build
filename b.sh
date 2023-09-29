#!/bin/sh

apt-get install -y libelf-dev libssl-dev dwarves bc

cd linux-*

cp ../config .config

make oldconfig LLVM=1

make bindeb-pkg -j4 LLVM=1
