#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

"$PROJECT_ROOT/scripts/submodules.sh"

mkdir -p build
cd build

cmake ..

CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
make -j"$CORES"

clear
echo "build complete!"