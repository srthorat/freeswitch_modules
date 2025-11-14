#!/bin/bash
#
# Complete Build Script for mod_aws_transcribe with AWS Transcribe Support
# This script ensures BOTH C and C++ files are properly compiled and linked
#

set -e  # Exit on any error

echo "========================================="
echo "Building mod_aws_transcribe"
echo "========================================="

# Configuration
FS_SRC_DIR=/usr/src/freeswitch
AWS_SDK_DIR=${FS_SRC_DIR}/libs/aws-sdk-cpp
MODULE_SRC=/home/user/freeswitch_modules/modules/mod_aws_transcribe

# Step 1: Wait for AWS SDK clone to complete (if still running)
echo ""
echo "[1/4] Checking AWS SDK clone status..."
if [ ! -d "${AWS_SDK_DIR}/.git" ]; then
    echo "ERROR: AWS SDK not found at ${AWS_SDK_DIR}"
    echo "The background clone may still be running. Please wait for it to complete."
    exit 1
fi

echo "AWS SDK found: $(du -sh ${AWS_SDK_DIR} | cut -f1)"

# Step 2: Build AWS SDK (only transcribestreaming)
echo ""
echo "[2/4] Building AWS C++ SDK (this takes 15-30 minutes)..."
cd ${AWS_SDK_DIR}

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

# Check if already built
if [ ! -f ".deps/install/lib/libaws-cpp-sdk-transcribestreaming.so" ]; then
    echo "Configuring AWS SDK..."
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_ONLY="transcribestreaming" \
        -DENABLE_TESTING=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=${AWS_SDK_DIR}/build/.deps/install

    echo "Compiling AWS SDK (using all CPU cores)..."
    make -j$(nproc)

    echo "Installing AWS SDK..."
    make install

    echo "AWS SDK build complete!"
else
    echo "AWS SDK already built, skipping..."
fi

# Step 3: Copy module to FreeSWITCH source tree
echo ""
echo "[3/4] Copying module to FreeSWITCH..."
cp -r ${MODULE_SRC} ${FS_SRC_DIR}/src/mod/applications/

# Add to modules.conf if not already there
if ! grep -q "applications/mod_aws_transcribe" ${FS_SRC_DIR}/modules.conf 2>/dev/null; then
    echo "applications/mod_aws_transcribe" >> ${FS_SRC_DIR}/modules.conf
    echo "Added mod_aws_transcribe to modules.conf"
fi

# Step 4: Build the module
echo ""
echo "[4/4] Building mod_aws_transcribe..."
cd ${FS_SRC_DIR}

# Clean any previous build
make mod_aws_transcribe-clean 2>/dev/null || true

# Build the module (this will compile BOTH .c and .cpp files)
echo "Compiling module (C and C++ files)..."
make mod_aws_transcribe

# Install
echo "Installing module..."
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
    echo "Checking for undefined symbols..."
    UNDEF=$(nm -D $MODULE_PATH | grep -c " U aws_transcribe" || true)
    if [ "$UNDEF" -gt 0 ]; then
        echo "⚠ WARNING: Found $UNDEF undefined aws_transcribe symbols"
        nm -D $MODULE_PATH | grep " U aws_transcribe"
        echo ""
        echo "This means the C++ glue code wasn't linked properly."
    else
        echo "✓ All aws_transcribe symbols are defined (C++ code properly linked!)"
    fi

    echo ""
    echo "To load the module in FreeSWITCH:"
    echo "  fs_cli -x 'load mod_aws_transcribe'"
else
    echo "✗ ERROR: Module not found after installation"
    exit 1
fi

echo ""
echo "Done!"
