#include <algorithm>
#include <iostream>
#include <vector>

#include "rocksdb/convenience.h"

#include "args.hxx"
#include "db_env.h"

int parse_arguments(int argc, char *argv[], std::unique_ptr<DBEnv> &env) {
  args::ArgumentParser parser("RocksDB_parser.", "");
  args::Group group1(parser, "This group is all exclusive:",
                     args::Group::Validators::DontCare);

  args::ValueFlag<int> destroy_database_cmd(
      group1, "d", "Destroy and recreate the database [def: 1]",
      {'d', "destroy"});
  args::ValueFlag<int> clear_system_cache_cmd(
      group1, "cc", "Clear system cache [def: 0]", {"cc"});

  args::ValueFlag<int> size_ratio_cmd(
      group1, "T", "The size ratio of the LSM-tree [def: 10]",
      {'T', "size_ratio"});
  args::ValueFlag<int> buffer_size_in_pages_cmd(
      group1, "P", "Number of pages in memory buffer [def: 16384]",
      {'P', "buffer_size_in_pages"});
  args::ValueFlag<int> entries_per_page_cmd(
      group1, "B", "Number of entries per page [def: 64]",
      {'B', "entries_per_page"});
  args::ValueFlag<int> entry_size_cmd(group1, "E",
                                      "Size of one entry (bytes) [def: 64 B]",
                                      {'E', "entry_size"});
  args::ValueFlag<long> buffer_size_cmd(
      group1, "M", " Memory buffer size (bytes); 0 derives it from P*B*E [def: 0]",
      {'M', "memory_size"});
  args::ValueFlag<int> file_to_memtable_size_ratio_cmd(
      group1, "file_to_memtable_size_ratio",
      "Ratio between files and memtable [def: 1]",
      {'f', "file_to_memtable_size_ratio"});
  args::ValueFlag<long> file_size_cmd(group1, "file_size",
                                      "Size of one SST file [def: 256 KB]",
                                      {'F', "file_size"});
  args::ValueFlag<int> num_levels_cmd(
      group1, "num_levels", "Number of levels in the LSM-tree [def: 7]",
      {'L', "num_levels"});
  args::ValueFlag<unsigned long long> max_bytes_for_level_base_cmd(
      group1, "max_bytes_for_level_base",
      "Maximum total size of level 1 in bytes; 0 derives it from the memtable "
      "size [def: 256 MB]",
      {"max_bytes_for_level_base"});
  args::ValueFlag<int> level0_file_num_compaction_trigger_cmd(
      group1, "level0_file_num_compaction_trigger",
      "Number of L0 files that triggers an L0 compaction [def: 4]",
      {"level0_file_num_compaction_trigger"});
  args::ValueFlag<int> level0_slowdown_writes_trigger_cmd(
      group1, "level0_slowdown_writes_trigger",
      "Number of L0 files at which writes start being throttled [def: 20]",
      {"level0_slowdown_writes_trigger"});
  args::ValueFlag<int> level0_stop_writes_trigger_cmd(
      group1, "level0_stop_writes_trigger",
      "Number of L0 files at which writes stop entirely [def: 36]",
      {"level0_stop_writes_trigger"});
  args::ValueFlag<int> max_background_jobs_cmd(
      group1, "max_background_jobs",
      "Concurrent background jobs. RocksDB splits this into "
      "max(1, jobs / 4) flushes and max(1, jobs - flushes) compactions, so 2 "
      "is one of each [def: 2]",
      {"max_background_jobs"});
  args::ValueFlag<int> max_background_compactions_cmd(
      group1, "max_background_compactions",
      "Concurrent background compactions; -1 defers to --max_background_jobs "
      "[def: -1]",
      {"max_background_compactions"});
  args::ValueFlag<int> max_background_flushes_cmd(
      group1, "max_background_flushes",
      "Concurrent background flushes; -1 defers to --max_background_jobs "
      "[def: -1]",
      {"max_background_flushes"});
  args::ValueFlag<int> compaction_pri_cmd(
      group1, "compaction_pri",
      "[Compaction priority: 0 for kByCompensatedSize, 1 for "
      "kOldestLargestSeqFirst, 2 for kOldestSmallestSeqFirst, 3 for "
      "kMinOverlappingRatio, 4 for kRoundRobin; def: 3]",
      {'c', "compaction_pri"});
  args::ValueFlag<int> compaction_style_cmd(
      group1, "compaction_style",
      "[Compaction priority: 1 for kCompactionStyleLevel, 2 for "
      "kCompactionStyleUniversal, 3 for kCompactionStyleFIFO, 4 for "
      "kCompactionStyleNone; def: 1]",
      {'C', "compaction_style"});
  args::ValueFlag<int> bits_per_key_cmd(
      group1, "bits_per_key",
      "The number of bits per key assigned to Bloom filter, used only with "
      "--bloom_filter=1 [def: 10]",
      {'b', "bits_per_key"});
  args::ValueFlag<int> block_cache_cmd(
      group1, "bb", "Block cache size in MB; 0 disables the block cache "
      "entirely [def: 32]",
      {"bb"});
  args::ValueFlag<int> cache_type_cmd(
      group1, "cache_type",
      "[Block cache: 1 for LRUCache, 2 for HyperClockCache; def: 2]",
      {"cache_type"});
  args::ValueFlag<int> cache_index_and_filter_cmd(
      group1, "cache_index_and_filter",
      "Put index and filter blocks in the block cache instead of holding them "
      "outside it for the table reader's lifetime. Ignored when --bb=0 "
      "[def: 0]",
      {"cache_index_and_filter"});
  args::ValueFlag<int> pin_l0_cmd(
      group1, "pin_l0",
      "Pin the index and filter blocks of L0 files in the block cache. "
      "Requires --cache_index_and_filter=1 [def: 0]",
      {"pin_l0"});
  args::ValueFlag<int> pin_top_level_cmd(
      group1, "pin_top_level",
      "Pin the top-level index of partitioned index/filter blocks in the "
      "block cache. Only meaningful with --partition_filters=1 or "
      "--index_type=3 [def: 0]",
      {"pin_top_level"});
  args::ValueFlag<int> partition_filters_cmd(
      group1, "partition_filters",
      "Use partitioned filters. Requires --index_type=3 [def: 0]",
      {"partition_filters"});
  args::ValueFlag<int> index_type_cmd(
      group1, "index_type",
      "[Index type: 1 for kBinarySearch, 2 for kHashSearch, 3 for "
      "kTwoLevelIndexSearch, 4 for kBinarySearchWithFirstKey; def: 1]",
      {"index_type"});
  args::ValueFlag<int> fill_cache_cmd(
      group1, "fill_cache",
      "Insert blocks read by queries into the block cache. 0 leaves the cache "
      "contents untouched by reads [def: 1]",
      {"fill_cache"});
  args::ValueFlag<int> compression_cmd(
      group1, "compression",
      "[Block compression: 1 none, 2 snappy, 3 zlib, 4 bzip2, 5 lz4, 6 lz4hc, "
      "7 xpress, 8 zstd; def: 2 (snappy)]",
      {"compression"});
  args::ValueFlag<int> bloom_filter_cmd(
      group1, "bloom_filter",
      "Build bloom filters. 0 drops the filter policy, so every lookup that "
      "reaches a file reads its index and data blocks [def: 0]",
      {"bloom_filter"});
  args::ValueFlag<int> enable_perf_cmd(
      group1, "enable_perf_iostat",
      "Enable RocksDB's internal Perf and IOstat [def: 0]", {"perf"});
  args::ValueFlag<int> enable_iostat_cmd(
      group1, "enable_iostat", "Enable RocksDB's internal IOstat [def: 0]",
      {"iostat"});
  args::ValueFlag<int> enable_rocksdb_stats_cmd(
      group1, "enable_rocksdb_stats",
      "Enable RocksDB's internal RocksDB stats [def: 0]", {"stat"});
  args::ValueFlag<int> show_progress_cmd(
      group1, "show_progress_bar", "Shows progress bar [def: 0]", {"progress"});
  args::ValueFlag<int> verbosity_cmd(
      group1, "verbosity", "The verbosity level of execution [0,1,2; def: 0]",
      {'V', "verbosity"});
  args::ValueFlag<int> enable_per_op_time_cmd(
      group1, "peroptime",
      "Enable timing for every individual operation [def: 0]", {"peroptime"});
  args::ValueFlag<int> enable_total_time_cmd(
      group1, "totaltime",
      "Enable timing for the total workload duration [def: 0]", {"totaltime"});

  args::ValueFlag<int> low_pri_cmd(
      group1, "low_pri",
      "Set the priority of write requests (0 means compactions aren't "
      "prioritized) [def: 0]",
      {"lowpri"});

  args::ValueFlag<std::string> trace_file_cmd(
      group1, "trace_file",
      "Key lookup trace output path. Empty disables tracing [def: \"\"]",
      {"trace_file"});
  args::ValueFlag<unsigned long long> trace_sampling_cmd(
      group1, "trace_sampling",
      "Capture one in every N lookups; 1 captures all. Breaks per-block "
      "access histories, so leave at 1 for cache simulation [def: 1]",
      {"trace_sampling"});
  args::ValueFlag<unsigned long long> trace_max_file_size_cmd(
      group1, "trace_max_file_size",
      "Stop tracing once the trace file exceeds this many bytes [def: 64 GB]",
      {"trace_max_file_size"});
  args::ValueFlag<int> trace_blocks_cmd(
      group1, "trace_blocks",
      "Record data blocks, not just the file sequence [def: 1]",
      {"trace_blocks"});
  args::ValueFlag<int> trace_block_id_mode_cmd(
      group1, "trace_block_id_mode",
      "[Block identifier: 0 for ordinal, 1 for offset; def: 0]",
      {"trace_block_id_mode"});
  args::ValueFlag<int> trace_compress_cmd(
      group1, "trace_compress",
      "[Trace compression: 0 for none, 1 for zstd; def: 0]",
      {"trace_compress"});
  args::ValueFlag<int> trace_compression_level_cmd(
      group1, "trace_compression_level",
      "zstd level, used only when --trace_compress=1 [def: 1]",
      {"trace_compression_level"});
  args::ValueFlag<int> trace_iters_cmd(
      group1, "trace_iters",
      "Record blocks read by table iterators, which covers user iterators and "
      "compaction [def: 1]",
      {"trace_iters"});
  args::ValueFlag<unsigned int> trace_caller_mask_cmd(
      group1, "trace_caller_mask",
      "Record an iterator access only if bit (1 << TableReaderCaller) is set. "
      "Compaction is bit 10, so 64511 excludes it [def: 65535]",
      {"trace_caller_mask"});

  try {
    parser.ParseCLI(argc, argv);
  } catch (args::Help &) {
    std::cout << parser;
    exit(0);
  } catch (args::ParseError &e) {
    std::cerr << e.what() << std::endl;
    std::cerr << parser;
    return 1;
  } catch (args::ValidationError &e) {
    std::cerr << e.what() << std::endl;
    std::cerr << parser;
    return 1;
  }

  env->SetDestroyDatabase(destroy_database_cmd
                              ? args::get(destroy_database_cmd)
                              : env->IsDestroyDatabaseEnabled());
  env->clear_system_cache = clear_system_cache_cmd
                                ? args::get(clear_system_cache_cmd)
                                : env->clear_system_cache;
  // --size_ratio is max_bytes_for_level_multiplier and nothing else. It used
  // to overwrite the three L0 triggers as well, which made their defaults dead
  // and had no counterpart in db_bench, where all four are separate flags.
  env->size_ratio =
      size_ratio_cmd ? args::get(size_ratio_cmd) : env->size_ratio;
  env->num_levels =
      num_levels_cmd ? args::get(num_levels_cmd) : env->num_levels;
  env->max_bytes_for_level_base = max_bytes_for_level_base_cmd
                                      ? args::get(max_bytes_for_level_base_cmd)
                                      : env->max_bytes_for_level_base;
  env->level0_file_num_compaction_trigger =
      level0_file_num_compaction_trigger_cmd
          ? args::get(level0_file_num_compaction_trigger_cmd)
          : env->level0_file_num_compaction_trigger;
  env->level0_slowdown_writes_trigger =
      level0_slowdown_writes_trigger_cmd
          ? args::get(level0_slowdown_writes_trigger_cmd)
          : env->level0_slowdown_writes_trigger;
  env->level0_stop_writes_trigger =
      level0_stop_writes_trigger_cmd
          ? args::get(level0_stop_writes_trigger_cmd)
          : env->level0_stop_writes_trigger;
  env->max_background_jobs = max_background_jobs_cmd
                                 ? args::get(max_background_jobs_cmd)
                                 : env->max_background_jobs;
  env->max_background_compactions =
      max_background_compactions_cmd ? args::get(max_background_compactions_cmd)
                                     : env->max_background_compactions;
  env->max_background_flushes = max_background_flushes_cmd
                                    ? args::get(max_background_flushes_cmd)
                                    : env->max_background_flushes;

  env->buffer_size_in_pages = buffer_size_in_pages_cmd
                                  ? args::get(buffer_size_in_pages_cmd)
                                  : env->buffer_size_in_pages;
  env->entries_per_page = entries_per_page_cmd ? args::get(entries_per_page_cmd)
                                               : env->entries_per_page;
  env->entry_size =
      entry_size_cmd ? args::get(entry_size_cmd) : env->entry_size;
  env->verbosity = verbosity_cmd ? args::get(verbosity_cmd) : env->verbosity;
  env->is_per_op_timer = enable_per_op_time_cmd
                             ? args::get(enable_per_op_time_cmd)
                             : env->is_per_op_timer;
  env->is_total_timer = enable_total_time_cmd ? args::get(enable_total_time_cmd)
                                              : env->is_total_timer;
  env->SetBufferSize(buffer_size_cmd ? args::get(buffer_size_cmd) : 0);
  env->file_to_memtable_size_ratio =
      file_to_memtable_size_ratio_cmd
          ? args::get(file_to_memtable_size_ratio_cmd)
          : env->file_to_memtable_size_ratio;
  env->compaction_pri =
      compaction_pri_cmd ? args::get(compaction_pri_cmd) : env->compaction_pri;
  env->compaction_style = compaction_style_cmd ? args::get(compaction_style_cmd)
                                               : env->compaction_style;
  env->bits_per_key =
      bits_per_key_cmd ? args::get(bits_per_key_cmd) : env->bits_per_key;
  env->block_cache =
      block_cache_cmd ? args::get(block_cache_cmd) : env->block_cache;
  env->cache_type =
      cache_type_cmd ? args::get(cache_type_cmd) : env->cache_type;
  env->cache_index_and_filter_blocks =
      cache_index_and_filter_cmd ? args::get(cache_index_and_filter_cmd)
                                 : env->cache_index_and_filter_blocks;
  env->pin_l0_filter_and_index_blocks_in_cache =
      pin_l0_cmd ? args::get(pin_l0_cmd)
                 : env->pin_l0_filter_and_index_blocks_in_cache;
  env->pin_top_level_index_and_filter =
      pin_top_level_cmd ? args::get(pin_top_level_cmd)
                        : env->pin_top_level_index_and_filter;
  env->partition_filters = partition_filters_cmd
                               ? args::get(partition_filters_cmd)
                               : env->partition_filters;
  env->index_type = index_type_cmd ? args::get(index_type_cmd)
                                   : env->index_type;
  env->fill_cache =
      fill_cache_cmd ? args::get(fill_cache_cmd) : env->fill_cache;
  env->use_bloom_filter = bloom_filter_cmd ? args::get(bloom_filter_cmd)
                                           : env->use_bloom_filter;
  env->compression =
      compression_cmd ? args::get(compression_cmd) : env->compression;
  env->SetPerfStat(enable_perf_cmd ? args::get(enable_perf_cmd)
                                   : env->IsPerfStatEnabled());
  env->SetIOStat(enable_iostat_cmd ? args::get(enable_iostat_cmd)
                                   : env->IsIOStatEnabled());
  env->SetRocksDBStat(enable_rocksdb_stats_cmd
                          ? args::get(enable_rocksdb_stats_cmd)
                          : env->IsRocksDBStatEnabled());
  env->SetShowProgress(show_progress_cmd ? args::get(show_progress_cmd)
                                         : env->IsShowProgressEnabled());
  env->low_pri = low_pri_cmd ? args::get(low_pri_cmd) : env->low_pri;

  env->key_lookup_trace_file = trace_file_cmd ? args::get(trace_file_cmd)
                                              : env->key_lookup_trace_file;
  env->trace_sampling_frequency = trace_sampling_cmd
                                      ? args::get(trace_sampling_cmd)
                                      : env->trace_sampling_frequency;
  env->trace_max_file_size = trace_max_file_size_cmd
                                 ? args::get(trace_max_file_size_cmd)
                                 : env->trace_max_file_size;
  env->trace_record_blocks = trace_blocks_cmd ? args::get(trace_blocks_cmd)
                                              : env->trace_record_blocks;
  env->trace_block_id_mode = trace_block_id_mode_cmd
                                 ? args::get(trace_block_id_mode_cmd)
                                 : env->trace_block_id_mode;
  env->trace_compression =
      trace_compress_cmd ? args::get(trace_compress_cmd) : env->trace_compression;
  env->trace_compression_level = trace_compression_level_cmd
                                     ? args::get(trace_compression_level_cmd)
                                     : env->trace_compression_level;
  env->trace_record_iterator_accesses =
      trace_iters_cmd ? args::get(trace_iters_cmd)
                      : env->trace_record_iterator_accesses;
  env->trace_iterator_caller_mask = trace_caller_mask_cmd
                                        ? args::get(trace_caller_mask_cmd)
                                        : env->trace_iterator_caller_mask;

  // Whether a codec is usable depends on what the build linked, not just on
  // the enum, so check rather than let DB::Open fail obscurely later.
  if (env->compression < 1 || env->compression > 8) {
    std::cerr << "--compression must be 1..8" << std::endl;
    return 1;
  }
  {
    rocksdb::CompressionType requested =
        static_cast<rocksdb::CompressionType>(env->compression - 1);
    const std::vector<rocksdb::CompressionType> &supported =
        rocksdb::GetSupportedCompressions();
    if (std::find(supported.begin(), supported.end(), requested) ==
        supported.end()) {
      if (!compression_cmd) {
        // Nobody asked for this codec; it is just the db_bench default (snappy)
        // on a build that did not link it. db_bench warns and carries on with
        // no compression, so do the same rather than refuse to start.
        std::cerr << "WARNING: default compression (" << env->compression
                  << ") is not compiled into this build; using none"
                  << std::endl;
        env->compression = 1;
      } else {
        std::cerr << "--compression=" << env->compression
                  << " is not compiled into this build. Available:";
        for (rocksdb::CompressionType type : supported) {
          std::cerr << " " << (static_cast<int>(type) + 1);
        }
        std::cerr << std::endl;
        return 1;
      }
    }
  }

  if (env->cache_type != 1 && env->cache_type != 2) {
    std::cerr << "--cache_type must be 1 (LRU) or 2 (HyperClock)" << std::endl;
    return 1;
  }
  if (env->index_type < 1 || env->index_type > 4) {
    std::cerr << "--index_type must be 1, 2, 3 or 4" << std::endl;
    return 1;
  }
  // RocksDB silently clears partition_filters when the index is not
  // partitioned, which would make a sweep entry a no-op without saying so.
  if (env->partition_filters && env->index_type != 3) {
    std::cerr << "--partition_filters=1 requires --index_type=3 "
                 "(kTwoLevelIndexSearch)"
              << std::endl;
    return 1;
  }
  if (env->block_cache == 0 && env->pin_l0_filter_and_index_blocks_in_cache) {
    std::cerr << "--pin_l0=1 has no meaning with --bb=0 (no block cache)"
              << std::endl;
    return 1;
  }

  if (env->IsKeyLookupTraceEnabled()) {
    if (env->trace_sampling_frequency < 1) {
      std::cerr << "--trace_sampling must be at least 1" << std::endl;
      return 1;
    }
    if (env->trace_block_id_mode != 0 && env->trace_block_id_mode != 1) {
      std::cerr << "--trace_block_id_mode must be 0 (ordinal) or 1 (offset)"
                << std::endl;
      return 1;
    }
    if (env->trace_compression != 0 && env->trace_compression != 1) {
      std::cerr << "--trace_compress must be 0 (none) or 1 (zstd)" << std::endl;
      return 1;
    }
    if (env->trace_iterator_caller_mask > 0xFFFF) {
      std::cerr << "--trace_caller_mask must fit in 16 bits" << std::endl;
      return 1;
    }
  }
  return 0;
}
