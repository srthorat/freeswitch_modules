# Incremental Build Verification Guide

This guide documents the batch-by-batch verification approach for building FreeSWITCH with transcription modules.

## Why Batch Build?

Instead of running one long 60-120 minute build, we split it into 7 batches that can be verified independently:

1. **Catch errors early** - If gRPC fails, we don't waste time building everything else first
2. **Resume from failures** - Can fix issues and continue from the last successful batch
3. **Understand dependencies** - See exactly which libraries are required and what they do
4. **Faster iteration** - Test changes to specific dependencies without rebuilding everything

---

## Build Batches

### Batch 1: CMake (5-10 min) ✅
**Status**: VERIFIED COMPLETE

**What it does**:
- Downloads CMake 3.28.3 source
- Bootstraps CMake build system
- Installs to /usr/local/bin/cmake

**Verification**:
```bash
cmake --version
# Expected: cmake version 3.28.3
```

**Script**: `./test-batch-simple.sh 1`

---

### Batch 2: gRPC + Protocol Buffers (15-30 min) ⏳
**Status**: IN PROGRESS

**What it does**:
- Clones gRPC 1.64.2 (12,000+ files)
- Clones 16 submodules:
  - Protocol Buffers (protobuf)
  - abseil-cpp (Google's C++ library)
  - BoringSSL (TLS/SSL library)
  - c-ares (async DNS)
  - googleapis (Google Cloud APIs)
  - re2 (regex library)
  - zlib (compression)
  - And 9 more...
- Builds gRPC with shared libraries
- Installs protoc (Protocol Buffer compiler)
- Installs grpc_cpp_plugin (gRPC C++ code generator)

**Time breakdown**:
- Clone main repo: 2-3 min
- Clone submodules: 5-8 min
- CMake configure: 2-3 min
- Build (16 cores): 15-20 min
- Install: 1-2 min

**Verification**:
```bash
/usr/local/bin/protoc --version
ls -lh /usr/local/bin/grpc_cpp_plugin
ls -lh /usr/local/lib/libgrpc++.so
```

**Script**: `./test-batch-simple.sh 2`

---

### Batch 3: googleapis + libwebsockets (5-10 min)
**Status**: PENDING

**What it does**:
- Clones googleapis (Google Cloud API definitions)
- Clones libwebsockets 4.3.3
- Builds libwebsockets for WebSocket-based modules:
  - mod_audio_fork
  - mod_azure_transcribe
  - mod_deepgram_transcribe

**Verification**:
```bash
ls -lh /usr/local/lib/libwebsockets.so
ls -d /tmp/freeswitch-build/googleapis
```

**Script**: `./test-batch-simple.sh 3`

---

### Batch 4: Azure Speech SDK (1-2 min)
**Status**: PENDING

**What it does**:
- Extracts Azure Speech SDK 1.37.0 from tarball
- Installs headers to /usr/local/include/MicrosoftSpeechSDK
- Installs libraries to /usr/local/lib
- Required for mod_azure_transcribe

**Verification**:
```bash
ls -lh /usr/local/lib/libMicrosoft.CognitiveServices.Speech.core.so
ls -d /usr/local/include/MicrosoftSpeechSDK
```

**Script**: `./test-batch-simple.sh 4`

---

### Batch 5: spandsp + sofia-sip + libfvad (10-15 min)
**Status**: PENDING

**What it does**:
- **spandsp**: Signal processing (DSP) library for FreeSWITCH
- **sofia-sip 1.13.17**: SIP (Session Initiation Protocol) stack
- **libfvad**: Voice Activity Detection library

**Verification**:
```bash
ls -lh /usr/local/lib/libspandsp.so
ls -lh /usr/local/lib/libsofia-sip-ua.so
ls -lh /usr/local/lib/libfvad.so
```

**Script**: `./test-batch-simple.sh 5`

---

### Batch 6: AWS SDK C++ + AWS C Common (20-40 min)
**Status**: PENDING

**What it does**:
- Builds AWS SDK C++ 1.11.345
- Only builds 2 required services:
  - `transcribestreaming` (for mod_aws_transcribe)
  - `lexv2-runtime` (for Lex integration)
- Builds AWS C Common library
- Installs pkg-config files

**Why it's slow**:
- AWS SDK is very large (even with only 2 services)
- Lots of templates to compile
- 15-25 minutes even with 16 CPU cores

**Verification**:
```bash
ls -lh /usr/local/lib/libaws-cpp-sdk-transcribestreaming.so
ls -lh /usr/local/lib/libaws-c-common.a
ls /usr/local/lib/pkgconfig/*aws*.pc
```

**Script**: `./test-batch-simple.sh 6`

---

### Batch 7: FreeSWITCH + Modules (20-30 min)
**Status**: PENDING

**What it does**:
- Clones FreeSWITCH 1.10.11
- Copies 5 transcription modules to src/mod/applications/
- Copies googleapis to libs/
- Adds modules to modules.conf
- Copies AWS SDK tarball and mod_conference patches
- Fixes cJSON header conflicts
- Bootstraps FreeSWITCH build system
- Configures with: `--enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=yes`
- Builds FreeSWITCH + all modules
- Installs to /usr/local/freeswitch/

**Module Verification**:
```bash
ls -lh /usr/local/freeswitch/mod/mod_*.so
ldd /usr/local/freeswitch/mod/mod_aws_transcribe.so
ldd /usr/local/freeswitch/mod/mod_azure_transcribe.so
ldd /usr/local/freeswitch/mod/mod_deepgram_transcribe.so
ldd /usr/local/freeswitch/mod/mod_google_transcribe.so
ldd /usr/local/freeswitch/mod/mod_audio_fork.so
```

**Script**: `./test-batch-simple.sh 7`

---

## Running All Batches

You can run all batches sequentially (not recommended for first build):
```bash
./test-batch-simple.sh 1
./test-batch-simple.sh 2
./test-batch-simple.sh 3
./test-batch-simple.sh 4
./test-batch-simple.sh 5
./test-batch-simple.sh 6  # Longest: AWS SDK
./test-batch-simple.sh 7  # Second longest: FreeSWITCH
```

---

## Monitoring Progress

### Check if build is running:
```bash
ps aux | grep test-batch-simple
```

### Monitor logs:
```bash
tail -f /tmp/batch2.log  # Replace 2 with current batch number
```

### Check build processes:
```bash
# For CMake/make builds:
ps aux | grep -E "cmake|make"

# For git operations:
ps aux | grep git
```

---

## Troubleshooting

### Batch fails with missing library
**Problem**: "cannot find -lsomething" or "library not found"

**Solution**: Previous batch may have failed silently. Re-run previous batch and check for errors.

### Out of memory during build
**Problem**: System runs out of RAM

**Solution**:
1. Close other applications
2. Reduce parallel jobs in script (change `BUILD_CPUS=$(nproc)` to `BUILD_CPUS=4`)
3. Add swap space if needed

### Git clone is very slow
**Problem**: Submodule cloning takes forever

**Solution**: Normal for gRPC (has 16 submodules, 100MB+ total). Just wait. You can monitor with:
```bash
du -sh /tmp/freeswitch-build/grpc
```

### Build stalls at specific percentage
**Problem**: Make appears frozen

**Solution**: It's probably compiling a large template file. Check CPU usage:
```bash
top  # Look for cc1plus or g++ at 100%
```

If CPU is high, build is progressing (just slow).

---

## Current Build Status

| Batch | Status | Time | Size |
|-------|--------|------|------|
| 1. CMake | ✅ COMPLETE | 3 min | ~50MB |
| 2. gRPC | ⏳ IN PROGRESS | 15-30 min | ~800MB |
| 3. googleapis + libwebsockets | ⏹️ PENDING | 5-10 min | ~200MB |
| 4. Azure SDK | ⏹️ PENDING | 1-2 min | ~100MB |
| 5. spandsp + sofia + fvad | ⏹️ PENDING | 10-15 min | ~100MB |
| 6. AWS SDK C++ | ⏹️ PENDING | 20-40 min | ~1GB |
| 7. FreeSWITCH + modules | ⏹️ PENDING | 20-30 min | ~500MB |

**Total estimated time**: 75-130 minutes
**Total disk space**: ~2.8GB build + ~500MB installed

---

## Next Steps

Once all batches complete:

1. **Test FreeSWITCH**:
```bash
/usr/local/freeswitch/bin/freeswitch -version
```

2. **Test module loading**:
```bash
/usr/local/freeswitch/bin/freeswitch -nc -nonat &
/usr/local/freeswitch/bin/fs_cli -x "module_exists mod_aws_transcribe"
```

3. **Check logs**:
```bash
tail -f /usr/local/freeswitch/log/freeswitch.log
```

4. **Create Docker image** (optional):
```bash
./build-locally.sh
```

---

## Comparison: Batch vs Full Build

| Aspect | Full Build | Batch Build |
|--------|------------|-------------|
| Total time | 60-120 min | 75-130 min |
| Error detection | At end | After each step |
| Resume capability | No | Yes |
| Disk cleanup | Manual | Per-batch |
| Learning value | Low | High |
| Debugging | Hard | Easy |

**Recommendation**: Use batch build for first time, then use full build (`build-local-system.sh`) for subsequent builds.

---

## Files Created

- `test-batch-simple.sh` - Main batch build script
- `/tmp/batch*.log` - Build logs for each batch
- `/tmp/freeswitch-build/` - Build directory (can be cleaned after install)

---

**Last Updated**: 2025-11-15
**Build Environment**: Ubuntu 24.04 (Noble)
**CPU Cores**: 16
**RAM**: 8GB+ recommended
