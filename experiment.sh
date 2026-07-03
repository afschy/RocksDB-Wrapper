#!/bin/bash

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
export ZENFS_PARAMS="${ZENFS_PARAMS:-${REAL_HOME}/RocksDB-Wrapper/lib/rocksdb/plugin/zenfs/params.txt}"

KB=$((1024))
MB=$((1024 * $KB))
GB=$((1024 * $MB))

ssd_size_gb=32
zone_size_mb=256
file_size_mb=4
size_ratio=10
files_in_l0=64
level_count=4
workload_dist=ycsb-a
key_size_b=19
value_size_b=4077
entry_count=7500000
workload_size_gb=$(( ((key_size_b + value_size_b) * entry_count + (GB / 2)) / GB ))
compaction_pri=3
gc_interval=10

reserve_count=10
gc_start_level=25
gc_stop_level=35
gc_slope=no

dbbench_or_tectonic=tectonic

file_placement_policies=( "real-oaza" "zonekv" "plaza-base" "plaza-int-4" "plaza-int-8" "plaza-int-12" "plaza-adv-0.8-4" "plaza-adv-0.5-4" "plaza-adv-0.8-8" "plaza-adv-0.5-8" )

run_dbb="env ZENFS_PARAMS=$ZENFS_PARAMS ./bin/db_bench --benchmarks="fillrandom,stats" --num=${entry_count} \
        --write_buffer_size=$((file_size_mb * MB)) --target_file_size_base=$((file_size_mb * MB)) \
        --max_bytes_for_level_base=$((file_size_mb * MB * files_in_l0)) \
        --max_bytes_for_level_multiplier=${size_ratio} --num_levels=${level_count} \
        --key_size=${key_size_b} --value_size=${value_size_b} --compaction_pri=${compaction_pri} \
        --compression_type=none --max_background_compactions=1 --max_background_flushes=1 --perf_level=5 \
        --fs_uri=zenfs://dev:nvme0n1 --use_direct_io_for_flush_and_compaction"

entry_size=$((key_size_b+value_size_b))
run_wld="env ZENFS_PARAMS=$ZENFS_PARAMS ./bin/working_version --size_ratio=${size_ratio} --buffer_size_in_pages=$((file_size_mb*256)) \
        --progress=1 --num_levels=${level_count} --files_in_l0=${files_in_l0} --fs_uri=zenfs://dev:nvme0n1 \
        --entry_size=${entry_size} --entries_per_page=$((4096 / entry_size)) --compaction_pri=${compaction_pri}"

if [[ "${dbbench_or_tectonic}" == "dbbench" ]]; then
    echo $run_dbb > curr_command.txt
elif [[ "${dbbench_or_tectonic}" == "tectonic" ]]; then
    echo $run_wld > curr_command.txt
fi

dir=s${ssd_size_gb}_z${zone_size_mb}_fs${file_size_mb}_r${size_ratio}_fl0-${files_in_l0}_lc${level_count}_ws${workload_size_gb}_wd-${workload_dist}_ks${key_size_b}_vs${value_size_b}_ec${entry_count}_cp${compaction_pri}_gcint${gc_interval}
subdir_1=rsvz-${reserve_count}_gcstart-${gc_start_level}_gcstop-${gc_stop_level}_gcslp-${gc_slope}

# Handles the plaza-int / plaza-adv variants, which reuse a single setup script
# instead of having a dedicated one per variant. The base script is called first,
# then the variant-specific parameters are overridden.
#   plaza-int-x        -> setup_plaza-int.sh, then logname + zones_to_open (1,1,x,x)
#   plaza-adv-f-x      -> setup_plaza-adv.sh, then logname + zones_to_open (1,1,x,x)
#                         + zone_fill_threshold (f)
# The numeric part is only used when it parses cleanly; otherwise it falls back to
# the defaults. So bare "plaza-int" and any malformed "plaza-int-*" resolve to
# plaza-int-4, and bare "plaza-adv" / malformed "plaza-adv-*" to plaza-adv-0.8-4.
setup_plaza_variant() {
    local policy="$1"

    if [[ "${policy}" == plaza-int* ]]; then
        local x=4
        [[ "${policy}" =~ ^plaza-int-([0-9]+)$ ]] && x="${BASH_REMATCH[1]}"
        ./scripts/setup_plaza-int.sh
        sed -i  -e "s/^logname .*/logname plaza-int-${x}.log/" \
                -e "s/^zones_to_open .*/zones_to_open 1,1,${x},${x}/" \
            ${ZENFS_PARAMS}
    elif [[ "${policy}" == plaza-adv* ]]; then
        local f=0.8 x=4
        if [[ "${policy}" =~ ^plaza-adv-([0-9]*\.?[0-9]+)-([0-9]+)$ ]]; then
            f="${BASH_REMATCH[1]}"
            x="${BASH_REMATCH[2]}"
        fi
        ./scripts/setup_plaza-adv.sh
        sed -i  -e "s/^logname .*/logname plaza-adv-${f}-${x}.log/" \
                -e "s/^zones_to_open .*/zones_to_open 1,1,${x},${x}/" \
                -e "s/^zone_fill_threshold .*/zone_fill_threshold ${f}/" \
            ${ZENFS_PARAMS}
    else
        echo "setup_plaza_variant: '${policy}' is not a plaza variant" >&2
        return 1
    fi
}

for file_placement_policy in "${file_placement_policies[@]}"; do
    ./scripts/zenfs_mkfs_clean.sh
    echo ${file_placement_policy}
    subdir_2=fp-${file_placement_policy}
    fullpath=${REAL_HOME}/${dir}/${subdir_1}/${subdir_2}

    sed -i  -e   "s/^logname .*/logname ${file_placement_policy}.log/" \
            -e   "s/^gc_pause_seconds .*/gc_pause_seconds ${gc_interval}/" \
            -e   "s/^gc_start_level .*/gc_start_level ${gc_start_level}/" \
            -e   "s/^reserve_zone_count .*/reserve_zone_count ${reserve_count}/" \
            -e   "s/^buffer_size_megabytes .*/buffer_size_megabytes $((file_size_mb + 1))/" \
        ${ZENFS_PARAMS}

    if [[ "${file_placement_policy}" == plaza-int* || "${file_placement_policy}" == plaza-adv* ]]; then
        setup_plaza_variant "${file_placement_policy}"
    else
        ./scripts/setup_${file_placement_policy}.sh
    fi

    if [[ "${gc_stop_level}" != "no" ]]; then
        sed -i  -e "s/^gc_stop_level .*/gc_stop_level ${gc_stop_level}/" \
                -e "s/^gc_type .*/gc_type kImprovedGC/" \
            ${ZENFS_PARAMS}
    fi
    if [[ "${gc_slope}" != "no" ]]; then
        sed -i  -e "s/^gc_slope .*/gc_slope ${gc_slope}/" \
                -e "s/^gc_type .*/gc_type kDefaultGC/" \
        ${ZENFS_PARAMS}
    fi

    if [[ "${dbbench_or_tectonic}" == "dbbench" ]]; then
        eval $run_dbb > stdout.log 2>&1
        # mv ${REAL_HOME}/db_extra/rocksdbtest/dbbench/LOG ./rocksdb.log
    elif [[ "${dbbench_or_tectonic}" == "tectonic" ]]; then
        eval $run_wld > stdout.log 2>&1
        # mv ${REAL_HOME}/db_extra/db/LOG ./rocksdb.log
    fi

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

sudo chown -R ${REAL_USER} ${REAL_HOME}/${dir}
