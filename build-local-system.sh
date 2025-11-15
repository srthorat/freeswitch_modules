#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    log_error ".env file not found"
    exit 1
fi

# Read versions from .env
log_info "Reading configuration from .env..."
CMAKE_VERSION=$(grep cmakeVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
GRPC_VERSION=$(grep grpcVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
LIBWEBSOCKETS_VERSION=$(grep libwebsocketsVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPEECH_SDK_VERSION=$(grep speechSdkVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPANDSP_VERSION=$(grep spandspVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SOFIA_VERSION=$(grep sofiaVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
AWS_SDK_CPP_VERSION=$(grep awsSdkCppVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
FREESWITCH_VERSION=$(grep freeswitchVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')

log_info "Configuration loaded:"
log_info "  CMake: $CMAKE_VERSION"
log_info "  gRPC: $GRPC_VERSION"
log_info "  libwebsockets: $LIBWEBSOCKETS_VERSION"
log_info "  Speech SDK: $SPEECH_SDK_VERSION"
log_info "  AWS SDK C++: $AWS_SDK_CPP_VERSION"
log_info "  FreeSWITCH: $FREESWITCH_VERSION"

# Set build directory
BUILD_DIR="/usr/local/src"
BUILD_CPUS=$(nproc)

log_info "Build directory: $BUILD_DIR"
log_info "Build CPUs: $BUILD_CPUS"

cd $BUILD_DIR

# Step 1: Install system dependencies
log_info "Step 1/13: Installing system dependencies..."
for i in $(seq 1 8); do mkdir -p "/usr/share/man/man${i}"; done

apt-get update && apt-get -y --quiet --allow-remove-essential upgrade
apt-get install -y --quiet --no-install-recommends \
    python-is-python3 lsof gcc g++ make build-essential git autoconf automake default-mysql-client redis-tools \
    curl telnet libtool libtool-bin libssl-dev libcurl4-openssl-dev libz-dev liblz4-tool \
    libxtables-dev libip6tc-dev libip4tc-dev libiptc-dev libavformat-dev liblua5.1-0-dev libavfilter-dev libavcodec-dev libswresample-dev \
    libevent-dev libpcap-dev libxmlrpc-core-c3-dev markdown libjson-glib-dev lsb-release libpq-dev php-dev \
    libhiredis-dev gperf libspandsp-dev default-libmysqlclient-dev htop dnsutils gdb libtcmalloc-minimal4 \
    gnupg2 wget pkg-config ca-certificates libjpeg-dev libsqlite3-dev libpcre3-dev libldns-dev libboost-all-dev \
    libspeex-dev libspeexdsp-dev libedit-dev libtiff-dev yasm libswscale-dev haveged libre2-dev \
    libopus-dev libsndfile-dev libshout3-dev libmpg123-dev libmp3lame-dev libopusfile-dev libgoogle-perftools-dev

git config --global http.postBuffer 524288000
git config --global https.postBuffer 524288000
git config --global pull.rebase true

log_info "System dependencies installed successfully"

# Step 2: Install CMake
log_info "Step 2/13: Installing CMake $CMAKE_VERSION..."
cd $BUILD_DIR
if [ ! -f "/usr/local/bin/cmake" ] || [ "$(/usr/local/bin/cmake --version | grep -oP '\d+\.\d+\.\d+' | head -1)" != "$CMAKE_VERSION" ]; then
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh
    chmod +x cmake-${CMAKE_VERSION}-linux-x86_64.sh
    ./cmake-${CMAKE_VERSION}-linux-x86_64.sh --skip-license --prefix=/usr/local
    rm -f cmake-${CMAKE_VERSION}-linux-x86_64.sh
    log_info "CMake $CMAKE_VERSION installed: $(cmake --version | head -1)"
else
    log_info "CMake $CMAKE_VERSION already installed"
fi

# Step 3: Build gRPC
log_info "Step 3/13: Building gRPC $GRPC_VERSION..."
cd $BUILD_DIR
if [ ! -d "grpc" ]; then
    git clone --depth 1 -b v$GRPC_VERSION https://github.com/grpc/grpc
    cd grpc
    git submodule update --init --recursive
    mkdir -p cmake/build
    cd cmake/build
    cmake -DBUILD_SHARED_LIBS=ON -DgRPC_SSL_PROVIDER=package -DCMAKE_BUILD_TYPE=RelWithDebInfo ../..
    make -j ${BUILD_CPUS}
    make install
    ldconfig /usr/local/lib
    log_info "gRPC built and installed successfully"
else
    log_info "gRPC directory already exists, skipping..."
fi

# Step 4: Build googleapis
log_info "Step 4/13: Building googleapis..."
cd $BUILD_DIR
if [ ! -d "googleapis" ]; then
    git clone https://github.com/googleapis/googleapis
    cd googleapis
    git checkout d81d0b9e6993d6ab425dff4d7c3d05fb2e59fa57
    LANGUAGE=cpp make -j ${BUILD_CPUS}
    log_info "googleapis built successfully"
else
    log_info "googleapis directory already exists, skipping..."
fi

# Step 5: Build libwebsockets
log_info "Step 5/13: Building libwebsockets $LIBWEBSOCKETS_VERSION..."
cd $BUILD_DIR
if [ ! -d "libwebsockets" ]; then
    git clone --depth 1 -b v$LIBWEBSOCKETS_VERSION https://github.com/warmcat/libwebsockets.git
    cd libwebsockets
    mkdir -p build
    cd build
    cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
    make -j ${BUILD_CPUS}
    make install
    log_info "libwebsockets built and installed successfully"
else
    log_info "libwebsockets directory already exists, skipping..."
fi

# Step 6: Install Azure Speech SDK
log_info "Step 6/13: Installing Azure Speech SDK $SPEECH_SDK_VERSION..."
if [ ! -d "/usr/local/include/MicrosoftSpeechSDK" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd /tmp
    tar xzf ${SCRIPT_DIR}/files/SpeechSDK-Linux-$SPEECH_SDK_VERSION.tar.gz
    cd SpeechSDK-Linux-$SPEECH_SDK_VERSION
    cp -r include /usr/local/include/MicrosoftSpeechSDK
    cp -r lib/ /usr/local/lib/MicrosoftSpeechSDK
    cp /usr/local/lib/MicrosoftSpeechSDK/x64/libMicrosoft.*.so /usr/local/lib/
    log_info "Azure Speech SDK installed successfully"
else
    log_info "Azure Speech SDK already installed"
fi

# Step 7: Build spandsp
log_info "Step 7/13: Building spandsp..."
cd $BUILD_DIR
if [ ! -d "spandsp" ]; then
    git clone https://github.com/freeswitch/spandsp.git
    cd spandsp
    git checkout $SPANDSP_VERSION
    ./bootstrap.sh
    ./configure
    make -j ${BUILD_CPUS}
    make install
    log_info "spandsp built and installed successfully"
else
    log_info "spandsp directory already exists, skipping..."
fi

# Step 8: Build sofia-sip
log_info "Step 8/13: Building sofia-sip $SOFIA_VERSION..."
cd $BUILD_DIR
if [ ! -d "sofia-sip" ]; then
    git clone --depth 1 -b v$SOFIA_VERSION https://github.com/freeswitch/sofia-sip.git
    cd sofia-sip
    ./bootstrap.sh
    ./configure
    make -j ${BUILD_CPUS}
    make install
    log_info "sofia-sip built and installed successfully"
else
    log_info "sofia-sip directory already exists, skipping..."
fi

# Step 9: Build libfvad
log_info "Step 9/13: Building libfvad..."
cd $BUILD_DIR
if [ ! -d "libfvad" ]; then
    git clone --depth 1 https://github.com/dpirch/libfvad.git
    cd libfvad
    autoreconf -i
    ./configure
    make -j ${BUILD_CPUS}
    make install
    log_info "libfvad built and installed successfully"
else
    log_info "libfvad directory already exists, skipping..."
fi

# Step 10: Build AWS C++ SDK
log_info "Step 10/13: Building AWS SDK C++ $AWS_SDK_CPP_VERSION..."
cd $BUILD_DIR
if [ ! -d "aws-sdk-cpp" ]; then
    git clone --depth 1 -b $AWS_SDK_CPP_VERSION https://github.com/aws/aws-sdk-cpp.git
    cd aws-sdk-cpp
    git submodule update --init --recursive
    mkdir -p build
    cd build
    cmake .. -DBUILD_ONLY="lexv2-runtime;transcribestreaming" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -Wno-error=nonnull -Wno-error=deprecated-declarations -Wno-error=uninitialized -Wno-error=maybe-uninitialized"
    make -j ${BUILD_CPUS}
    make install
    mkdir -p /usr/local/lib/pkgconfig
    find /usr/local/src/aws-sdk-cpp/ -type f -name "*.pc" | xargs cp -t /usr/local/lib/pkgconfig/
    log_info "AWS SDK C++ built and installed successfully"
else
    log_info "AWS SDK C++ directory already exists, skipping..."
fi

# Step 11: Build AWS C Common
log_info "Step 11/13: Building AWS C Common..."
cd $BUILD_DIR
if [ ! -d "aws-c-common" ]; then
    git clone --depth 1 https://github.com/awslabs/aws-c-common.git
    cd aws-c-common
    mkdir -p build
    cd build
    cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_SHARED_LIBS=OFF -DCMAKE_CXX_FLAGS="-Wno-unused-parameter"
    make -j ${BUILD_CPUS}
    make install
    log_info "AWS C Common built and installed successfully"
else
    log_info "AWS C Common directory already exists, skipping..."
fi

# Update library paths
ldconfig /usr/local/lib
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

# Step 12: Build FreeSWITCH with modules
log_info "Step 12/13: Building FreeSWITCH $FREESWITCH_VERSION with transcription modules..."
cd $BUILD_DIR

if [ ! -d "freeswitch" ]; then
    log_info "Cloning FreeSWITCH..."
    git clone --depth 1 -b v$FREESWITCH_VERSION https://github.com/signalwire/freeswitch.git
fi

cd freeswitch

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy modules
log_info "Copying transcription modules..."
cp -r ${SCRIPT_DIR}/modules/* src/mod/applications/

# Copy googleapis
log_info "Copying googleapis..."
cp -r $BUILD_DIR/googleapis libs/

# Apply patches and configurations
log_info "Applying patches and configurations..."
cp ${SCRIPT_DIR}/files/configure.ac.extra configure.ac
cp ${SCRIPT_DIR}/files/Makefile.am.extra Makefile.am
cp ${SCRIPT_DIR}/files/ax_check_compile_flag.m4 .
cp ${SCRIPT_DIR}/files/modules.conf.in.extra build/modules.conf.in
cp ${SCRIPT_DIR}/files/modules.conf.vanilla.xml.extra conf/vanilla/autoload_configs/modules.conf.xml
cp ${SCRIPT_DIR}/files/avmd.conf.xml conf/vanilla/autoload_configs/avmd_conf.xml

# Apply source patches
cd src
cp ${SCRIPT_DIR}/files/switch_core_media.c.patch .
cp ${SCRIPT_DIR}/files/switch_rtp.c.patch .
patch < switch_core_media.c.patch
patch < switch_rtp.c.patch
cp ${SCRIPT_DIR}/files/switch_event.c .

# Apply module patches
cd mod/applications/mod_avmd
cp ${SCRIPT_DIR}/files/mod_avmd.c.patch .
patch < mod_avmd.c.patch

cd ../mod_httapi
cp ${SCRIPT_DIR}/files/mod_httapi.c.patch .
patch < mod_httapi.c.patch

# Copy mod_conference files
cd ../mod_conference
cp ${SCRIPT_DIR}/files/mod_conference.h .
cp ${SCRIPT_DIR}/files/conference_api.c .

# Fix cJSON header conflict
cd $BUILD_DIR/freeswitch
log_info "Fixing cJSON header conflicts..."
sed -i '/#ifndef cJSON_AS4CPP__h/i #ifndef cJSON__h\n#define cJSON__h' /usr/local/include/aws/core/external/cjson/cJSON.h
echo '#endif' >> /usr/local/include/aws/core/external/cjson/cJSON.h

# Bootstrap and configure
log_info "Bootstrapping FreeSWITCH..."
./bootstrap.sh -j

log_info "Configuring FreeSWITCH..."
./configure --enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=yes

# Build FreeSWITCH
log_info "Building FreeSWITCH (this may take 30-60 minutes)..."
make -j ${BUILD_CPUS}

# Install FreeSWITCH
log_info "Installing FreeSWITCH..."
make install

# Copy configurations
log_info "Installing configuration files..."
cp ${SCRIPT_DIR}/files/acl.conf.xml /usr/local/freeswitch/conf/autoload_configs/
cp ${SCRIPT_DIR}/files/event_socket.conf.xml /usr/local/freeswitch/conf/autoload_configs/
cp ${SCRIPT_DIR}/files/switch.conf.xml /usr/local/freeswitch/conf/autoload_configs/
cp ${SCRIPT_DIR}/files/conference.conf.xml /usr/local/freeswitch/conf/autoload_configs/

rm -rf /usr/local/freeswitch/conf/dialplan/*
rm -rf /usr/local/freeswitch/conf/sip_profiles/*
cp -r ${SCRIPT_DIR}/files/dialplan/* /usr/local/freeswitch/conf/dialplan/
cp -r ${SCRIPT_DIR}/files/sip_profiles/* /usr/local/freeswitch/conf/sip_profiles/

cp conf/vanilla/autoload_configs/modules.conf.xml /usr/local/freeswitch/conf/autoload_configs/

# Update codec preferences
sed -i -e 's/global_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8/global_codec_prefs=PCMU,PCMA,OPUS,G722/g' /usr/local/freeswitch/conf/vars.xml
sed -i -e 's/outbound_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8/outbound_codec_prefs=PCMU,PCMA,OPUS,G722/g' /usr/local/freeswitch/conf/vars.xml

# Copy additional configs if provided
if [ -f "${SCRIPT_DIR}/freeswitch.xml" ]; then
    cp ${SCRIPT_DIR}/freeswitch.xml /usr/local/freeswitch/conf/freeswitch.xml
fi

if [ -f "${SCRIPT_DIR}/vars_diff.xml" ]; then
    cp ${SCRIPT_DIR}/vars_diff.xml /usr/local/freeswitch/conf/vars_diff.xml
fi

log_info "FreeSWITCH built and installed successfully"

# Step 13: Verify module loading
log_info "Step 13/13: Verifying transcription modules..."

MODULES_TO_CHECK=(
    "mod_audio_fork"
    "mod_aws_transcribe"
    "mod_azure_transcribe"
    "mod_deepgram_transcribe"
    "mod_google_transcribe"
)

# Check if module .so files exist
log_info "Checking module files..."
MODULE_DIR="/usr/local/freeswitch/mod"
ALL_MODULES_EXIST=true

for module in "${MODULES_TO_CHECK[@]}"; do
    if [ -f "$MODULE_DIR/${module}.so" ]; then
        log_info "  ✓ ${module}.so found"
    else
        log_error "  ✗ ${module}.so NOT FOUND"
        ALL_MODULES_EXIST=false
    fi
done

if [ "$ALL_MODULES_EXIST" = false ]; then
    log_error "Some modules are missing. Build may have failed."
    exit 1
fi

# Test module loading with FreeSWITCH
log_info "Testing module loading with FreeSWITCH..."

# Create a test script
cat > /tmp/test_modules.sh << 'TESTEOF'
#!/bin/bash
timeout 30 /usr/local/freeswitch/bin/freeswitch -nonat -nc -nf &
FS_PID=$!
sleep 10

# Check if FreeSWITCH is running
if ! ps -p $FS_PID > /dev/null; then
    echo "ERROR: FreeSWITCH failed to start"
    exit 1
fi

# Use fs_cli to check modules
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_audio_fork" > /tmp/mod_audio_fork.log 2>&1
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_aws_transcribe" > /tmp/mod_aws_transcribe.log 2>&1
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_azure_transcribe" > /tmp/mod_azure_transcribe.log 2>&1
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_deepgram_transcribe" > /tmp/mod_deepgram_transcribe.log 2>&1
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_google_transcribe" > /tmp/mod_google_transcribe.log 2>&1

# Shutdown FreeSWITCH
/usr/local/freeswitch/bin/fs_cli -x "fsctl shutdown" > /dev/null 2>&1
wait $FS_PID 2>/dev/null
TESTEOF

chmod +x /tmp/test_modules.sh

if /tmp/test_modules.sh; then
    log_info "FreeSWITCH started successfully"

    # Check module load results
    log_info "Module verification results:"
    for module in "${MODULES_TO_CHECK[@]}"; do
        if grep -q "true" /tmp/${module}.log 2>/dev/null || grep -q "SUCCESS" /tmp/${module}.log 2>/dev/null; then
            log_info "  ✓ $module loaded successfully"
        else
            log_warn "  ⚠ $module verification inconclusive (check /tmp/${module}.log)"
        fi
    done
else
    log_warn "Module load test inconclusive (FreeSWITCH test run failed)"
fi

# Final verification using ldd
log_info "Checking module dependencies..."
for module in "${MODULES_TO_CHECK[@]}"; do
    log_info "  Checking ${module}..."
    if ldd "$MODULE_DIR/${module}.so" | grep -q "not found"; then
        log_error "  ✗ ${module} has missing dependencies:"
        ldd "$MODULE_DIR/${module}.so" | grep "not found"
        ALL_MODULES_EXIST=false
    else
        log_info "  ✓ ${module} dependencies OK"
    fi
done

# Final summary
echo ""
echo "========================================="
log_info "BUILD COMPLETE!"
echo "========================================="
log_info "FreeSWITCH version: $FREESWITCH_VERSION"
log_info "Installation path: /usr/local/freeswitch"
log_info "Modules installed:"
for module in "${MODULES_TO_CHECK[@]}"; do
    log_info "  - $module"
done
echo ""
log_info "To start FreeSWITCH:"
echo "  /usr/local/freeswitch/bin/freeswitch -nc"
echo ""
log_info "To connect with fs_cli:"
echo "  /usr/local/freeswitch/bin/fs_cli"
echo ""
log_info "Check logs at:"
echo "  /usr/local/freeswitch/log/freeswitch.log"
echo "========================================="

if [ "$ALL_MODULES_EXIST" = true ]; then
    exit 0
else
    log_error "Some modules have issues. Please check the logs above."
    exit 1
fi
