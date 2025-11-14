#!/bin/bash
#
# Simplified Build Script for mod_aws_transcribe
# This script assumes AWS SDK is already built at /usr/src/freeswitch/libs/aws-sdk-cpp
#

set -e  # Exit on any error

echo "========================================="
echo "Building mod_aws_transcribe Module"
echo "========================================="

# Configuration
FS_SRC_DIR=/usr/src/freeswitch
AWS_SDK_DIR=${FS_SRC_DIR}/libs/aws-sdk-cpp
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_SRC="${SCRIPT_DIR}"

# Check prerequisites
echo "[1/5] Checking prerequisites..."

if [ ! -d "${FS_SRC_DIR}" ]; then
    echo "ERROR: FreeSWITCH source not found at ${FS_SRC_DIR}"
    echo "Please run: cd /usr/src && git clone https://github.com/signalwire/freeswitch.git"
    exit 1
fi

if [ ! -d "${AWS_SDK_DIR}" ]; then
    echo "ERROR: AWS SDK not found at ${AWS_SDK_DIR}"
    echo "Please run the full build_aws_transcribe.sh script first"
    exit 1
fi

if [ ! -f "${AWS_SDK_DIR}/build/.deps/install/lib/libaws-cpp-sdk-transcribestreaming.so" ]; then
    echo "ERROR: AWS SDK not built yet"
    echo "Please wait for AWS SDK build to complete, or run:"
    echo "  cd ${AWS_SDK_DIR}/build && make -j\$(nproc) && make install"
    exit 1
fi

echo "✓ FreeSWITCH source: OK"
echo "✓ AWS SDK: OK"

# Copy module to FreeSWITCH source tree
echo ""
echo "[2/5] Copying module to FreeSWITCH..."
cp -r ${MODULE_SRC} ${FS_SRC_DIR}/src/mod/applications/
echo "✓ Module copied"

# Add to modules.conf if not already there
echo ""
echo "[3/5] Configuring build..."
if ! grep -q "applications/mod_aws_transcribe" ${FS_SRC_DIR}/modules.conf 2>/dev/null; then
    echo "applications/mod_aws_transcribe" >> ${FS_SRC_DIR}/modules.conf
    echo "✓ Added to modules.conf"
else
    echo "✓ Already in modules.conf"
fi

# Build the module
echo ""
echo "[4/5] Building module..."
cd ${FS_SRC_DIR}

# Clean any previous build
make mod_aws_transcribe-clean 2>/dev/null || true

# Build (this compiles BOTH .c and .cpp files)
echo "Compiling mod_aws_transcribe.c and aws_transcribe_glue.cpp..."
make mod_aws_transcribe -j$(nproc)

# Install
echo ""
echo "[5/5] Installing module..."
make mod_aws_transcribe-install

# Verify installation
echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="

MODULE_PATH=$(find /usr -name "mod_aws_transcribe.so" 2>/dev/null | head -1)
if [ -n "$MODULE_PATH" ]; then
    echo "✓ Module installed at: $MODULE_PATH"
    echo "✓ Module size: $(du -h $MODULE_PATH | cut -f1)"

    # Check for undefined symbols
    echo ""
    echo "Verifying symbols..."
    UNDEF=$(nm -D $MODULE_PATH | grep " U aws_transcribe" 2>/dev/null | wc -l)
    if [ "$UNDEF" -gt 0 ]; then
        echo "⚠ WARNING: Found $UNDEF undefined aws_transcribe symbols:"
        nm -D $MODULE_PATH | grep " U aws_transcribe"
        echo ""
        echo "This means the C++ glue code wasn't linked properly."
        echo "Please check the build log above for errors."
        exit 1
    else
        echo "✓ All symbols properly linked (no undefined aws_transcribe symbols)"
    fi

    echo ""
    echo "========================================="
    echo "Module ready to use!"
    echo "========================================="
    echo ""
    echo "To load in FreeSWITCH:"
    echo "  fs_cli -x 'load mod_aws_transcribe'"
    echo ""
    echo "To configure:"
    echo "  1. Add AWS credentials to FreeSWITCH environment"
    echo "  2. See README_AWS_DIARIZATION.md for full configuration"
else
    echo "✗ ERROR: Module not found after installation"
    exit 1
fi
