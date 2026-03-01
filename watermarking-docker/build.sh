#!/bin/bash
# Build script for Watermarking Docker image
# Copies C++ library from canonical source (root watermarking-functions)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Copying C++ source files from canonical location..."

# Ensure submodule is initialized
if [ ! -f "$PARENT_DIR/watermarking-functions/WatermarkDetection.cpp" ]; then
  echo "Initializing watermarking-functions submodule..."
  (cd "$PARENT_DIR" && git submodule update --init watermarking-functions)
fi

# Copy watermarking-functions directory from root (private submodule)
rm -rf "$SCRIPT_DIR/watermarking-functions"
cp -r "$PARENT_DIR/watermarking-functions" "$SCRIPT_DIR/"

echo "Building Docker image..."
docker build -t watermarking-docker "$SCRIPT_DIR"

echo "Build complete!"
