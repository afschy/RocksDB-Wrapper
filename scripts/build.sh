#!/bin/bash

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

cd ..
sudo rm -rf ${REAL_HOME}/db_extra/*
echo deadline | sudo tee -a /sys/class/block/nvme0n1/queue/scheduler
# rm -r build
# mkdir build
cd build
cmake ..
cmake --build . --parallel 60
sudo cmake --install .
cd ../lib/rocksdb/plugin/zenfs/util
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make clean
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig make
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme0n1 --aux_path=${REAL_HOME}/db_extra/