# RocksDB-Wrapper

This repository provides a **wrapper module for RocksDB**, designed to facilitate database operations, workload generation, and performance testing. It leverages [RocksDB-SSD](https://github.com/SSD-Brandeis/RocksDB-SSD) for storage and [Tectonic](https://github.com/SSD-Brandeis/Tectonic) for workload generation.

## Prerequisites

Ensure the following are installed:

* Git
* CMake
* A C++ compiler (GCC or Clang)

---

## Fork and Add Submodules

The repository **does not include submodules by default**. You need to add them manually after forking:

```bash
# Clone your fork
git clone <your-fork-url>
cd RocksDB-Wrapper

# Add submodules
git submodule add https://github.com/SSD-Brandeis/RocksDB-SSD.git lib/rocksdb
git submodule add https://github.com/SSD-Brandeis/Tectonic.git lib/tectonic

# Initialize and fetch
git submodule update --init --recursive
```

> Note: The `KV-WorkloadGenerator` submodule is **deprecated**. See [tectonic README.md](https://github.com/SSD-Brandeis/Tectonic.git) to generate the workload

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

This builds the wrapper and the submodules.

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
        --compaction_pri=[compaction_pri] [Compaction priority: 1 for
                                          kMinOverlappingRatio, 2 for
                                          kByCompensatedSize, 3 for
                                          kOldestLargestSeqFirst, 4 for
                                          kOldestSmallestSeqFirst; def: 1]
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
        --bb=[bb]                         Block cache size in MB [def: 8 MB]
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
