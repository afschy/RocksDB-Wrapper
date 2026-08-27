#ifndef DB_ENV_H_
#define DB_ENV_H_

#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

#include "buffer.h"

// Every default below is db_bench's default for the same RocksDB option, so
// that `working_version` and `db_bench` launched with no flags at all hand
// RocksDB the same configuration. Where db_bench declares no flag of its own,
// the value here is the Options() / BlockBasedTableOptions() default, which is
// exactly what db_bench leaves in place.
//
// Two consequences worth knowing before changing anything here: a bare run now
// writes a WAL and asks for snappy, because that is what a bare db_bench does.

namespace Default {

// B * E is the block size and P * B * E the memtable size. db_bench has no
// P/B/E model of its own; what it has is block_size (4096) and
// write_buffer_size (64 MB), and these three reproduce both exactly.
const unsigned int ENTRY_SIZE = 64;
const unsigned int ENTRIES_PER_PAGE = 64;
const unsigned int BUFFER_SIZE_IN_PAGES = 16384;

// max_bytes_for_level_multiplier
const double SIZE_RATIO = 10;
const unsigned int FILE_TO_MEMTABLE_SIZE_RATIO = 1;

// The default and the minimum number is 2
const int MAX_WRITE_BUFFER_NUMBER = 2;
// RocksDB's own default, deliberately independent of SIZE_RATIO. db_bench
// keeps the trigger and the multiplier as separate flags, so tying them
// together here would make --size_ratio silently move a second knob.
const int LEVEL0_FILE_NUM_COMPACTION_TRIGGER = 4;

// kMaxMultiTrivialMove, default is 4 for RocksDB
const size_t MAX_MULTI_TRIVIAL_MOVE = 4;

// -1 is unlimited: every table reader stays open, so a file's index and filter
// blocks are read once rather than re-read after a table cache eviction.
const int MAX_OPEN_FILES = -1;
const int MAX_FILE_OPENING_THREADS = 16;

} // namespace Default

enum Verbosity {
  NO_PRINTS = 0,
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3,
  EXTREME = 4,
};

/**
 * RocksDB is an emulator environment that let the user set bunch
 * of options (default or custom) to update the RocksDB knobs
 *
 * For more information, look at options.h, advanced_options.h
 */
class DBEnv {
private:
  DBEnv() = default;
  ~DBEnv() = default;
  DBEnv(const DBEnv &) = default;
  DBEnv &operator=(const DBEnv &) = delete;

  friend struct std::default_delete<DBEnv>;

  static std::unique_ptr<DBEnv> instance_;
  static std::mutex mutex_;

  // buffer size in bytes
  size_t buffer_size_ = 0;         // [M]
  bool rocksdb_stats_ = false;     // [stat]
  bool perf_stats_ = false;        // [perf]
  bool iostat_stats_ = false;      // [iostat]
  bool destroy_database_ = true;   // [d]
  bool show_progress_bar_ = false; // [progress]

public:
  static std::string kDBPath;
  static std::string kSavedDBPath;
  bool is_per_op_timer = false; // [peroptime]
  bool is_total_timer = false;  // [totaltime]

  static std::unique_ptr<DBEnv> GetInstance() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (instance_ == nullptr)
      instance_ = std::unique_ptr<DBEnv>(new DBEnv());
    return std::move(instance_);
  }

  uint64_t GetBlockSize() const { return entries_per_page * entry_size; }

  void SetBufferSize(size_t buffer_size) { buffer_size_ = buffer_size; }
  void SetRocksDBStat(bool value) { rocksdb_stats_ = value; }
  void SetPerfStat(bool value) { perf_stats_ = value; }
  void SetIOStat(bool value) { iostat_stats_ = value; }
  void SetDestroyDatabase(bool value) { destroy_database_ = value; }
  void SetShowProgress(bool value) { show_progress_bar_ = value; }

  size_t GetBufferSize() const {
    // usually buffer_size = P * B * E
    return buffer_size_ != 0
               ? buffer_size_
               : buffer_size_in_pages * entries_per_page * entry_size;
  }
  bool IsRocksDBStatEnabled() const { return rocksdb_stats_; }
  bool IsPerfStatEnabled() const { return perf_stats_; }
  bool IsIOStatEnabled() const { return iostat_stats_; }
  bool IsDestroyDatabaseEnabled() const { return destroy_database_; }
  bool IsShowProgressEnabled() const { return show_progress_bar_; }

  long GetTargetFileSizeBase() const { return GetBufferSize(); }

  // Control maximum total data size for level base (i.e. level 1). Held
  // independent of the memtable size, the way db_bench holds it: pinning L1 to
  // one buffer buys an extra populated level and all the compaction that goes
  // with it. 0 falls back to the old buffer-derived value.
  uint64_t GetMaxBytesForLevelBase() const {
    return max_bytes_for_level_base != 0 ? max_bytes_for_level_base
                                         : GetTargetFileSizeBase();
  }

#pragma region[DBOptions]
  bool create_if_missing = true;
  // db_bench sets this unconditionally. Inert while only the default column
  // family is used, but kept so the option dumps agree.
  bool create_missing_column_families = true;

  // Allow WAL and memtable writes to be pipelined onto separate threads.
  bool enable_pipelined_write = true;

  // 2^n shards in the table cache.
  int table_cache_numshardbits = 4;

  // Bytes per second allowed to the DB once level0_slowdown_writes_trigger or
  // the soft pending compaction limit kicks in.
  uint64_t delayed_write_rate = 8388608;
  // db_bench never drops the page cache, so neither does a bare run here.
  bool clear_system_cache = false;

  // number of open files that can be used by the DB
  int max_open_files = Default::MAX_OPEN_FILES;
  // number of threads used to open the files.
  int max_file_opening_threads = Default::MAX_FILE_OPENING_THREADS;
  // Allows OS to incrementally sync files to disk while they are being
  // written, asynchronously, in the background. 0, turned off
  int bytes_per_sync = 0;

  // If true, then the status of the threads involved in this DB will
  // be tracked and available via GetThreadList() API.
  bool enable_thread_tracking = false;

  // if true, allow multi-writers to update mem tables in parallel.
  bool allow_concurrent_memtable_write = true;

  // the memory size for stats snapshots, default is 1MB
  size_t stats_history_buffer_size = 1024 * 1024;
  // print malloc stats together with rocksdb.stats
  bool dump_malloc_stats = true;
  // by default RocksDB will flush all memtables on DB close
  bool avoid_flush_during_shutdown = false;

  // If set true, will hint the underlying file system that the file
  // access pattern is random, when a sst file is opened.
  bool advise_random_on_open = true;

  // periodicity when obsolete files get deleted. default is 6 hours.
  // db_bench declares a flag for this but documents it as ignored and never
  // applies it, so RocksDB's default is what db_bench actually runs with.
  uint64_t delete_obsolete_files_period_micros = 6ULL * 60 * 60 * 1000000;

  // allow the OS to mmap file for reading sst tables.
  bool allow_mmap_reads = false;
  // allow the OS to mmap file for writing.
  bool allow_mmap_writes = false;

  /**
   * Verbosity of print statements
   * 0 for NO_PRINTS
   * 1 for LOW
   * 2 for MEDIUM
   * 3 for HIGH
   * 4 for EXTREME
   */
  int verbosity = 0;
#pragma endregion

  // entry size including key and value size in bytes
  unsigned int entry_size = Default::ENTRY_SIZE; // [E]
  // number of entries one page/block stores
  unsigned int entries_per_page = Default::ENTRIES_PER_PAGE; // [B]
  // number of pages in one buffer
  unsigned int buffer_size_in_pages = Default::BUFFER_SIZE_IN_PAGES; // [P]

  double size_ratio = Default::SIZE_RATIO; // [T]
  unsigned int file_to_memtable_size_ratio =
      Default::FILE_TO_MEMTABLE_SIZE_RATIO; // [f]

  // The maximum number of write buffers that are built up in memory.
  // The default and the minimum number is 2, so that when 1 write buffer
  // is being flushed to storage, new writes can continue to the other
  // write buffer.
  int max_write_buffer_number = Default::MAX_WRITE_BUFFER_NUMBER;

  // bloom filter bits per key, used only when use_bloom_filter is on
  double bits_per_key = 10; // [b]

  // Build a bloom filter at all. Equivalent to bits_per_key = 0, but kept
  // separate so a sweep can switch filters off and back on without having to
  // remember the bits_per_key it was using.
  // Off by default because db_bench's --bloom_bits defaults to -1, which
  // leaves BlockBasedTableOptions().filter_policy in place, and that is null.
  bool use_bloom_filter = false; // [bloom_filter]

  /**
   * Compaction Priority. These are RocksDB's own CompactionPri values, so
   * they carry the same meaning as db_bench's --compaction_pri.
   * 0 for kByCompensatedSize
   * 1 for kOldestLargestSeqFirst
   * 2 for kOldestSmallestSeqFirst
   * 3 for kMinOverlappingRatio
   * 4 for kRoundRobin
   */
  uint16_t compaction_pri = 3; // [c] lower case

  /**
   * Memtable Factory
   * 1 for skiplist
   * 2 for vector
   * 3 for hash skip list
   * 4 for hash linked list
   */
  uint16_t memtable_factory = 1; // [m]

  // if true, RocksDB will pick target size of each level dynamically
  bool level_compaction_dynamic_level_bytes = false;

  /**
   * Compaction Style
   * 1 for kCompactionStyleLevel
   * 2 for kCompactionStyleUniversal
   * 3 for kCompactionStyleFIFO
   * 4 for kCompactionStyleNone
   * 5 for kCompactionStyleiLevel
   */
  uint64_t compaction_style = 1; // [C] upper case

  // if true, RocksDB disables auto compactions.
  bool disable_auto_compactions = false;

  // number of files to trigger level-0 compaction. A value < 0 means that
  // level-0 compaction will not be triggered by number of files at all.
  // only applicable if compaction_style != kCompactionStyleUniversal
  int level0_file_num_compaction_trigger =
      Default::LEVEL0_FILE_NUM_COMPACTION_TRIGGER;

  // number of levels for this database
  int num_levels = 7;

  // Maximum total size of level 1, in bytes. 0 means "one memtable", i.e. the
  // buffer-derived value GetMaxBytesForLevelBase() falls back to.
  uint64_t max_bytes_for_level_base = 256ULL * 1024 * 1024;

  // by default target_file_size_multiplier is 1, which means
  // by default files in different levels will have similar size.
  int target_file_size_multiplier = 1;

  // maximum number of concurrent background jobs (compactions and flushes).
  // RocksDB splits this as flushes = max(1, jobs / 4) and compactions =
  // max(1, jobs - flushes), so 2 is one of each -- the same split db_bench
  // gets from --max_background_compactions=1 --max_background_flushes=1.
  int max_background_jobs = 2;

  // Explicit per-pool limits. -1 on both leaves the split above in charge;
  // setting either one takes over completely, giving max(1, value) of each.
  int max_background_compactions = -1;
  int max_background_flushes = -1;

  // Write rate is throttled once the estimated pending compaction bytes pass
  // the soft limit, and writes stop at the hard limit. 0 disables each.
  uint64_t soft_pending_compaction_bytes_limit = 64ULL * 1024 * 1024 * 1024;
  uint64_t hard_pending_compaction_bytes_limit = 128ULL * 1024 * 1024 * 1024;

  // FIFO compaction bounds, read only under compaction_style=3. db_bench sets
  // both explicitly, and its values differ from RocksDB's own defaults.
  uint64_t fifo_max_table_files_size = 0;
  bool fifo_allow_compaction = true;

  // RocksDB's "unset" sentinel, which leveled compaction sanitizes to 30 days.
  // 0 turns periodic compaction off.
  uint64_t periodic_compaction_seconds = 0xfffffffffffffffeULL;

  // Memtable arena allocation unit. 0 lets RocksDB pick, which is
  // write_buffer_size / 8 capped at 1 MB -- what db_bench leaves in place.
  size_t arena_block_size = 0;

  // use O_DIRECT for writes in background flush and compactions.
  bool use_direct_io_for_flush_and_compaction = false;
  // enable direct I/O mode for read/write. Files will be opened in "direct I/O"
  // mode which means that data r/w from the disk will not be cached.
  bool use_direct_reads = false;

#pragma region[TableOptions]
  // disable block cache if this is set to true
  bool no_block_cache = false;

  // Block cache size in MB. 0 sets no_block_cache and passes nullptr, which is
  // what db_bench does when --cache_size is not positive.
  int block_cache = 32;

  /**
   * Block Cache Type
   * 1 for LRUCache
   * 2 for HyperClockCache (auto-tuned entry charge)
   *
   * db_bench's --cache_type defaults to "hyper_clock_cache".
   */
  uint16_t cache_type = 2;

  // 2^n shards in the block cache; negative means let RocksDB decide.
  int cache_numshardbits = -1;

  // high priority pool ratio, LRUCache only
  double block_cache_high_priority_ratio = 0.0;

  // wheather to put index/filter blocks in the block cache
  bool cache_index_and_filter_blocks = false;

  // If used, For every data block we load into memory, we will create a bitmap
  // of size ((block_size / `read_amp_bytes_per_bit`) / 8) bytes. This bitmap
  // will be used to figure out the percentage we actually read of the blocks.
  int read_amp_bytes_per_bit = 0;

  /**
   * Data Block Index Type
   * 1 for kDataBlockBinarySearch
   * 2 for kDataBlockBinaryAndHash
   */
  uint16_t data_block_index_type = 1;

  /**
   * Index Type
   * 1 for kBinarySearch
   * 2 for kHashSearch
   * 3 for kTwoLevelIndexSearch
   * 4 for kBinarySearchWithFirstKey
   */
  uint16_t index_type = 1;

  // use partitioned full filters for each SST file. Filter partition blocks
  // using block cache even when cache_index_and_filter_blocks=false.
  bool partition_filters = false;

  // block size for partitioned metadata. Look into table.h
  uint64_t metadata_block_size = 4096;

  // If cache_index_and_filter_blocks is true, pin the index and filter blocks
  // of L0 files in the block cache. They still occupy their charge but are
  // never evicted while the table reader lives, so L0 point lookups stop
  // paying for index/filter misses. No effect when the blocks are not cached
  // in the first place.
  bool pin_l0_filter_and_index_blocks_in_cache = false;

  // If cache_index_and_filter_blocks is true and the below is true, then
  // the top-level index of partitioned filter and index blocks are stored in
  // the cache, but a reference is held in the "table reader" object so the
  // blocks are pinned and only evicted from cache when the table reader is
  // freed. This is not limited to l0 in LSM tree. Only meaningful with
  // partition_filters or a two-level index, since there is no top level to
  // pin otherwise.
  bool pin_top_level_index_and_filter = false;

  /**
   * Index Shortening Mode
   * 1 for kNoShortening
   * 2 for kShortenSeparators
   * 3 for kShortenSeparatorsAndSuccessor
   */
  uint16_t index_shortening = 3;

  // This is used to close a block before it reaches the configured
  // 'block_size'. If the percentage of free space in the current block is less
  // than this specified number and adding a new record to the block will
  // exceed the configured block size, then this block will be closed and the
  // new record will be written to the next block.
  int block_size_deviation = 10;

  // store index block on disk in compressed format
  bool enable_index_compression = true;
#pragma endregion

  /**
   * Compression Type
   * 1 for kNoCompression
   * 2 for kSnappyCompression
   * 3 for kZlibCompression
   * 4 for kBZip2Compression
   * 5 for kLZ4Compression
   * 6 for kLZ4HCCompression
   * 7 for kXpressCompression
   * 8 for kZSTD
   * 9 for kZSTDNotFinalCompression March 01, 2025 [deprecated]
   * 10 for kDisableCompressionOption
   */
  // db_bench's --compression_type defaults to "snappy". A build without snappy
  // linked warns and falls back to no compression, as db_bench does.
  uint16_t compression = 2;

#pragma region[ReadOptions]
  // if true, all data read from underlying storage
  // will be verified against corresponding checksums.
  bool verify_checksums = true;

  // should the "data block"/"index block" read
  // for this iteration be placed in block cache?
  bool fill_cache = true;

  // if true, range tombstones handling will be skipped in key lookup paths
  // look into options.h
  bool ignore_range_deletions = false;

  /**
   * Read Tier
   * 1 for kReadAllTier
   * 2 for kBlockCacheTier
   * 3 for kPersistedTier
   * 4 for kMemtableTier
   */
  uint16_t read_tier = 1;
#pragma endregion

#pragma region[WriteOptions]
  // if true, this write request is of lower priority if compaction is behind
  bool low_pri = false;

  // if true, the write will be flushed from the operating system buffer cache
  // before the write is considered complete. If true, write will be slower.
  bool sync = false;

  // if true, write will not first go to the write ahead log.
  bool disableWAL = false;

  // if true and we need to wait or sleep for the write request, fails
  // immediately with Status::Incomplete()
  bool no_slowdown = false;

  // If true and if user is trying to write to column families that don't exist
  // (they were dropped),  ignore the write (don't return an error). If there
  // are multiple writes in a WriteBatch, other writes will succeed.
  bool ignore_missing_column_families = false;
#pragma endregion

#pragma region[ColumnFamilyOptions]
  /**
   * Comparator
   * 1 for BytewiseComparator
   * 2 for ReverseBytewiseComparator
   */
  uint16_t comparator = 1;

  // An iteration->Next() sequentially skips over keys with the same
  // user-key unless this option is set. This number specifies the number
  // of keys (with the same userkey) that will be sequentially
  // skipped before a reseek is issued.
  //
  // Why 8?
  uint64_t max_sequential_skip_in_iterations = 8;

  // Enables a dynamic Bloom filter in memtable to optimize many queries that
  // must go beyond the memtable. The size in bytes of the filter is
  // write_buffer_size * memtable_prefix_bloom_size_ratio.
  double memtable_prefix_bloom_size_ratio = 0.0;

  // Soft limit on number of level-0 files.
  // We start slowing down writes at this point.
  int level0_slowdown_writes_trigger = 20;

  // maximum number of level-0 files. RocksDB stop writes at this point
  int level0_stop_writes_trigger = 36;

  // After writing every SST file, reopen it and read all the keys.
  // Checks the hash of all of the keys and values written versus the
  // keys in the file and signals a corruption if they do not match
  bool paranoid_file_checks = false;

  // This flag specifies that the implementation should optimize the filters
  // mainly for cases where keys are found rather than also optimize for keys
  // missed. This would be used in cases where the application knows that
  // there are very few misses or the performance in the case of misses is not
  // important.
  bool optimize_filters_for_hits = false;

  // Allows thread-safe inplace updates.
  bool inplace_update_support = false;

  // Number of locks used for inplace update
  // Default: 10000, if inplace_update_support = true, else 0.
  size_t inplace_update_num_locks = 10000;

  // measure IO stats in compactions and flushes, if true
  bool report_bg_io_stats = false;
#pragma endregion

#pragma region[FlushOptions]
  // if true, the flush will wait until the flush is done.
  bool wait = true;

  // If true, the flush would proceed immediately even it means writes will
  // stall for the duration of the flush; if false the operation will wait
  // until it's possible to do flush w/o causing stall or until required flush
  // is performed by someone else (foreground call or background thread).
  bool allow_write_stall = false;
#pragma endregion

#pragma region[KeyLookupTraceOptions]
  // Path of the key lookup trace file. Empty means tracing is disabled; this
  // is the single switch that turns the whole feature on.
  std::string key_lookup_trace_file = ""; // [trace_file]

  // Capture one in every N lookups. 1 captures all. Note that this drops whole
  // lookups uniformly, which breaks the per-block access histories a cache
  // simulator needs; leave it at 1 for simulation runs and control trace
  // volume with the caller mask instead.
  uint64_t trace_sampling_frequency = 1; // [trace_sampling]

  // Stop writing once the trace file exceeds this many bytes. With compression
  // on this counts compressed bytes and is checked once per batch, so the file
  // may overshoot by at most one batch.
  uint64_t trace_max_file_size = uint64_t{64} * 1024 * 1024 * 1024;

  // Record the data blocks read from each file, not just the file sequence.
  bool trace_record_blocks = true; // [trace_blocks]

  // How a block is identified: 0 for ordinal (index among the file's data
  // blocks), 1 for offset (raw byte offset). Ordinal survives the SST file
  // being deleted but costs an index walk on first access to each file, which
  // is real extra I/O with a partitioned index.
  int trace_block_id_mode = 0; // [trace_block_id_mode]

  // Trace file compression: 0 for none, 1 for zstd. zstd produces a standard
  // .zst file that `zstd -d` reads.
  int trace_compression = 0; // [trace_compress]

  // zstd level, used only when trace_compression is 1. Level 1 gives most of
  // the achievable ratio on this data at a fraction of the CPU.
  int trace_compression_level = 1; // [trace_compression_level]

  // Record data blocks read by table iterators, which covers user iterators,
  // compaction, ingestion and verification.
  bool trace_record_iterator_accesses = true; // [trace_iters]

  // Record an iterator access only if bit (1 << caller) is set, where caller is
  // a TableReaderCaller value. Masking out compaction (bit 10) is the main
  // lever on trace size, since compaction typically outweighs user iterators by
  // one to two orders of magnitude.
  unsigned int trace_iterator_caller_mask = 0xFFFF; // [trace_caller_mask]

  bool IsKeyLookupTraceEnabled() const {
    return !key_lookup_trace_file.empty();
  }
#pragma endregion
};
#endif // DB_ENV_H_