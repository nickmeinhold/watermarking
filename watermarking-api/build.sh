#!/bin/bash
# Build script for Watermarking API Docker image
# This copies C++ source files from sibling directories and builds the image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Copying C++ source files..."

# Copy mark.cpp and detect.cpp from watermarking-docker
cp "$PARENT_DIR/watermarking-docker/mark.cpp" "$SCRIPT_DIR/"
cp "$PARENT_DIR/watermarking-docker/detect.cpp" "$SCRIPT_DIR/"

# Copy watermarking-functions directory
rm -rf "$SCRIPT_DIR/watermarking-functions"
cp -r "$PARENT_DIR/watermarking-functions" "$SCRIPT_DIR/"

echo "Building Docker image..."
docker build -t watermarking-api "$SCRIPT_DIR"

echo "Build complete!"
echo ""
echo "To run the API:"
echo "  docker run -p 8080:8080 -e API_KEY=your-secret-key watermarking-api"
