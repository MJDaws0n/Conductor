#!/usr/bin/env bash
set -euo pipefail

pull_if_missing() {
  local name="$1"
  local version="$2"
  if [ -d "lib/$name" ]; then
    return 0
  fi
  nox pull "$name" -v "$version"
}

pull_if_missing std 1.3.1
pull_if_missing file_io 1.0.2
pull_if_missing env 1.0.3
pull_if_missing process 1.0.3
pull_if_missing time 1.0.2
