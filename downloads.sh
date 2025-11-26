#!/bin/bash
set -e

echo "=== Removing old release files ==="

# Remove old single file
rm -f hailo_volumes.tar.gz

# Ensure tar/ exists
mkdir -p tars

# Remove old files inside tar/
rm -f tars/kernel-source.tar.gz
rm -f tars/kernel-build.tar.gz

echo "=== Downloading latest GitHub releases ==="

# URLs
URL_HAILO="https://github.com/harisislam10/edgemind-software/releases/download/release-2025-11-26/hailo_volumes.tar.gz"
URL_KERNEL_BUILD="https://github.com/harisislam10/edgemind-software/releases/download/release-2025-11-26/kernel-build.tar.gz"
URL_KERNEL_SOURCE="https://github.com/harisislam10/edgemind-software/releases/download/release-2025-11-26/kernel-source.tar.gz"

# Download files
wget -O hailo_volumes.tar.gz "$URL_HAILO"
wget -O tars/kernel-build.tar.gz "$URL_KERNEL_BUILD"
wget -O tars/kernel-source.tar.gz "$URL_KERNEL_SOURCE"

echo "=== Downloads completed successfully ==="
