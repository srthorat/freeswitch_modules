#!/bin/bash
set -e

echo "[INFO] Testing CMake build only (no apt-get)..."

# Read CMAKE version from .env
CMAKE_VERSION=$(grep cmakeVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')

echo "[INFO] CMake version: $CMAKE_VERSION"
echo "[INFO] Build CPUs: $(nproc)"

cd /tmp

# Download CMake
if [ ! -f "cmake-$CMAKE_VERSION.tar.gz" ]; then
    echo "[INFO] Downloading CMake $CMAKE_VERSION..."
    wget -q https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION.tar.gz
    echo "[SUCCESS] Downloaded"
else
    echo "[INFO] CMake tarball already downloaded"
fi

# Extract
if [ ! -d "cmake-$CMAKE_VERSION" ]; then
    echo "[INFO] Extracting..."
    tar xzf cmake-$CMAKE_VERSION.tar.gz
    echo "[SUCCESS] Extracted"
else
    echo "[INFO] Already extracted"
fi

cd cmake-$CMAKE_VERSION

# Bootstrap
echo "[INFO] Bootstrapping CMake (this may take 2-3 minutes)..."
./bootstrap --parallel=$(nproc)

echo "[INFO] Building CMake..."
make -j $(nproc)

echo "[SUCCESS] CMake built successfully!"
echo "[INFO] Testing cmake binary..."
./bin/cmake --version

