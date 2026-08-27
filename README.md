# RocksDB-Wrapper

This repository provides a **wrapper module for RocksDB**, designed to facilitate database operations, workload generation, and performance testing. It leverages [RocksDB-SSD](https://github.com/SSD-Brandeis/RocksDB-SSD) for storage and [Tectonic](https://github.com/SSD-Brandeis/Tectonic) for workload generation.

## Prerequisites

Ensure the following are installed:

* Git
* CMake
* A C++ compiler (GCC or Clang)

---

## Clone and Submodules

RocksDB is included as a submodule at `lib/rocksdb`, pinned to the `memory-project`
branch of [rocksdb_modified](https://github.com/afschy/rocksdb_modified).

```bash
git clone <your-fork-url>
cd RocksDB-Wrapper

# Fetch submodules and check out their configured branches
./scripts/submodules.sh
```

Use `./scripts/submodules.sh` rather than `git submodule update --init`: plain
`git submodule update` always leaves a submodule on a **detached HEAD**, even
when `.gitmodules` names a branch. The script does the update and then checks
out the branch recorded in `.gitmodules` (`memory-project` for `lib/rocksdb`),
with upstream tracking set. `setup.sh` and `scripts/rebuild.sh` call it for you.

Once the submodule is on its branch it stays there: `.gitmodules` sets
`update = merge`, so later `git submodule update` runs fast-forward the branch
instead of detaching it again.

> Note: `Tectonic` is not currently wired in as a submodule. The
> `KV-WorkloadGenerator` submodule is **deprecated**. See
> [tectonic README.md](https://github.com/SSD-Brandeis/Tectonic.git) to generate the workload

---

## Build
Use the provided scripts:

```bash
# Initial setup
./setup.sh

# Rebuild the project after changes
./scripts/rebuild.sh
```

Or you can also use the standard CMake commands:

```bash
mkdir build
cd build
cmake ..
cmake --build . --parallel $(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
```

This builds the wrapper and the submodules, producing `bin/working_version`
and `bin/db_bench`.

zstd is on by default because `--trace_compress=1` needs it, and RocksDB's own
default is off. It requires the libzstd headers, which `setup.sh` installs
(`libzstd-dev` on Debian/Ubuntu, `zstd` on macOS). If they are missing,
`find_package(zstd REQUIRED)` fails at configure time — build it without by
passing `-DWITH_ZSTD=OFF`, and traces will then have to be uncompressed.

One flag is worth knowing about:

```bash
cmake -DFAIL_ON_WARNINGS=OFF ..
```

`-DFAIL_ON_WARNINGS=OFF` is needed on GCC 16, which reports a false positive
`-Wmaybe-uninitialized` in RocksDB's `db/blob/blob_file_reader.cc` that
`-Werror` then turns into a build failure.

`db_bench` is built by default; turn it off with `-DWITH_DB_BENCH=OFF`.

---

## Running Experiments

```

    RocksDB_parser.

  OPTIONS:

      This group is all exclusive:
        -d[d], --destroy=[d]              Destroy and recreate the database
                                          [def: 1]
        --cc=[cc]                         Clear system cache [def: 1]
        -T[T], --size_ratio=[T]           The size ratio of the LSM-tree [def:
                                          10]
        -P[P], --buffer_size_in_pages=[P] Number of pages in memory buffer [def:
                                          512]
        -B[B], --entries_per_page=[B]     Number of entries per page [def: 4]
        -E[E], --entry_size=[E]           Size of one entry (bytes) [def: 1024
                                          B]
        -M[M], --memory_size=[M]           Memory buffer size (bytes) [def: 16
                                          MB]
        -f[file_to_memtable_size_ratio],
        --file_to_memtable_size_ratio=[file_to_memtable_size_ratio]
                                          Ratio between files and memtable [def:
                                          1]
        -F[file_size],
        --file_size=[file_size]           Size of one SST file [def: 256 KB]
        -c[compaction_pri],
        --compaction_pri=[compaction_pri] [Compaction priority: 0 for
                                          kByCompensatedSize, 1 for
                                          kOldestLargestSeqFirst, 2 for
                                          kOldestSmallestSeqFirst, 3 for
                                          kMinOverlappingRatio, 4 for
                                          kRoundRobin; def: 3]
        -C[compaction_style],
        --compaction_style=[compaction_style]
                                          [Compaction priority: 1 for
                                          kCompactionStyleLevel, 2 for
                                          kCompactionStyleUniversal, 3 for
                                          kCompactionStyleFIFO, 4 for
                                          kCompactionStyleNone; def: 1]
        -b[bits_per_key],
        --bits_per_key=[bits_per_key]     The number of bits per key assigned to
                                          Bloom filter [def: 10]
        --bb=[bb]                         Block cache size in MB; 0 disables the
                                          block cache entirely [def: 0]
        --cache_index_and_filter=[cache_index_and_filter]
                                          Put index and filter blocks in the
                                          block cache instead of holding them
                                          outside it for the table reader's
                                          lifetime. Ignored when --bb=0 [def: 1]
        --pin_l0=[pin_l0]                 Pin the index and filter blocks of L0
                                          files in the block cache. Requires
                                          --cache_index_and_filter=1 [def: 0]
        --pin_top_level=[pin_top_level]   Pin the top-level index of partitioned
                                          index/filter blocks in the block
                                          cache. Only meaningful with
                                          --partition_filters=1 or
                                          --index_type=3 [def: 0]
        --partition_filters=[partition_filters]
                                          Use partitioned filters. Requires
                                          --index_type=3 [def: 0]
        --index_type=[index_type]         [Index type: 1 for kBinarySearch, 2
                                          for kHashSearch, 3 for
                                          kTwoLevelIndexSearch, 4 for
                                          kBinarySearchWithFirstKey; def: 1]
        --fill_cache=[fill_cache]         Insert blocks read by queries into the
                                          block cache. 0 leaves the cache
                                          contents untouched by reads [def: 0]
        --compression=[compression]       [Block compression: 1 none, 2 snappy,
                                          3 zlib, 4 bzip2, 5 lz4, 6 lz4hc, 7
                                          xpress, 8 zstd; def: 1]
        --bloom_filter=[bloom_filter]     Build bloom filters. 0 drops the
                                          filter policy, so every lookup that
                                          reaches a file reads its index and
                                          data blocks [def: 1]
        --perf=[enable_perf_iostat]       Enable RocksDB's internal Perf and
                                          IOstat [def: 0]
        --iostat=[enable_iostat]          Enable RocksDB's internal IOstat [def:
                                          0]
        --stat=[enable_rocksdb_stats]     Enable RocksDB's internal RocksDB
                                          stats [def: 0]
        --progress=[show_progress_bar]    Shows progress bar [def: 0]
        -V[verbosity],
        --verbosity=[verbosity]           The verbosity level of execution
                                          [0,1,2; def: 0]
        --peroptime=[peroptime]           Enable timing for every individual
                                          operation [def: 0]
        --totaltime=[totaltime]           Enable timing for the total workload
                                          duration [def: 0]
        --lowpri=[low_pri]                Set the priority of write requests (0
                                          means compactions aren't prioritized)
                                          [def: 1]
        --trace_file=[trace_file]         Key lookup trace output path. Empty
                                          disables tracing [def: ""]
        --trace_sampling=[trace_sampling] Capture one in every N lookups; 1
                                          captures all. Breaks per-block access
                                          histories, so leave at 1 for cache
                                          simulation [def: 1]
        --trace_max_file_size=[trace_max_file_size]
                                          Stop tracing once the trace file
                                          exceeds this many bytes [def: 64 GB]
        --trace_blocks=[trace_blocks]     Record data blocks, not just the file
                                          sequence [def: 1]
        --trace_block_id_mode=[trace_block_id_mode]
                                          [Block identifier: 0 for ordinal, 1
                                          for offset; def: 0]
        --trace_compress=[trace_compress] [Trace compression: 0 for none, 1 for
                                          zstd; def: 0]
        --trace_compression_level=[trace_compression_level]
                                          zstd level, used only when
                                          --trace_compress=1 [def: 1]
        --trace_iters=[trace_iters]       Record blocks read by table iterators,
                                          which covers user iterators and
                                          compaction [def: 1]
        --trace_caller_mask=[trace_caller_mask]
                                          Record an iterator access only if bit
                                          (1 << TableReaderCaller) is set.
                                          Compaction is bit 10, so 64511
                                          excludes it [def: 65535]

Failed to parse arguments. Exiting.
```
---

### Example

```bash
./bin/working_version --file_size 512 --size_ratio 20 --peroptime 1
```

This example runs the experiment with:

* SST file size = 512 KB
* Size ratio = 20
* Per-operation timing enabled

---

## Block Cache and Filters

The block cache is off by default (`--bb=0`); any non-zero size gives an LRU
cache of that many megabytes.

```bash
# 64 MB cache, index and filter blocks competing with data blocks in it,
# L0's index and filter blocks pinned so they are never evicted
./bin/working_version --bb=64 --cache_index_and_filter=1 --pin_l0=1
```

* `--cache_index_and_filter=0` keeps index and filter blocks out of the cache;
  they are then held by the table reader for its lifetime and never evicted,
  which is unbounded memory but constant lookup cost. Forced to 0 when `--bb=0`,
  since there is nowhere to put them.
* `--pin_l0=1` pins the index and filter blocks of L0 files. They are still
  charged against the cache but never evicted while the table reader lives. It
  needs a cache to pin into, so it is rejected with `--bb=0`.
* `--pin_top_level=1` pins the top level of a partitioned index or filter. It
  only does something when the index is partitioned, so pair it with
  `--partition_filters=1 --index_type=3`. RocksDB silently drops
  `partition_filters` when the index is not two-level, so the wrapper rejects
  that combination up front rather than letting a run quietly not test what it
  claims to.
* `--fill_cache=0` lets queries read from the cache without inserting into it,
  which holds the cache contents fixed for the duration of a run.
* `--bloom_filter=0` drops the filter policy entirely, so every lookup that
  reaches a file must read its index and data blocks. `--bits_per_key` is kept
  separate so a sweep can switch filters off and back on without losing the
  bits_per_key it was using.

None of this changes what the trace records: a block read is recorded whether it
was served from the cache or from disk. Two runs that differ only in cache
configuration produce near-identical traces, which is the point — the trace
describes the access stream, and a cache is simulated on top of it afterwards.
Filter settings *do* change the trace, because a filter that rejects a key stops
the lookup before any data block is read.

---

## Block Compression

SST blocks are stored uncompressed by default (`--compression=1`). Only codecs
the build actually linked are usable — this one has `none` and `zstd`, per
`WITH_ZSTD=ON` and the other `WITH_*` options being off — and working_version
checks the request against `GetSupportedCompressions()` up front rather than
letting `DB::Open` fail later.

Worth knowing when comparing against other people's numbers: **db_bench's own
default is `snappy`**, not none. `experiment.sh` passes `--compression_type`
explicitly so both binaries agree, but a bare `./bin/db_bench` invocation
compresses.

Compression changes the trace, since a block holds more keys when compressed
and a lookup therefore touches fewer of them. It does not change the block
*identity* scheme: ordinal ids still count data blocks, and offset ids are
still on-disk byte offsets, which is to say post-compression offsets.

---

## Key Lookup Tracing

`working_version` can record every SST file searched and every data block read,
independently of block cache state. Tracing is off until `--trace_file` is set:

```bash
./bin/working_version --trace_file=key_lookup.trace.zst --trace_compress=1
```

The trace covers the whole run, load phase included, so compaction's block
reads appear alongside the queries. It is stopped and flushed before the DB is
closed. If the trace cannot be started the run aborts rather than continuing
untraced.

Notes on the options:

* `--trace_compress=1` writes a standard `.zst` file that `zstd -d` and
  Python's `zstandard` module read directly. Level 1 is the default and gets
  most of the achievable ratio for a fraction of the CPU.
* `--trace_caller_mask` is the main lever on trace size. Compaction usually
  outweighs user iterators by one to two orders of magnitude, and it is
  `TableReaderCaller` 10, so `--trace_caller_mask=64511` drops it.
* `--trace_sampling` drops whole lookups uniformly. That breaks the per-block
  access histories a cache simulator needs, so leave it at 1 for simulation
  runs and use the caller mask instead.
* `--trace_block_id_mode=0` (ordinal) identifies a block by its index among the
  file's data blocks, which stays meaningful after the SST is gone but costs an
  index walk on first access to each file. Mode 1 (offset) has no setup cost but
  needs the SST file to still exist to be interpreted.

The trace format is documented in `lib/rocksdb/claude_md/key_lookup_tracer.md`.

---

## db_bench

`db_bench` is built into `bin/` alongside `working_version`, and exposes its own
subset of the tracer through `--key_lookup_trace_*` flags:

```bash
./bin/db_bench --benchmarks=fillrandom,readrandom --db=./db \
    --key_lookup_trace_file=key_lookup.trace.zst --key_lookup_trace_compress=true
```

Turn it off with `cmake -DWITH_DB_BENCH=OFF ..` if you do not need it; it is on
by default.

Every tracer option is reachable from db_bench. The names differ from
`working_version`'s, and two of them take a different form:

| working_version | db_bench |
| --- | --- |
| `--trace_file` | `--key_lookup_trace_file` |
| `--trace_sampling` | `--key_lookup_trace_sampling_frequency` |
| `--trace_max_file_size` | `--key_lookup_trace_max_file_size` |
| `--trace_blocks=0\|1` | `--key_lookup_trace_record_blocks=false\|true` |
| `--trace_block_id_mode=0\|1` | `--key_lookup_trace_block_id_mode=ordinal\|offset` |
| `--trace_compress=0\|1` | `--key_lookup_trace_compress=false\|true` |
| `--trace_compression_level` | `--key_lookup_trace_compression_level` |
| `--trace_iters=0\|1` | `--key_lookup_trace_record_iterator_accesses=false\|true` |
| `--trace_caller_mask` | `--key_lookup_trace_iterator_caller_mask` |

db_bench additionally has `--key_lookup_trace_iterator_skip_compaction`, a
shorthand for clearing `TableReaderCaller::kCompaction` (bit 10) from the
caller mask. It composes with the mask rather than replacing it: the mask
selects, then `skip_compaction` subtracts, so
`--key_lookup_trace_iterator_caller_mask=64511` and
`--key_lookup_trace_iterator_skip_compaction=true` do the same thing, and
setting both is harmless.

---

## experiment.sh

`experiment.sh` runs one experiment from the knobs at the top of the file and
leaves behind exactly one artifact: the trace, renamed to carry the options that
produced it. The database and the logs are deleted on the way out. Set `runner`
to `dbbench` or `tectonic` to choose the binary; both can trace.

```
dbbench__fs32_r4_fl0-6_lc7_ws3_cp4__cache-8mb_cif-1_pinl0__bpk10__ks12_vs500_ec6500000_reads-1000000_seed-42__trace_iters_mask64511.trace.zst
```

Groups are separated by a double underscore: runner, LSM shape, cache, filters
and compression, workload, tracing. A knob appears only when it is off its default, so the common
case stays short. Under `runner=tectonic` the workload group carries only the
entry size, since everything else about the workload comes from `workload.txt`.

For a sweep, drive the script from a loop that edits the knobs, or copy it per
configuration — it is a flat list of assignments followed by one command, with
nothing to unpick.

A few knobs are coupled and are resolved for you rather than passed through into
a confusing failure: `cache_index_filter` is forced off when the cache is off
(RocksDB rejects that combination), `partition_filters=1` selects the two-level
index it requires, and `fill_cache=0` is refused under `runner=dbbench`, whose
reads always populate the cache.
