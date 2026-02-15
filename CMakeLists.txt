cmake_minimum_required(VERSION 3.10)
project(UniZNS VERSION 1.0)

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
option(WITH_BENCHMARK_TOOLS "Build with benchmark tools" OFF)
option(WITH_CORE_TOOLS "Build with core tools" OFF)
option(WITH_TRACE_TOOLS "Build with trace tools" OFF)
option(USE_RTTI "" ON)
set(ROCKSDB_PLUGINS "zenfs")


include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lib/rocksdb/include)
# include_directories(${CMAKE_CURRENT_SOURCE_DIR}/lib/KV-WorkloadGenerator/include) [deprecated]

# Build tectonic
add_custom_target(tectonic-cli ALL
    COMMAND cargo build --release
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic/target/release/tectonic-cli
            ${CMAKE_CURRENT_SOURCE_DIR}/bin/tectonic-cli
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/lib/tectonic
    COMMENT "Building tectonic in release mode"
)

add_subdirectory(lib/rocksdb)

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

target_link_libraries(working_version ${CMAKE_BINARY_DIR}/lib/rocksdb/librocksdb.a ${EXEC_LDFLAGS})

add_dependencies(working_version rocksdb)
add_dependencies(working_version tectonic-cli)

target_compile_definitions(working_version PRIVATE -DPROFILE)
