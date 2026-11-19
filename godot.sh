#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Keep editor settings, caches, and development saves local to this installation.
export XDG_DATA_HOME="$project_dir/.tools/godot/data"
export XDG_CONFIG_HOME="$project_dir/.tools/godot/config"
export XDG_CACHE_HOME="$project_dir/.tools/godot/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
if [[ $# -eq 0 ]]; then
    set -- --editor --path "$project_dir"
fi
exec "$project_dir/.tools/godot/Godot_v4.7.2-stable_linux.x86_64" "$@"
