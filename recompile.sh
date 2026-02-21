#!/bin/bash
cd lib/rocksdb
./compile_rocksdb.sh
cd ../..
./scripts/zenfs_mkfs_clean.sh
make clean
make -j$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
