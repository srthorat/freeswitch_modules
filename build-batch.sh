#!/bin/bash
set -e

# Build FreeSWITCH in batches for incremental verification
# Usage: sudo ./build-batch.sh [batch_number]
# Example: sudo ./build-batch.sh 1    # Run only batch 1
#          sudo ./build-batch.sh all   # Run all batches

# Color output
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_success() {
    echo "[SUCCESS] $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    log_error ".env file not found in $SCRIPT_DIR"
    exit 1
fi

# Read versions from .env
log_info "Reading configuration from .env..."
cd "$SCRIPT_DIR"
CMAKE_VERSION=$(grep cmakeVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
GRPC_VERSION=$(grep grpcVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
LIBWEBSOCKETS_VERSION=$(grep libwebsocketsVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPEECH_SDK_VERSION=$(grep speechSdkVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPANDSP_VERSION=$(grep spandspVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SOFIA_VERSION=$(grep sofiaVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
AWS_SDK_CPP_VERSION=$(grep awsSdkCppVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
FREESWITCH_VERSION=$(grep freeswitchVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')

# Set build directory and environment
BUILD_DIR="/usr/local/src"
BUILD_CPUS=$(nproc)
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

log_info "Build configuration:"
log_info "  Build directory: $BUILD_DIR"
log_info "  Build CPUs: $BUILD_CPUS"
log_info "  CMake: $CMAKE_VERSION"
log_info "  gRPC: $GRPC_VERSION"
log_info "  libwebsockets: $LIBWEBSOCKETS_VERSION"
log_info "  Speech SDK: $SPEECH_SDK_VERSION"
log_info "  AWS SDK C++: $AWS_SDK_CPP_VERSION"
log_info "  FreeSWITCH: $FREESWITCH_VERSION"

cd $BUILD_DIR

# =============================================================================
# BATCH 1: System Dependencies + CMake
# =============================================================================
batch_1() {
    log_info "========================================="
    log_info "BATCH 1: System Dependencies + CMake"
    log_info "========================================="

    log_info "Step 1.1: Installing system dependencies..."
    for i in $(seq 1 8); do mkdir -p "/usr/share/man/man${i}"; done

    apt-get update && apt-get -y --quiet --allow-remove-essential upgrade
    apt-get -y --quiet install build-essential cmake automake autoconf libtool \
        pkg-config git wget curl libssl-dev zlib1g-dev libncurses5-dev \
        libsqlite3-dev libpcre3-dev libspeex-dev libspeexdsp-dev libedit-dev \
        libldns-dev liblua5.2-dev libopus-dev yasm nasm libavformat-dev \
        libswscale-dev libavresample-dev libjpeg-dev ca-certificates \
        libgoogle-perftools-dev google-perftools libsndfile1-dev

    log_success "System dependencies installed"

    log_info "Step 1.2: Building CMake $CMAKE_VERSION..."
    cd $BUILD_DIR
    if [ ! -d "cmake-$CMAKE_VERSION" ]; then
        wget -q https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION.tar.gz
        tar xzf cmake-$CMAKE_VERSION.tar.gz
        cd cmake-$CMAKE_VERSION
        ./bootstrap --parallel=${BUILD_CPUS}
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "CMake $CMAKE_VERSION built and installed"
    else
        log_info "CMake already exists, skipping..."
    fi

    # Verify
    cmake --version
    if [ $? -eq 0 ]; then
        log_success "BATCH 1 COMPLETED: CMake is working!"
    else
        log_error "BATCH 1 FAILED: CMake verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 2: gRPC + Protocol Buffers
# =============================================================================
batch_2() {
    log_info "========================================="
    log_info "BATCH 2: gRPC + Protocol Buffers"
    log_info "========================================="

    log_info "Step 2.1: Building gRPC $GRPC_VERSION..."
    cd $BUILD_DIR
    if [ ! -d "grpc" ]; then
        git clone --depth 1 -b v$GRPC_VERSION https://github.com/grpc/grpc
        cd grpc
        git submodule update --init --recursive
        mkdir -p cmake/build
        cd cmake/build
        cmake ../.. -DBUILD_SHARED_LIBS=ON -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF \
            -DgRPC_SSL_PROVIDER=package -DCMAKE_BUILD_TYPE=Release
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "gRPC built and installed"
    else
        log_info "gRPC already exists, skipping..."
    fi

    # Verify
    if [ -f "/usr/local/bin/grpc_cpp_plugin" ] && [ -f "/usr/local/bin/protoc" ]; then
        /usr/local/bin/protoc --version
        log_success "BATCH 2 COMPLETED: gRPC and protoc are working!"
    else
        log_error "BATCH 2 FAILED: gRPC verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 3: googleapis + libwebsockets
# =============================================================================
batch_3() {
    log_info "========================================="
    log_info "BATCH 3: googleapis + libwebsockets"
    log_info "========================================="

    log_info "Step 3.1: Building googleapis..."
    cd $BUILD_DIR
    if [ ! -d "googleapis" ]; then
        git clone --depth 1 https://github.com/googleapis/googleapis.git
        log_success "googleapis cloned"
    else
        log_info "googleapis already exists, skipping..."
    fi

    log_info "Step 3.2: Building libwebsockets $LIBWEBSOCKETS_VERSION..."
    cd $BUILD_DIR
    if [ ! -d "libwebsockets" ]; then
        git clone --depth 1 -b v$LIBWEBSOCKETS_VERSION https://github.com/warmcat/libwebsockets.git
        cd libwebsockets
        mkdir -p build
        cd build
        cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "libwebsockets built and installed"
    else
        log_info "libwebsockets already exists, skipping..."
    fi

    # Verify
    if [ -d "$BUILD_DIR/googleapis" ] && [ -f "/usr/local/lib/libwebsockets.so" ]; then
        log_success "BATCH 3 COMPLETED: googleapis and libwebsockets are ready!"
    else
        log_error "BATCH 3 FAILED: Verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 4: Azure Speech SDK
# =============================================================================
batch_4() {
    log_info "========================================="
    log_info "BATCH 4: Azure Speech SDK"
    log_info "========================================="

    log_info "Installing Azure Speech SDK $SPEECH_SDK_VERSION..."
    if [ ! -d "/usr/local/include/MicrosoftSpeechSDK" ]; then
        cd /tmp
        if [ ! -f "${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz" ]; then
            log_error "Azure Speech SDK file not found: ${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz"
            exit 1
        fi
        tar xzf ${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz
        cd SpeechSDK-Linux-$SPEECH_SDK_VERSION
        cp -r include /usr/local/include/MicrosoftSpeechSDK
        cp -r lib/ /usr/local/lib/MicrosoftSpeechSDK
        cp /usr/local/lib/MicrosoftSpeechSDK/x64/libMicrosoft.*.so /usr/local/lib/
        ldconfig /usr/local/lib
        log_success "Azure Speech SDK installed"
    else
        log_info "Azure Speech SDK already installed"
    fi

    # Verify
    if [ -d "/usr/local/include/MicrosoftSpeechSDK" ] && [ -f "/usr/local/lib/libMicrosoft.CognitiveServices.Speech.core.so" ]; then
        log_success "BATCH 4 COMPLETED: Azure Speech SDK is ready!"
    else
        log_error "BATCH 4 FAILED: Azure Speech SDK verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 5: spandsp + sofia-sip + libfvad
# =============================================================================
batch_5() {
    log_info "========================================="
    log_info "BATCH 5: spandsp + sofia-sip + libfvad"
    log_info "========================================="

    log_info "Step 5.1: Building spandsp..."
    cd $BUILD_DIR
    if [ ! -d "spandsp" ]; then
        git clone https://github.com/freeswitch/spandsp.git
        cd spandsp
        git checkout $SPANDSP_VERSION
        ./bootstrap.sh
        ./configure
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "spandsp built and installed"
    else
        log_info "spandsp already exists, skipping..."
    fi

    log_info "Step 5.2: Building sofia-sip $SOFIA_VERSION..."
    cd $BUILD_DIR
    if [ ! -d "sofia-sip" ]; then
        git clone --depth 1 -b v$SOFIA_VERSION https://github.com/freeswitch/sofia-sip.git
        cd sofia-sip
        ./bootstrap.sh
        ./configure
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "sofia-sip built and installed"
    else
        log_info "sofia-sip already exists, skipping..."
    fi

    log_info "Step 5.3: Building libfvad..."
    cd $BUILD_DIR
    if [ ! -d "libfvad" ]; then
        git clone --depth 1 https://github.com/dpirch/libfvad.git
        cd libfvad
        autoreconf -i
        ./configure
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "libfvad built and installed"
    else
        log_info "libfvad already exists, skipping..."
    fi

    # Verify
    if [ -f "/usr/local/lib/libspandsp.so" ] && [ -f "/usr/local/lib/libsofia-sip-ua.so" ] && [ -f "/usr/local/lib/libfvad.so" ]; then
        log_success "BATCH 5 COMPLETED: spandsp, sofia-sip, and libfvad are ready!"
    else
        log_error "BATCH 5 FAILED: Verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 6: AWS SDK C++ + AWS C Common
# =============================================================================
batch_6() {
    log_info "========================================="
    log_info "BATCH 6: AWS SDK C++ + AWS C Common"
    log_info "========================================="

    log_info "Step 6.1: Building AWS SDK C++ $AWS_SDK_CPP_VERSION..."
    cd $BUILD_DIR
    if [ ! -d "aws-sdk-cpp" ]; then
        git clone --depth 1 -b $AWS_SDK_CPP_VERSION https://github.com/aws/aws-sdk-cpp.git
        cd aws-sdk-cpp
        git submodule update --init --recursive
        mkdir -p build
        cd build
        cmake .. -DBUILD_ONLY="lexv2-runtime;transcribestreaming" -DCMAKE_BUILD_TYPE=RelWithDebInfo \
            -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -Wno-error=nonnull -Wno-error=deprecated-declarations -Wno-error=uninitialized -Wno-error=maybe-uninitialized"
        make -j ${BUILD_CPUS}
        make install
        mkdir -p /usr/local/lib/pkgconfig
        find /usr/local/src/aws-sdk-cpp/ -type f -name "*.pc" | xargs cp -t /usr/local/lib/pkgconfig/
        ldconfig /usr/local/lib
        log_success "AWS SDK C++ built and installed"
    else
        log_info "AWS SDK C++ already exists, skipping..."
    fi

    log_info "Step 6.2: Building AWS C Common..."
    cd $BUILD_DIR
    if [ ! -d "aws-c-common" ]; then
        git clone --depth 1 https://github.com/awslabs/aws-c-common.git
        cd aws-c-common
        mkdir -p build
        cd build
        cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_SHARED_LIBS=OFF -DCMAKE_CXX_FLAGS="-Wno-unused-parameter"
        make -j ${BUILD_CPUS}
        make install
        ldconfig /usr/local/lib
        log_success "AWS C Common built and installed"
    else
        log_info "AWS C Common already exists, skipping..."
    fi

    # Verify
    if [ -f "/usr/local/lib/libaws-cpp-sdk-transcribestreaming.so" ] && [ -f "/usr/local/lib/libaws-c-common.a" ]; then
        log_success "BATCH 6 COMPLETED: AWS SDK C++ and AWS C Common are ready!"
    else
        log_error "BATCH 6 FAILED: Verification failed"
        exit 1
    fi
}

# =============================================================================
# BATCH 7: FreeSWITCH + Modules
# =============================================================================
batch_7() {
    log_info "========================================="
    log_info "BATCH 7: FreeSWITCH + Modules"
    log_info "========================================="

    log_info "Building FreeSWITCH $FREESWITCH_VERSION with transcription modules..."
    cd $BUILD_DIR

    if [ ! -d "freeswitch" ]; then
        log_info "Cloning FreeSWITCH..."
        git clone --depth 1 -b v$FREESWITCH_VERSION https://github.com/signalwire/freeswitch.git
    fi

    cd freeswitch

    # Copy modules
    log_info "Copying transcription modules..."
    cp -r ${SCRIPT_DIR}/modules/* src/mod/applications/

    # Copy googleapis
    log_info "Copying googleapis..."
    cp -r $BUILD_DIR/googleapis libs/

    # Add modules to modules.conf
    log_info "Adding modules to modules.conf..."
    cat >> modules.conf <<EOF
applications/mod_audio_fork
applications/mod_aws_transcribe
applications/mod_azure_transcribe
applications/mod_deepgram_transcribe
applications/mod_google_transcribe
EOF

    # Copy vars_diff.xml if it exists
    if [ -f "${SCRIPT_DIR}/vars_diff.xml" ]; then
        log_info "Copying vars_diff.xml..."
        cp ${SCRIPT_DIR}/vars_diff.xml autoload_configs/
    fi

    # Copy AWS SDK tarball
    log_info "Copying AWS SDK tarball..."
    mkdir -p libs/aws-sdk-cpp
    cp ${SCRIPT_DIR}/files/aws-sdk-cpp-1.11.200.tar.gz libs/aws-sdk-cpp/

    # Copy mod_conference files
    cd src/mod/applications/mod_conference
    cp ${SCRIPT_DIR}/files/mod_conference.h .
    cp ${SCRIPT_DIR}/files/conference_api.c .

    # Fix cJSON header conflict
    cd $BUILD_DIR/freeswitch
    log_info "Fixing cJSON header conflicts..."
    if ! grep -q "ifndef cJSON__h" /usr/local/include/aws/core/external/cjson/cJSON.h; then
        sed -i '/#ifndef cJSON_AS4CPP__h/i #ifndef cJSON__h\n#define cJSON__h' /usr/local/include/aws/core/external/cjson/cJSON.h
        echo '#endif' >> /usr/local/include/aws/core/external/cjson/cJSON.h
        log_info "cJSON header fixed"
    else
        log_info "cJSON header already fixed"
    fi

    # Bootstrap and configure
    log_info "Bootstrapping FreeSWITCH..."
    ./bootstrap.sh -j

    log_info "Configuring FreeSWITCH..."
    ./configure --enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=yes

    # Build
    log_info "Building FreeSWITCH (this will take 20-30 minutes)..."
    make -j ${BUILD_CPUS}

    # Install
    log_info "Installing FreeSWITCH..."
    make install

    # Verify modules were built
    log_info "Verifying modules..."
    MODULE_DIR="/usr/local/freeswitch/mod"
    MODULES_TO_CHECK=("mod_audio_fork" "mod_aws_transcribe" "mod_azure_transcribe" "mod_deepgram_transcribe" "mod_google_transcribe")

    ALL_MODULES_EXIST=true
    for module in "${MODULES_TO_CHECK[@]}"; do
        if [ -f "$MODULE_DIR/${module}.so" ]; then
            log_success "  ✓ ${module}.so found"
        else
            log_error "  ✗ ${module}.so NOT FOUND"
            ALL_MODULES_EXIST=false
        fi
    done

    # Check dependencies
    for module in "${MODULES_TO_CHECK[@]}"; do
        if [ -f "$MODULE_DIR/${module}.so" ]; then
            if ldd "$MODULE_DIR/${module}.so" | grep -q "not found"; then
                log_error "  ✗ ${module} has missing dependencies:"
                ldd "$MODULE_DIR/${module}.so" | grep "not found"
                ALL_MODULES_EXIST=false
            else
                log_success "  ✓ ${module} dependencies OK"
            fi
        fi
    done

    if [ "$ALL_MODULES_EXIST" = true ]; then
        log_success "BATCH 7 COMPLETED: FreeSWITCH and all modules are ready!"
    else
        log_error "BATCH 7 FAILED: Some modules are missing or have dependency issues"
        exit 1
    fi
}

# =============================================================================
# Main execution
# =============================================================================

BATCH=${1:-1}

case "$BATCH" in
    1)
        batch_1
        ;;
    2)
        batch_2
        ;;
    3)
        batch_3
        ;;
    4)
        batch_4
        ;;
    5)
        batch_5
        ;;
    6)
        batch_6
        ;;
    7)
        batch_7
        ;;
    all)
        batch_1
        batch_2
        batch_3
        batch_4
        batch_5
        batch_6
        batch_7
        ;;
    *)
        echo "Usage: sudo $0 [1|2|3|4|5|6|7|all]"
        echo ""
        echo "Batches:"
        echo "  1 - System Dependencies + CMake (5-10 min)"
        echo "  2 - gRPC + Protocol Buffers (15-30 min)"
        echo "  3 - googleapis + libwebsockets (5-10 min)"
        echo "  4 - Azure Speech SDK (1-2 min)"
        echo "  5 - spandsp + sofia-sip + libfvad (10-15 min)"
        echo "  6 - AWS SDK C++ + AWS C Common (20-40 min)"
        echo "  7 - FreeSWITCH + Modules (20-30 min)"
        echo "  all - Run all batches sequentially"
        exit 1
        ;;
esac

log_success "========================================="
log_success "Batch $BATCH completed successfully!"
log_success "========================================="
