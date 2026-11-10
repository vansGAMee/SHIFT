#!/usr/bin/env bash
set -euo pipefail
shift_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$shift_project_dir"
shift_godot_bin="${SHIFT_GODOT:-$shift_project_dir/tools/godot}"
mkdir -p builds/SHIFT-Linux builds/SHIFT-Windows
"$shift_godot_bin" --headless --editor --path . --import --quit
python3 tests/puzzle_model.py
"$shift_godot_bin" --headless --fixed-fps 60 --path . -- --campaign-test
shift_startup_test_dir="$(mktemp -d /tmp/shift-startup-XXXXXX)"
XDG_DATA_HOME="$shift_startup_test_dir" "$shift_godot_bin" --headless --fixed-fps 60 --path . -- --startup-test
shift_save_test_dir="$(mktemp -d /tmp/shift-save-XXXXXX)"
XDG_DATA_HOME="$shift_save_test_dir" "$shift_godot_bin" --headless --fixed-fps 60 --path . --script tests/saving.gd
"$shift_godot_bin" --headless --path . --export-release Linux
"$shift_godot_bin" --headless --path . --export-release Windows
python3 tools/package.py
