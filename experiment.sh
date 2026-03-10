#!/bin/bash

# sudo bin/working_version --size_ratio=10 --buffer_size_in_pages=256 --progress=1 --num_levels=4 --fs_uri=zenfs://dev:nvme0n1

# ./recompile.sh

KB=$((1024))
MB=$((1024 * $KB))
GB=$((1024 * $MB))

ssd_size_gb=32
zone_size_mb=128
file_size_mb=32
size_ratio=10
files_in_l0=4
level_count=4
workload_dist=uniform
key_size_b=16
value_size_b=4080
entry_count=7000000
workload_size_gb=$(( ((key_size_b + value_size_b) * entry_count + (GB / 2)) / GB ))
compaction_pri=3
gc_interval=10

reserve_count=10
gc_start_level=25
gc_stop_level=35
gc_slope=no

file_placement_policies=( "default" "caza" "zonekv" "our-oaza" "real-oaza" "overlap" "nearest" "hybrid1" "hybrid2" "hybrid3" "hybrid4" )

run_dbb="sudo ./bin/db_bench --benchmarks="fillrandom,stats" --num=${entry_count} \
        --write_buffer_size=$((file_size_mb * MB)) --target_file_size_base=$((file_size_mb * MB)) \
        --max_bytes_for_level_base=$((file_size_mb * MB * files_in_l0)) \
        --max_bytes_for_level_multiplier=${size_ratio} --num_levels=${level_count} \
        --key_size=${key_size_b} --value_size=${value_size_b} \
        --compression_type=none --max_background_compactions=1 --max_background_flushes=1 --perf_level=5 \
        --fs_uri=zenfs://dev:nvme0n1 --use_direct_io_for_flush_and_compaction"

entry_size=$((key_size_b+value_size_b))
run_wld="sudo ./bin/working_version --size_ratio=${size_ratio} --buffer_size_in_pages=$((file_size_mb*256)) \
        --progress=1 --num_levels=${level_count} --files_in_l0=${files_in_l0} --fs_uri=zenfs://dev:nvme0n1 \
        --entry_size=${entry_size} --entries_per_page=$((entry_size / 4096))"
echo $run_wld > curr_command.txt

dir=s${ssd_size_gb}_z${zone_size_mb}_fs${file_size_mb}_r${size_ratio}_fl0-${files_in_l0}_lc${level_count}_ws${workload_size_gb}_wd-${workload_dist}_ks${key_size_b}_vs${value_size_b}_ec${entry_count}_cp${compaction_pri}_gcint${gc_interval}
subdir_1=rsvz-${reserve_count}_gcstart-${gc_start_level}_gcstop-${gc_stop_level}_gcslp-${gc_slope}

for file_placement_policy in "${file_placement_policies[@]}"; do
    ./scripts/zenfs_mkfs_clean.sh
    echo ${file_placement_policy}
    subdir_2=fp-${file_placement_policy}
    fullpath=/home/afschy/${dir}/${subdir_1}/${subdir_2}

    PARAMFILE="./lib/rocksdb/plugin/zenfs/params.txt"
    sed -i  -e   "s/^logname .*/logname ${file_placement_policy}.log/" \
            -e   "s/^gc_pause_seconds .*/gc_pause_seconds ${gc_interval}/" \
            -e   "s/^gc_start_level .*/gc_start_level ${gc_start_level}/" \
            -e   "s/^reserve_zone_count .*/reserve_zone_count ${reserve_count}/" \
            -e   "s/^buffer_size_megabytes .*/buffer_size_megabytes $((file_size_mb + 1))/" \
        ${PARAMFILE}
    ./scripts/setup_${file_placement_policy}.sh

    if [[ "${gc_stop_level}" != "no" ]]; then
        sed -i  -e "s/^gc_stop_level .*/gc_stop_level ${gc_stop_level}/" \
                -e "s/^gc_type .*/gc_type kImprovedGC/" \
            ${PARAMFILE}
    fi
    if [[ "${gc_slope}" != "no" ]]; then
        sed -i  -e "s/^gc_slope .*/gc_slope ${gc_slope}/" \
                -e "s/^gc_type .*/gc_type kDefaultGC/" \
        ${PARAMFILE}
    fi

    # eval $run_dbb > stdout.log 2>&1
    eval $run_wld > stdout.log 2>&1

    # sudo chmod 777 /home/afschy/db_extra
    # sudo chmod 777 /home/afschy/db_extra/rocksdbtest
    # sudo chmod 777 /home/afschy/db_extra/rocksdbtest/dbbench
    # mv /home/afschy/db_extra/rocksdbtest/dbbench/LOG ./rocksdb.log

    sudo chmod 777 /home/afschy/db_extra
    sudo chmod 777 /home/afschy/db_extra/db
    mv /home/afschy/db_extra/db/LOG ./rocksdb.log

    timestamp=$(date +"%y-%m-%d_%H-%M")
    for file in *.log; do
        [ -e "$file" ] || continue
        filename="${file%.*}"
        extension="${file##*.}"
        mv "$file" "${filename}_${timestamp}.${extension}"
    done

    mkdir -p ${fullpath}
    mv *.log ${fullpath}/
done

sudo chown -R afschy /home/afschy/${dir}
