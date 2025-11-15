#!/bin/bash
set -e

# Simplified batch testing - skips apt-get, focuses on building
# Usage: ./test-batch-simple.sh [batch_number]

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_success() { echo "[SUCCESS] $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read versions from .env
CMAKE_VERSION=$(grep cmakeVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
GRPC_VERSION=$(grep grpcVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
LIBWEBSOCKETS_VERSION=$(grep libwebsocketsVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPEECH_SDK_VERSION=$(grep speechSdkVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPANDSP_VERSION=$(grep spandspVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SOFIA_VERSION=$(grep sofiaVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
AWS_SDK_CPP_VERSION=$(grep awsSdkCppVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
FREESWITCH_VERSION=$(grep freeswitchVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')

BUILD_DIR="/tmp/freeswitch-build"
BUILD_CPUS=$(nproc)
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

mkdir -p $BUILD_DIR
cd $BUILD_DIR

log_info "Configuration: CMake=$CMAKE_VERSION, gRPC=$GRPC_VERSION, AWS=$AWS_SDK_CPP_VERSION"
log_info "Build directory: $BUILD_DIR"
log_info "Build CPUs: $BUILD_CPUS"

# Batch 1: CMake
batch_1() {
    log_info "========== BATCH 1: CMake =========="

    if [ -f "/tmp/cmake-$CMAKE_VERSION/bin/cmake" ]; then
        log_info "CMake already built, installing..."
        cd /tmp/cmake-$CMAKE_VERSION
        make install
        ldconfig
    else
        log_error "CMake not found. Please run test-cmake-build.sh first"
        exit 1
    fi

    cmake --version
    log_success "BATCH 1 COMPLETE: CMake $(cmake --version | head -1)"
}

# Batch 2: gRPC
batch_2() {
    log_info "========== BATCH 2: gRPC + Protobuf =========="
    cd $BUILD_DIR

    if [ ! -d "grpc" ]; then
        log_info "Cloning gRPC $GRPC_VERSION..."
        git clone --depth 1 -b v$GRPC_VERSION https://github.com/grpc/grpc
        cd grpc
        log_info "Updating submodules..."
        git submodule update --init --recursive
    else
        log_info "gRPC already cloned"
        cd grpc
    fi

    if [ ! -d "cmake/build" ]; then
        mkdir -p cmake/build
    fi

    cd cmake/build

    if [ ! -f "Makefile" ]; then
        log_info "Configuring gRPC..."
        cmake ../.. -DBUILD_SHARED_LIBS=ON -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF \
            -DgRPC_SSL_PROVIDER=package -DCMAKE_BUILD_TYPE=Release
    fi

    log_info "Building gRPC (15-30 minutes)..."
    make -j ${BUILD_CPUS}

    log_info "Installing gRPC..."
    make install
    ldconfig

    /usr/local/bin/protoc --version
    ls -lh /usr/local/bin/grpc_cpp_plugin
    log_success "BATCH 2 COMPLETE: gRPC and protoc installed"
}

# Batch 3: googleapis + libwebsockets
batch_3() {
    log_info "========== BATCH 3: googleapis + libwebsockets =========="
    cd $BUILD_DIR

    # googleapis
    if [ ! -d "googleapis" ]; then
        log_info "Cloning googleapis..."
        git clone --depth 1 https://github.com/googleapis/googleapis.git
    else
        log_info "googleapis already cloned"
    fi

    # libwebsockets
    if [ ! -d "libwebsockets" ]; then
        log_info "Cloning libwebsockets $LIBWEBSOCKETS_VERSION..."
        git clone --depth 1 -b v$LIBWEBSOCKETS_VERSION https://github.com/warmcat/libwebsockets.git
        cd libwebsockets
        mkdir -p build
    else
        log_info "libwebsockets already cloned"
        cd libwebsockets
    fi

    cd build

    if [ ! -f "Makefile" ]; then
        log_info "Configuring libwebsockets..."
        cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
    fi

    log_info "Building libwebsockets..."
    make -j ${BUILD_CPUS}
    make install
    ldconfig

    ls -lh /usr/local/lib/libwebsockets.so*
    log_success "BATCH 3 COMPLETE: googleapis and libwebsockets ready"
}

# Batch 4: Azure Speech SDK
batch_4() {
    log_info "========== BATCH 4: Azure Speech SDK =========="

    if [ ! -f "${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz" ]; then
        log_error "Azure Speech SDK not found: ${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz"
        exit 1
    fi

    if [ ! -d "/usr/local/include/MicrosoftSpeechSDK" ]; then
        cd /tmp
        log_info "Extracting Azure Speech SDK..."
        tar xzf ${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz
        cd SpeechSDK-Linux-$SPEECH_SDK_VERSION

        log_info "Installing headers and libraries..."
        cp -r include /usr/local/include/MicrosoftSpeechSDK
        cp -r lib/ /usr/local/lib/MicrosoftSpeechSDK
        cp /usr/local/lib/MicrosoftSpeechSDK/x64/libMicrosoft.*.so /usr/local/lib/
        ldconfig
    else
        log_info "Azure Speech SDK already installed"
    fi

    ls -lh /usr/local/lib/libMicrosoft.CognitiveServices.Speech.core.so
    log_success "BATCH 4 COMPLETE: Azure Speech SDK installed"
}

# Batch 5: spandsp + sofia-sip + libfvad
batch_5() {
    log_info "========== BATCH 5: spandsp + sofia-sip + libfvad =========="
    cd $BUILD_DIR

    # spandsp
    if [ ! -d "spandsp" ]; then
        log_info "Cloning spandsp..."
        git clone https://github.com/freeswitch/spandsp.git
        cd spandsp
        git checkout $SPANDSP_VERSION
        ./bootstrap.sh
        ./configure
    else
        log_info "spandsp already cloned"
        cd spandsp
    fi

    log_info "Building spandsp..."
    make -j ${BUILD_CPUS}
    make install
    ldconfig

    # sofia-sip
    cd $BUILD_DIR
    if [ ! -d "sofia-sip" ]; then
        log_info "Cloning sofia-sip $SOFIA_VERSION..."
        git clone --depth 1 -b v$SOFIA_VERSION https://github.com/freeswitch/sofia-sip.git
        cd sofia-sip
        ./bootstrap.sh
        ./configure
    else
        log_info "sofia-sip already cloned"
        cd sofia-sip
    fi

    log_info "Building sofia-sip..."
    make -j ${BUILD_CPUS}
    make install
    ldconfig

    # libfvad
    cd $BUILD_DIR
    if [ ! -d "libfvad" ]; then
        log_info "Cloning libfvad..."
        git clone --depth 1 https://github.com/dpirch/libfvad.git
        cd libfvad
        autoreconf -i
        ./configure
    else
        log_info "libfvad already cloned"
        cd libfvad
    fi

    log_info "Building libfvad..."
    make -j ${BUILD_CPUS}
    make install
    ldconfig

    ls -lh /usr/local/lib/libspandsp.so /usr/local/lib/libsofia-sip-ua.so /usr/local/lib/libfvad.so
    log_success "BATCH 5 COMPLETE: spandsp, sofia-sip, libfvad installed"
}

# Main
BATCH=${1:-1}

case "$BATCH" in
    1) batch_1 ;;
    2) batch_2 ;;
    3) batch_3 ;;
    4) batch_4 ;;
    5) batch_5 ;;
    *)
        echo "Usage: $0 [1|2|3|4|5]"
        echo "  1 - CMake (1 min)"
        echo "  2 - gRPC + Protobuf (15-30 min)"
        echo "  3 - googleapis + libwebsockets (5-10 min)"
        echo "  4 - Azure Speech SDK (1 min)"
        echo "  5 - spandsp + sofia-sip + libfvad (10-15 min)"
        exit 1
        ;;
esac

log_success "========== Batch $BATCH COMPLETED =========="
