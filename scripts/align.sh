#!/usr/bin/env bash
# 委托给 vendor/my_env 里的同一脚本，避免副本漂移。
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
exec bash "$HERE/../vendor/my_env/skills/rtl-developer/scripts/align.sh" "$@"
