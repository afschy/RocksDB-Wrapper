cmake_minimum_required(VERSION 3.10)
project(RocksWrapper VERSION 1.0)

set(CMAKE_CXX_STANDARD 20)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -DPROFILE")

if(NOT DISABLE_JEMALLOC)
    if(JEMALLOC)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DROCKSDB_JEMALLOC -DJEMALLOC_NO_DEMANGLE ${JEMALLOC_INCLUDE}")
        if(APPLE)
            list(APPEND EXEC_LDFLAGS "${JEMALLOC_LIB}" "-lpthread")
        else()
            list(APPEND EXEC_LDFLAGS "${JEMALLOC_LIB}" "-lpthread" "-lrt")
        endif()
    else()
        if(APPLE)
            list(APPEND EXEC_LDFLAGS "-lpthread")
        else()
            list(APPEND EXEC_LDFLAGS "-lpthread" "-lrt")
        endif()
    endif()
else()
    if(APPLE)
        list(APPEND EXEC_LDFLAGS "-lpthread")
    else()
        list(APPEND EXEC_LDFLAGS "-lpthread" "-lrt")
    endif()
endif()

# The three settings below are all FORCEd, and all of them have to be decided
# before add_subdirectory(lib/rocksdb) picks its own defaults. FORCE matters
# for more than precedence: a plain set(... CACHE ...) is a no-op against a
# build directory that was configured earlier, so without it an existing
# build/ would keep whatever it was first given, forever.

# The key lookup tracer writes .zst files through RocksDB's streaming
# compressor, which compiles in only when the ZSTD macro is defined. RocksDB
# defaults that to OFF, producing a binary that fails at StartTrace with "This
# build does not support zstd stream compression" instead of failing at
# configure time. Opt out with -DWITH_TRACE_COMPRESSION=OFF if you really want
# a build without it; RocksDB's find_package(zstd REQUIRED) fails loudly when
# the library is missing.
option(WITH_TRACE_COMPRESSION
       "Build with zstd, so key lookup traces can be compressed" ON)
if(WITH_TRACE_COMPRESSION)
    set(WITH_ZSTD ON CACHE BOOL "Build with zstd" FORCE)
    message(STATUS "zstd enabled; compressed key lookup traces available")
else()
    message(WARNING "WITH_TRACE_COMPRESSION is OFF. Traces can still be "
                    "written, but only uncompressed: --trace_compress=1 will "
                    "fail at runtime.")
endif()

# RocksDB forces CMAKE_BUILD_TYPE to Debug when it is unset and the source tree
# is a git checkout, which is every checkout of this repository. That builds
# without NDEBUG, so assertions run in the read path and db_bench prints
# "WARNING: Assertions are enabled" on every run. Choose Release first.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING
        "Build type: Debug, Release, RelWithDebInfo, MinSizeRel" FORCE)
endif()
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# RocksDB turns warnings into errors by default, and this fork predates the
# compilers people now build it with. GCC 16.2 alone produces two false
# positives that stop the build once optimization is on: -Wmaybe-uninitialized
# in the blob reader (rocksdb/file_system.h:938, from
# db/blob/blob_file_reader.cc) and -Wformat-truncation in db_bench_tool.cc.
# Chasing them one -Wno-error= at a time is a losing game across compiler
# versions, and a clone that will not build is worse than one that warns.
# Warnings are still printed; they just do not fail the build. Note this only
# ever applied to RocksDB's own sources -- its -Werror is set inside
# lib/rocksdb's directory scope and never reached the wrapper's targets.
set(FAIL_ON_WARNINGS OFF CACHE BOOL
    "Treat compile warnings as errors" FORCE)

# RocksDB compiles with -fno-rtti outside of Debug builds, but working_version
# subclasses rocksdb::EventListener, and inheriting from a polymorphic RocksDB
# class needs the base's typeinfo to have been emitted. Without this, linking
# fails with "undefined reference to typeinfo for rocksdb::Customizable".
set(USE_RTTI ON CACHE STRING
    "Enable RTTI; required because the wrapper subclasses EventListener" FORCE)

option(WITH_TESTS "Build with tests" OFF)
option(WITH_TOOLS "Build with tools" OFF)
option(WITH_ALL_TESTS "Build with all tests" OFF)
option(WITH_DB_BENCH "Build db_bench and place it in bin/" ON)

# db_bench lives behind RocksDB's WITH_BENCHMARK_TOOLS switch, which also
# defines eight other benchmark binaries we never run. Turn the switch on when
# db_bench is wanted, then drop the rest from the default build below.
if(WITH_DB_BENCH)
    set(WITH_BENCHMARK_TOOLS ON CACHE BOOL "Build with benchmark tools" FORCE)
else()
    set(WITH_BENCHMARK_TOOLS OFF CACHE BOOL "Build with benchmark tools" FORCE)
endif()
option(WITH_CORE_TOOLS "Build with core tools" OFF)
option(WITH_TRACE_TOOLS "Build with trace tools" OFF)


file(MAKE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lib/rocksdb/include)
# include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lib/KV-WorkloadGenerator/include) [deprecated]

# Build tectonic, but only when it can actually be built: that needs both the
# checkout and a Rust toolchain. An unconditional ALL target here fails the
# whole build on a machine missing either, and working_version depends on it,
# so it takes that down too.
find_program(CARGO_EXECUTABLE cargo)
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/Cargo.toml AND CARGO_EXECUTABLE)
    add_custom_target(tectonic-cli ALL
        COMMAND ${CARGO_EXECUTABLE} build --release
        COMMAND ${CMAKE_COMMAND} -E copy
                ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/target/release/tectonic-cli
                ${CMAKE_CURRENT_SOURCE_DIR}/bin/tectonic-cli
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic
        COMMENT "Building tectonic in release mode"
    )
elseif(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/Cargo.toml)
    message(STATUS "lib/tectonic not found; skipping the tectonic-cli target")
else()
    # A warning rather than a status: rebuild.sh ends in `clear`, so a status
    # line here would scroll away and bin/tectonic-cli would just be missing.
    message(WARNING "cargo not found; skipping the tectonic-cli target. "
                    "bin/tectonic-cli will not be built. Install a Rust "
                    "toolchain and re-run cmake if you need it.")
endif()

add_subdirectory(lib/rocksdb)

# RocksDB's targets were defined before CMAKE_RUNTIME_OUTPUT_DIRECTORY is set
# below, so db_bench needs its output directory set explicitly to land in bin/
# alongside working_version.
if(WITH_DB_BENCH)
    if(TARGET db_bench)
        set_target_properties(db_bench PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)
    else()
        message(WARNING "WITH_DB_BENCH is ON but no db_bench target exists. "
                        "RocksDB builds it only when gflags is available.")
    endif()

    # Each of these links the whole static library, so excluding them keeps
    # enabling db_bench from costing eight extra links.
    foreach(unused_bench cache_bench memtablerep_bench
                         range_del_aggregator_bench table_reader_bench
                         filter_bench hash_table_bench point_lock_bench)
        if(TARGET ${unused_bench})
            set_target_properties(${unused_bench} PROPERTIES
                EXCLUDE_FROM_ALL TRUE)
        endif()
    endforeach()
endif()
# add_subdirectory(lib/KV-WorkloadGenerator) [deprecated]

set(SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/aux_time.cc 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/buffer.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/db_env.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/event_listners.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/fluid_lsm.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/utils.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/run_workload.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/working_version.cc 
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

add_executable(working_version ${SOURCES})

# Link the rocksdb target rather than a hardcoded librocksdb.a path, so that
# RocksDB's own third-party dependencies (zstd, snappy, lz4, ...) come along.
# With the raw path, enabling any compression library breaks this link with
# undefined references.
target_link_libraries(working_version rocksdb ${EXEC_LDFLAGS})

add_dependencies(working_version rocksdb)
if(TARGET tectonic-cli)
    add_dependencies(working_version tectonic-cli)
endif()

target_compile_definitions(working_version PRIVATE -DPROFILE)