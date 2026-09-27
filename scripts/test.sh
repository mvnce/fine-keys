#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${FINEKEYS_TEST_DIR:-$project_root/.build/tests}"
mkdir -p "$build_dir"
xcrun swiftc -module-cache-path "$build_dir/ModuleCache" \
  "$project_root/FineKeys/KeyPolicy.swift" "$project_root/FineKeys/MediaKeyInterceptor.swift" \
  "$project_root/Tests/main.swift" -o "$build_dir/checks"
"$build_dir/checks"
