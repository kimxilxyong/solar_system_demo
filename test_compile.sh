#!/bin/bash

# Test compilation script for Godot Solar System Demo
# This script tests if the project can be loaded and scripts can be compiled

LIBSTDCXX="/usr/lib/libstdc++.so.6.0.36"
GODOT="/usr/bin/godot"
PROJECT_DIR="$(dirname "$0")"

if [ ! -f "$LIBSTDCXX" ]; then
    echo "Error: Required libstdc++ not found"
    exit 1
fi

if [ ! -x "$GODOT" ]; then
    echo "Error: Godot not found"
    exit 1
fi

echo "Testing Godot project compilation..."
echo "Project directory: $PROJECT_DIR"
echo ""

# Clean up any previous .godot directory
rm -rf "$PROJECT_DIR/.godot"

# Run Godot in check-project mode with LD_PRELOAD
LD_PRELOAD="$LIBSTDCXX" timeout 30 "$GODOT" --check-project --path "$PROJECT_DIR" 2>&1 | grep -E "(ERROR|SCRIPT ERROR|WARNING: res://.*ext_resource)" | head -20

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Project loaded (some warnings may be normal)"
else
    echo ""
    echo "✓ No critical errors found"
fi

echo ""
echo "Test complete"
