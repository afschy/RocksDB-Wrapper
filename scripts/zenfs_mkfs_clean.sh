#!/bin/bash

sudo rm -rf /home/afschy/db_extra*
echo deadline | sudo tee -a /sys/class/block/nvme0n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme1n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme2n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme3n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme4n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme5n1/queue/scheduler
echo deadline | sudo tee -a /sys/class/block/nvme6n1/queue/scheduler
cd lib/rocksdb/plugin/zenfs/util
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme0n1 --aux_path=/home/afschy/db_extra/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme1n1 --aux_path=/home/afschy/db_extra_1/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme2n1 --aux_path=/home/afschy/db_extra_2/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme3n1 --aux_path=/home/afschy/db_extra_3/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme4n1 --aux_path=/home/afschy/db_extra_4/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme5n1 --aux_path=/home/afschy/db_extra_5/
sudo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib ./zenfs mkfs --force --zbd=nvme6n1 --aux_path=/home/afschy/db_extra_6/
