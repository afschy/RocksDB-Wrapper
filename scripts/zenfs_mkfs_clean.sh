#!/bin/bash

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

rm -rf ${REAL_HOME}/db_extra*
echo deadline | tee -a /sys/class/block/nvme0n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme1n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme2n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme3n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme4n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme5n1/queue/scheduler
# echo deadline | tee -a /sys/class/block/nvme6n1/queue/scheduler
cd lib/rocksdb/plugin/zenfs/util
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme0n1 --aux_path=${REAL_HOME}/db_extra/
rm -f *.log
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme1n1 --aux_path=${REAL_HOME}/db_extra_1/
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme2n1 --aux_path=${REAL_HOME}/db_extra_2/
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme3n1 --aux_path=${REAL_HOME}/db_extra_3/
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme4n1 --aux_path=${REAL_HOME}/db_extra_4/
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme5n1 --aux_path=${REAL_HOME}/db_extra_5/
# LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme6n1 --aux_path=${REAL_HOME}/db_extra_6/
rm -f *.log
