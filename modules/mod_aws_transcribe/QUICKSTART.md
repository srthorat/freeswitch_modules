# Quick Start Guide - mod_aws_transcribe

## Problem You May Have Encountered

If you got this error when loading the module:
```
undefined symbol: aws_transcribe_frame
```

**Root Cause:** Only the C file was compiled, but the C++ file (`aws_transcribe_glue.cpp`) that contains all AWS functions was not compiled or linked.

## Solution: Two-Step Build Process

### Step 1: Build AWS C++ SDK (One-Time Setup)

**Time:** ~25-35 minutes (one-time)

```bash
cd /usr/src/freeswitch/libs/aws-sdk-cpp
mkdir -p build && cd build

# Configure (only build transcribestreaming)
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_ONLY="transcribestreaming" \
    -DENABLE_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=/usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install

# Build (use all CPU cores)
make -j$(nproc)

# Install
make install
```

### Step 2: Build the Module

**Time:** ~2-3 minutes

```bash
cd /path/to/freeswitch_modules/modules/mod_aws_transcribe
./build_module_simple.sh
```

This script will:
- ✅ Copy module with **BOTH** C and C++ files
- ✅ Compile `mod_aws_transcribe.c` (C code)
- ✅ Compile `aws_transcribe_glue.cpp` (C++ AWS functions) ← **This was missing before!**
- ✅ Link both together properly
- ✅ Verify no undefined symbols remain

## What Gets Built

The module includes these files:
1. **mod_aws_transcribe.c** - FreeSWITCH module interface (C code)
2. **aws_transcribe_glue.cpp** - AWS Transcribe integration (C++ code)
   - `aws_transcribe_frame` - Processes audio frames
   - `aws_transcribe_init` - Initializes AWS SDK
   - `aws_transcribe_cleanup` - Cleans up resources
   - `aws_transcribe_session_init` - Starts transcription
   - `aws_transcribe_session_stop` - Stops transcription

## After Build

1. **Load the module:**
   ```bash
   fs_cli -x 'load mod_aws_transcribe'
   ```

2. **Configure AWS credentials** (see README_AWS_DIARIZATION.md)

3. **Test transcription:**
   ```bash
   fs_cli
   > originate user/1000 &echo
   > aws_transcribe <UUID> start en-US interim stereo
   ```

## Features Included

- ✅ **Speaker Diarization** (enabled by default)
- ✅ **PII Redaction** (configurable)
- ✅ **Partial Results Stabilization** (enabled by default)
- ✅ **Auto Punctuation** (always on)
- ✅ **Word Confidence Scores** (always included)
- ✅ **Content Moderation** (requires AWS vocabulary filter)

## Troubleshooting

### Still getting "undefined symbol" errors?

Check if C++ file was compiled:
```bash
nm -D /usr/local/freeswitch/mod/mod_aws_transcribe.so | grep aws_transcribe
```

Should show these as **defined** (not `U`):
- `aws_transcribe_frame`
- `aws_transcribe_init`
- `aws_transcribe_cleanup`
- `aws_transcribe_session_init`
- `aws_transcribe_session_stop`

If you see `U` (undefined), the C++ file wasn't compiled. Re-run the build script.

### AWS SDK build fails?

Install missing dependencies:
```bash
apt-get install -y libcurl4-openssl-dev libssl-dev cmake build-essential
```

## Full Documentation

See **README_AWS_DIARIZATION.md** for complete configuration and features.
