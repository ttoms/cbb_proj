#!/usr/bin/env bash
# 委托给 vendor/my_env 里的同一脚本，避免副本漂移。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TARGET="$HERE/../vendor/my_env/skills/rtl-developer/scripts/align.sh"
if [ ! -f "$TARGET" ]; then
    echo "vendor/my_env 未初始化：请运行 git submodule update --init --recursive，或 git clone https://github.com/ttoms/my_env.git vendor/my_env" >&2
    exit 3
fi
exec bash "$TARGET" "$@"
