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

# Build tectonic. It is not wired in as a submodule, so build it only when it
# is actually checked out; otherwise an unconditional ALL target here fails the
# whole build on a machine that has no lib/tectonic or no cargo.
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/Cargo.toml)
    add_custom_target(tectonic-cli ALL
        COMMAND cargo build --release
        COMMAND ${CMAKE_COMMAND} -E copy
                ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/target/release/tectonic-cli
                ${CMAKE_CURRENT_SOURCE_DIR}/bin/tectonic-cli
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic
        COMMENT "Building tectonic in release mode"
    )
else()
    message(STATUS "lib/tectonic not found; skipping the tectonic-cli target")
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