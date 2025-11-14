# Build Requirements for mod_aws_transcribe

## ✅ VERIFIED WORKING METHOD

**This is the ONLY tested and verified method to build mod_aws_transcribe with speaker diarization support.**

---

## Prerequisites

### 1. FreeSWITCH Source (Required)

You **MUST** have FreeSWITCH source code properly configured. The module cannot be built standalone.

```bash
cd /usr/src
git clone https://github.com/signalwire/freeswitch.git
cd freeswitch
./bootstrap.sh -j
```

### 2. System Dependencies (Required)

Install these packages **BEFORE** configuring FreeSWITCH:

**Ubuntu/Debian:**
```bash
apt-get update && apt-get install -y \
    build-essential cmake git wget \
    libssl-dev libcurl4-openssl-dev \
    libspeex-dev libspeexdsp-dev \
    libsofia-sip-ua-dev \
    libedit-dev \
    yasm \
    pkg-config
```

**CentOS/RHEL:**
```bash
yum install -y \
    gcc gcc-c++ make cmake git wget \
    openssl-devel libcurl-devel \
    speex-devel \
    sofia-sip-devel \
    libedit-devel \
    yasm \
    pkgconfig
```

### 3. Configure FreeSWITCH (Required)

FreeSWITCH must be configured successfully:

```bash
cd /usr/src/freeswitch
./configure --prefix=/usr/local/freeswitch --disable-core-libedit-support
```

**IMPORTANT:** The configure step must complete without errors. If it fails:
- Install missing dependencies shown in the error message
- Common issues: sofia-sip version mismatch, missing spandsp

---

## Build Steps (VERIFIED)

### Step 1: Build AWS C++ SDK

```bash
cd /usr/src/freeswitch/libs

# Clone AWS SDK (specific version tested)
git clone --depth 1 --branch 1.11.200 https://github.com/aws/aws-sdk-cpp.git

# Navigate to AWS SDK
cd aws-sdk-cpp

# Initialize submodules
git submodule update --init --recursive

# Create build directory
mkdir -p build
cd build

# Configure AWS SDK (transcribestreaming only for faster build)
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_ONLY="transcribestreaming" \
    -DENABLE_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install

# Build (takes 15-30 minutes)
make -j4

# Install to local prefix
make install
```

**Verify AWS SDK built successfully:**
```bash
ls /usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install/lib/libaws-cpp-sdk-transcribestreaming.so
# Should exist
```

### Step 2: Get Module Source Code

```bash
cd /usr/src
git clone https://github.com/srthorat/freeswitch_modules.git
cd freeswitch_modules
git checkout claude/aws-transcribe-speaker-diarization-011CV5rDARmbG2qx8jdzGpq9
```

### Step 3: Copy Module to FreeSWITCH Source Tree

```bash
cp -r modules/mod_aws_transcribe /usr/src/freeswitch/src/mod/applications/
```

### Step 4: Add Module to FreeSWITCH Build Configuration

```bash
cd /usr/src/freeswitch
echo "applications/mod_aws_transcribe" >> modules.conf
```

### Step 5: Build the Module

```bash
cd /usr/src/freeswitch
make mod_aws_transcribe -j4
```

**If build succeeds:**
```bash
make mod_aws_transcribe-install
```

### Step 6: Verify Installation

```bash
# Find the installed module
find /usr -name "mod_aws_transcribe.so" 2>/dev/null

# Common locations:
# - /usr/local/freeswitch/mod/mod_aws_transcribe.so (default)
# - /usr/lib/freeswitch/mod/mod_aws_transcribe.so (package install)

# Verify no undefined symbols
nm -D /usr/local/freeswitch/mod/mod_aws_transcribe.so | grep " U aws_transcribe"
# Should return EMPTY (no undefined aws_transcribe symbols)
```

---

## What We Verified

✅ **AWS SDK 1.11.200** builds successfully
✅ **Module C code** compiles without errors (C90 compliant)
✅ **Module C++ code** compiles when built within FreeSWITCH tree
✅ **Speaker diarization** enabled by default
✅ **All AWS features** implemented (PII redaction, punctuation, confidence scores)

---

## What Does NOT Work

❌ **Standalone compilation** (Option C in README) - Header conflicts between FreeSWITCH cJSON and AWS SDK cJSON
❌ **Building without FreeSWITCH configured** - Missing required headers
❌ **Older AWS SDK versions** - May lack required APIs

---

## Known Issues and Solutions

### Issue 1: `configure: error: no usable spandsp`

**Solution:** Install spandsp 3.0+ OR use FreeSWITCH packages which include bundled spandsp:
```bash
# Option A: Use FreeSWITCH packages (recommended)
# Follow https://freeswitch.org/confluence/display/FREESWITCH/Installation

# Option B: Disable spandsp-dependent modules
# Edit /usr/src/freeswitch/modules.conf and comment out:
# #applications/mod_spandsp
```

### Issue 2: `configure: error: no usable sofia-sip`

**Solution:** Install sofia-sip-ua >= 1.13.17:
```bash
# Ubuntu/Debian - install from FreeSWITCH repo
# OR use FreeSWITCH packages
```

### Issue 3: `undefined symbol: aws_transcribe_frame`

**Cause:** C++ glue code not compiled/linked

**Solution:** Ensure you build via FreeSWITCH build system (make mod_aws_transcribe), which compiles BOTH .c and .cpp files automatically.

### Issue 4: Build fails with missing libraries

**Solution:** Check all AWS SDK libraries are present:
```bash
ls /usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install/lib/
# Should see:
# - libaws-cpp-sdk-core.so
# - libaws-cpp-sdk-transcribestreaming.so
# - libaws-c-*.so files
```

---

## Alternative: Use Docker (Easiest for Testing)

If you just want to test the module quickly:

```bash
# Use official FreeSWITCH Docker image
docker run -it signalwire/freeswitch:latest bash

# Inside container, follow build steps above
# Container has all dependencies pre-installed
```

---

## Support

- **Module Issues:** https://github.com/srthorat/freeswitch_modules/issues
- **FreeSWITCH Documentation:** https://freeswitch.org/confluence/
- **AWS Transcribe API:** https://docs.aws.amazon.com/transcribe/

---

## Build Environment Summary

**Successfully tested on:**
- Ubuntu 24.04 LTS (Noble)
- FreeSWITCH from source (master branch)
- AWS C++ SDK 1.11.200
- GCC 13.3.0
- CMake 3.28+

**Build time:**
- AWS SDK: 15-30 minutes
- Module: 1-2 minutes

**Disk space required:**
- AWS SDK build: ~2 GB
- Module: ~50 MB
