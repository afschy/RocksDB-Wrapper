#!/bin/bash
#
# Runs one tracing experiment from the knobs below and leaves behind exactly
# one file: the trace, named after the options that produced it. The database
# and the logs are deleted on the way out.
#
# Both runners can trace. They spell the flags differently: db_bench uses
# --key_lookup_trace_*, working_version uses --trace_*.

set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MB=$((1024 * 1024))
GB=$((1024 * MB))

##############################################################################
# KNOBS
##############################################################################

# Which binary drives the workload: dbbench | tectonic
runner=dbbench

# --- LSM shape ---------------------------------------------------------------
file_size_mb=32
size_ratio=4
files_in_l0=6
level_count=7
file_to_memtable_size_ratio=1
compaction_pri=4
clear_system_cache=0    # 1 makes working_version shell out to sudo

# --- Block cache -------------------------------------------------------------
cache_size_mb=0         # 0 disables the block cache entirely
cache_index_filter=1    # index/filter blocks in the cache, subject to eviction
pin_l0=0                # pin L0 index/filter blocks (needs the cache on)
pin_top_level=0         # pin the top level of a partitioned index
partition_filters=0     # partitioned index + filters; forces a two-level index
fill_cache=1            # queries insert what they read (working_version only)

# --- On-disk block compression -----------------------------------------------
# none | snappy | zlib | bzip2 | lz4 | lz4hc | xpress | zstd. Only what the
# build linked is usable; this one has none and zstd. Note that db_bench's own
# default is snappy, so leaving this at none is a deliberate override.
compression=none

# --- Filters -----------------------------------------------------------------
bloom_filter=0          # 0 drops the filter policy entirely
bits_per_key=10         # only used when bloom_filter=1

# --- Workload ----------------------------------------------------------------
key_size_b=1024
value_size_b=3072
# working_version reads its operations from workload.txt, so everything below
# applies to db_bench only.
entry_count=7000000
read_count=7000000
benchmarks=fillrandom,readrandom
seed=42
threads=1

# --- Key lookup tracing ------------------------------------------------------
trace_enabled=1         # 0 disables tracing entirely
trace_sampling=1        # record 1 out of every N lookups
trace_blocks=1          # record data blocks, not just the files searched
trace_iters=0           # record blocks read by table iterators
trace_caller_mask=65535 # iterator callers to keep; 64511 drops compaction
trace_block_id_mode=0   # 0 ordinal, 1 offset
trace_compress=1        # stream the trace out as zstd
trace_compression_level=1
trace_max_file_size=$((128 * GB))

# Where the database lives while the run is in flight
db_path=./db

##############################################################################
# DERIVED
##############################################################################

tf() { [[ "$1" -eq 1 ]] && echo true || echo false; }

# Everything the run drops in the working directory except its trace file.
cleanup() {
    rm -rf "${db_path}"
    rm -f workload.log stats.log
}

file_size_b=$((file_size_mb * MB))
entry_size=$((key_size_b + value_size_b))
workload_gb=$(( (entry_size * entry_count + GB / 2) / GB ))

# db_bench's reads always populate the cache, so a run asking otherwise would
# produce a trace whose name claims a setting the run did not have.
if [[ "${runner}" == "dbbench" && "${fill_cache}" -eq 0 ]]; then
    echo "db_bench has no --fill_cache" >&2
    exit 1
fi

# There is nowhere to put index and filter blocks when the cache is off, and
# RocksDB rejects the combination rather than ignoring it.
[[ "${cache_size_mb}" -eq 0 ]] && cache_index_filter=0

# Partitioned filters need a two-level index or RocksDB silently drops them,
# and there is no other reason to change the index type here.
index_type=1
[[ "${partition_filters}" -eq 1 ]] && index_type=3

# working_version numbers the codecs; db_bench names them.
case "${compression}" in
    none)   compression_id=1 ;;
    snappy) compression_id=2 ;;
    zlib)   compression_id=3 ;;
    bzip2)  compression_id=4 ;;
    lz4)    compression_id=5 ;;
    lz4hc)  compression_id=6 ;;
    xpress) compression_id=7 ;;
    zstd)   compression_id=8 ;;
    *)      echo "unknown compression '${compression}'" >&2; exit 1 ;;
esac

# db_bench drops the filter policy when --bloom_bits is 0.
bloom_bits=${bits_per_key}
[[ "${bloom_filter}" -eq 0 ]] && bloom_bits=0

if [[ "${trace_enabled}" -eq 1 ]]; then
    trace_file=key_lookup.trace
    [[ "${trace_compress}" -eq 1 ]] && trace_file=key_lookup.trace.zst

    block_id_mode=ordinal
    [[ "${trace_block_id_mode}" -eq 1 ]] && block_id_mode=offset

    dbb_trace="--key_lookup_trace_file=${trace_file} \
        --key_lookup_trace_sampling_frequency=${trace_sampling} \
        --key_lookup_trace_max_file_size=${trace_max_file_size} \
        --key_lookup_trace_record_blocks=$(tf ${trace_blocks}) \
        --key_lookup_trace_block_id_mode=${block_id_mode} \
        --key_lookup_trace_record_iterator_accesses=$(tf ${trace_iters}) \
        --key_lookup_trace_iterator_caller_mask=${trace_caller_mask} \
        --key_lookup_trace_compress=$(tf ${trace_compress}) \
        --key_lookup_trace_compression_level=${trace_compression_level}"

    wld_trace="--trace_file=${trace_file} \
        --trace_sampling=${trace_sampling} \
        --trace_max_file_size=${trace_max_file_size} \
        --trace_blocks=${trace_blocks} \
        --trace_block_id_mode=${trace_block_id_mode} \
        --trace_iters=${trace_iters} \
        --trace_caller_mask=${trace_caller_mask} \
        --trace_compress=${trace_compress} \
        --trace_compression_level=${trace_compression_level}"
else
    trace_file=""
    dbb_trace=""
    wld_trace=""
fi

##############################################################################
# COMMAND
##############################################################################

if [[ "${runner}" == "dbbench" ]]; then
    command="./bin/db_bench --benchmarks=${benchmarks},stats --db=${db_path} \
        --num=${entry_count} --reads=${read_count} \
        --key_size=${key_size_b} --value_size=${value_size_b} \
        --write_buffer_size=${file_size_b} --target_file_size_base=${file_size_b} \
        --max_bytes_for_level_base=$((file_size_b * files_in_l0)) \
        --max_bytes_for_level_multiplier=${size_ratio} --num_levels=${level_count} \
        --level0_file_num_compaction_trigger=${size_ratio} \
        --level0_slowdown_writes_trigger=$((size_ratio - 1)) \
        --level0_stop_writes_trigger=${size_ratio} \
        --compaction_pri=${compaction_pri} --compression_type=${compression} \
        --max_background_compactions=1 --max_background_flushes=1 \
        --threads=${threads} --seed=${seed} --histogram=1 --perf_level=5 \
        --cache_size=$((cache_size_mb * MB)) \
        --cache_index_and_filter_blocks=$(tf ${cache_index_filter}) \
        --pin_l0_filter_and_index_blocks_in_cache=$(tf ${pin_l0}) \
        --pin_top_level_index_and_filter=$(tf ${pin_top_level}) \
        --partition_index_and_filters=$(tf ${partition_filters}) \
        --bloom_bits=${bloom_bits} ${dbb_trace}"
else
    # Only the flags below are applied by parse_arguments.h. --file_size is
    # declared there but never read, and --num_levels / --files_in_l0 do not
    # exist on this branch at all.
    command="./bin/working_version --destroy=1 --size_ratio=${size_ratio} \
        --buffer_size_in_pages=$((file_size_mb * 256)) --entry_size=${entry_size} \
        --entries_per_page=$((4096 / entry_size)) \
        --file_to_memtable_size_ratio=${file_to_memtable_size_ratio} \
        --compaction_pri=${compaction_pri} --cc=${clear_system_cache} \
        --progress=1 --totaltime=1 --peroptime=1 \
        --bb=${cache_size_mb} --cache_index_and_filter=${cache_index_filter} \
        --pin_l0=${pin_l0} --pin_top_level=${pin_top_level} \
        --partition_filters=${partition_filters} --index_type=${index_type} \
        --fill_cache=${fill_cache} --bloom_filter=${bloom_filter} \
        --bits_per_key=${bits_per_key} --compression=${compression_id} \
        ${wld_trace}"
fi

##############################################################################
# TRACE FILE NAME
##############################################################################

# The name carries what used to be the results directory hierarchy, so a trace
# file stays identifiable once it has been moved somewhere else. Groups are
# separated by a double underscore, and a knob shows up only when it is off its
# default, so the common case stays readable.
lsm="fs${file_size_mb}_r${size_ratio}_fl0-${files_in_l0}"
lsm="${lsm}_lc${level_count}_ws${workload_gb}_cp${compaction_pri}"

cache=cache-off
if [[ "${cache_size_mb}" -ne 0 ]]; then
    cache="cache-${cache_size_mb}mb_cif-${cache_index_filter}"
    [[ "${pin_l0}" -eq 1 ]] && cache="${cache}_pinl0"
    [[ "${pin_top_level}" -eq 1 ]] && cache="${cache}_pintl"
    [[ "${partition_filters}" -eq 1 ]] && cache="${cache}_part"
    [[ "${fill_cache}" -eq 0 ]] && cache="${cache}_nofill"
fi

filter=bloom-off
[[ "${bloom_filter}" -eq 1 ]] && filter="bpk${bits_per_key}"
[[ "${compression}" != "none" ]] && filter="${filter}_${compression}"

# Only the entry size is real under tectonic; the rest of the workload comes
# from workload.txt, so naming it after these knobs would be a fiction.
wl="ks${key_size_b}_vs${value_size_b}"
if [[ "${runner}" == "dbbench" ]]; then
    wl="${wl}_ec${entry_count}_reads-${read_count}_seed-${seed}"
fi

trace=trace
[[ "${trace_iters}" -eq 1 ]] && trace="${trace}_iters"
[[ "${trace_caller_mask}" -ne 65535 ]] && trace="${trace}_mask${trace_caller_mask}"
[[ "${trace_sampling}" -ne 1 ]] && trace="${trace}_s${trace_sampling}"
[[ "${trace_blocks}" -eq 0 ]] && trace="${trace}_noblocks"
[[ "${trace_block_id_mode}" -eq 1 ]] && trace="${trace}_offset"

# key_lookup.trace or key_lookup.trace.zst, minus the stem
output="${runner}__${lsm}__${cache}__${filter}__${wl}__${trace}${trace_file#key_lookup}"

##############################################################################
# RUN
##############################################################################

echo "${command}"

# A leftover trace from an earlier run would otherwise be renamed as though
# this run had produced it.
[[ -n "${trace_file}" ]] && rm -f "${trace_file}"
cleanup

status=0
eval "${command}" || status=$?
if [[ ${status} -ne 0 ]]; then
    echo "run failed with exit ${status}" >&2
elif [[ -z "${trace_file}" ]]; then
    echo "no trace requested"
elif [[ -e "${trace_file}" ]]; then
    mv "${trace_file}" "${output}"
    echo "trace -> ${output}"
else
    echo "expected ${trace_file}, found nothing" >&2
    status=1
fi

cleanup
exit ${status}
