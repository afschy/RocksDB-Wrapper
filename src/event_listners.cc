#include <iostream>

#include "event_listners.h"

std::mutex mtx;
std::condition_variable cv;
bool compaction_complete = false;

void WaitForCompactions(DB *db) {
  std::unique_lock<std::mutex> lock(mtx);
  uint64_t num_running_compactions;
  uint64_t pending_compaction_bytes;
  uint64_t num_pending_compactions;

  while (!compaction_complete) {
    // Check if there are ongoing or pending compactions
    db->GetIntProperty("rocksdb.num-running-compactions",
                       &num_running_compactions);
    db->GetIntProperty("rocksdb.estimate-pending-compaction-bytes",
                       &pending_compaction_bytes);
    db->GetIntProperty("rocksdb.compaction-pending", &num_pending_compactions);
    if (num_running_compactions == 0 && pending_compaction_bytes == 0 &&
        num_pending_compactions == 0) {
      break;
    }
    cv.wait_for(lock, std::chrono::milliseconds(10));
  }
}

void CompactionsListner::OnCompactionBegin(DB *db,
                                           const CompactionJobInfo &ci) {
#ifdef PROFILE
  if (db_env->verbosity > Verbosity::MEDIUM) {
    std::cout << "    ================> Before compaction <================"
              << std::flush;
    // This function is not supported by default
    // RocksDB, you have to implement it by youself
    // db->PrintFullTreeSummary();
  }
#endif // PROFILE
}

void CompactionsListner::OnCompactionCompleted(DB *db,
                                               const CompactionJobInfo &ci) {
  std::lock_guard<std::mutex> lock(mtx);
  uint64_t num_running_compactions;
  uint64_t pending_compaction_bytes;
  uint64_t num_pending_compactions;
  db->GetIntProperty("rocksdb.num-running-compactions",
                     &num_running_compactions);
  db->GetIntProperty("rocksdb.estimate-pending-compaction-bytes",
                     &pending_compaction_bytes);
  db->GetIntProperty("rocksdb.compaction-pending", &num_pending_compactions);
  if (num_running_compactions == 0 && pending_compaction_bytes == 0 &&
      num_pending_compactions == 0) {
    compaction_complete = true;
  }
  cv.notify_one();
#ifdef PROFILE
  if (db_env->verbosity > Verbosity::MEDIUM) {
    std::cout << "    ================> After compaction <================"
              << std::flush;
    // This function is not supported by default
    // RocksDB, you have to implement it by youself
    // db->PrintFullTreeSummary();
  }
#endif // PROFILE
}