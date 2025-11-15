# Building FreeSWITCH with Transcription Modules

This repository provides **two build options** for FreeSWITCH with transcription modules:
1. **Docker Build** (recommended for production/deployment)
2. **Local System Build** (for development/testing with module verification)

---

## Option 1: Docker Build (Production)

**Prerequisites:**
- Docker (20.10 or later)
- At least 8GB of free disk space
- 4GB+ RAM recommended for build

### Quick Start

```bash
./build-locally.sh
```

This script:
1. Reads version configuration from `.env` file
2. Builds the Docker image with all dependencies
3. Tags the image as `freeswitch-transcribe:latest`
4. Creates isolated, reproducible builds

### Manual Docker Build

If you prefer to build manually:

```bash
docker build \
  --build-arg CMAKE_VERSION=3.28.3 \
  --build-arg GRPC_VERSION=1.64.2 \
  --build-arg LIBWEBSOCKETS_VERSION=4.3.3 \
  --build-arg SPEECH_SDK_VERSION=1.37.0 \
  --build-arg SPANDSP_VERSION=0d2e6ac \
  --build-arg SOFIA_VERSION=1.13.17 \
  --build-arg AWS_SDK_CPP_VERSION=1.11.345 \
  --build-arg FREESWITCH_MODULES_VERSION=claude/compare-aws-transcribe-modules-011CV5rDARmbG2qx8jdzGpq9 \
  --build-arg FREESWITCH_VERSION=1.10.11 \
  -t freeswitch-transcribe:latest .
```

### Docker Build Configuration

Edit `.env` to customize build versions:

```env
cmakeVersion=3.28.3
grpcVersion=1.64.2
libwebsocketsVersion=4.3.3
speechSdkVersion=1.37.0
awsSdkCppVersion=1.11.345
freeswitchModulesVersion=claude/compare-aws-transcribe-modules-011CV5rDARmbG2qx8jdzGpq9
freeswitchVersion=1.10.11
```

### Running the Container

```bash
docker run -d \
  --name freeswitch \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 8021:8021/tcp \
  -v $(pwd)/logs:/usr/local/freeswitch/log \
  -v $(pwd)/recordings:/usr/local/freeswitch/recordings \
  freeswitch-transcribe:latest
```

---

## Option 2: Local System Build (Development)

**Prerequisites:**
- Debian 11 (Bullseye) or Ubuntu 20.04/22.04
- Root access (sudo)
- At least 20GB of free disk space
- 8GB+ RAM recommended
- 4+ CPU cores recommended

### Quick Start

```bash
sudo ./build-local-system.sh
```

### What This Script Does

**Mirrors the Dockerfile exactly** with these steps:

- **Step 1/13**: Install system dependencies (gcc, g++, autotools, libraries)
- **Step 2/13**: Build and install CMake 3.28.3
- **Step 3/13**: Build and install gRPC 1.64.2 with Protocol Buffers
- **Step 4/13**: Build googleapis for Google Cloud Speech-to-Text
- **Step 5/13**: Build libwebsockets 4.3.3 for WebSocket modules
- **Step 6/13**: Install Azure Speech SDK 1.37.0
- **Step 7/13**: Build spandsp (signal processing)
- **Step 8/13**: Build sofia-sip 1.13.17 (SIP stack)
- **Step 9/13**: Build libfvad (voice activity detection)
- **Step 10/13**: Build AWS SDK C++ 1.11.345 (transcribestreaming + lexv2-runtime)
- **Step 11/13**: Build AWS C Common library
- **Step 12/13**: Build FreeSWITCH 1.10.11 with all transcription modules
- **Step 13/13**: **Verify all modules load correctly** ✓

### Module Verification

The script automatically verifies:
1. ✓ All module `.so` files are built
2. ✓ All module dependencies are satisfied (no missing libraries)
3. ✓ FreeSWITCH starts successfully
4. ✓ All transcription modules load without errors

**Modules verified:**
- `mod_audio_fork.so`
- `mod_aws_transcribe.so`
- `mod_azure_transcribe.so`
- `mod_deepgram_transcribe.so`
- `mod_google_transcribe.so`

### After Installation

```bash
# Start FreeSWITCH
/usr/local/freeswitch/bin/freeswitch -nc

# Connect with fs_cli
/usr/local/freeswitch/bin/fs_cli

# Check loaded modules
fs_cli -x "module_exists mod_aws_transcribe"

# View logs
tail -f /usr/local/freeswitch/log/freeswitch.log
```

### Expected Build Time

- **First build**: 60-120 minutes (depending on CPU/RAM)
- **CMake**: ~2 minutes
- **gRPC**: ~15-30 minutes
- **AWS SDK C++**: ~20-40 minutes
- **FreeSWITCH**: ~20-30 minutes

---

## Build Configuration (Both Options)

Both build scripts use the same `.env` file:

```env
cmakeVersion=3.28.3
grpcVersion=1.64.2
libwebsocketsVersion=4.3.3
speechSdkVersion=1.37.0
awsSdkCppVersion=1.11.345
freeswitchModulesVersion=claude/compare-aws-transcribe-modules-011CV5rDARmbG2qx8jdzGpq9
freeswitchVersion=1.10.11
```

## Docker Build Stages

The Dockerfile uses multi-stage builds for efficiency:

1. **base** - Debian bullseye with build tools
2. **base-cmake** - CMake installation
3. **grpc** - gRPC and Protocol Buffers
4. **grpc-googleapis** - Google Cloud APIs
5. **websockets** - libwebsockets for mod_audio_fork, mod_azure_transcribe, mod_deepgram_transcribe
6. **speechsdk** - Microsoft Azure Speech SDK
7. **aws-sdk-cpp** - AWS SDK for C++ (transcribestreaming)
8. **aws-c-common** - AWS C Common library
9. **spandsp** - Signal processing library
10. **sofia-sip** - SIP library
11. **libfvad** - Voice Activity Detection
12. **freeswitch-modules** - Clone of this repository
13. **freeswitch** - FreeSWITCH compilation with all modules
14. **final** - Slim runtime image (~500MB vs ~5GB build image)

## Included Modules

The build includes these transcription modules:

- **mod_audio_fork** - Generic WebSocket audio streaming
- **mod_aws_transcribe** - AWS Transcribe with speaker diarization
- **mod_azure_transcribe** - Azure Speech Services
- **mod_deepgram_transcribe** - Deepgram transcription
- **mod_google_transcribe** - Google Cloud Speech-to-Text

## Troubleshooting

### Docker Build Issues

**Build fails at dependency stage** (e.g., grpc, aws-sdk-cpp):
1. Increase Docker memory limit to 6GB+
2. Modify Dockerfile to set `BUILD_CPUS=1` for lower memory usage (slower build)

**Out of disk space:**
```bash
docker system prune -a
```

**Module not loading in container:**
```bash
docker logs freeswitch
```
Check `/usr/local/freeswitch/conf/autoload_configs/modules.conf.xml`

### Local Build Issues

**Missing dependencies error:**
```bash
# The script installs all dependencies, but if you encounter issues:
sudo apt-get update
sudo apt-get install -f
```

**Build fails at gRPC or AWS SDK:**
- Ensure you have at least 8GB RAM
- Script automatically uses all CPU cores; reduce if needed
- Check `/usr/local/src/<library>/build` for error logs

**Module fails to load:**
```bash
# Check module dependencies
ldd /usr/local/freeswitch/mod/mod_aws_transcribe.so

# Check FreeSWITCH logs
tail -f /usr/local/freeswitch/log/freeswitch.log

# Verify module exists
ls -lh /usr/local/freeswitch/mod/mod_*.so
```

**FreeSWITCH fails to start:**
```bash
# Run in foreground to see errors
/usr/local/freeswitch/bin/freeswitch -nc -nonat

# Check for port conflicts
netstat -tulpn | grep -E ':(5060|8021)'
```

**Module verification script fails:**
The build script automatically runs verification. If it fails:
1. Check that all `.so` files exist in `/usr/local/freeswitch/mod/`
2. Run `ldd` on each module to check for missing libraries
3. Ensure `LD_LIBRARY_PATH` includes `/usr/local/lib`
4. Check that FreeSWITCH can start: `/usr/local/freeswitch/bin/freeswitch -version`

## Build Times

### Docker Build
- **First build**: 45-90 minutes (depending on CPU/RAM)
- **Incremental builds**: 5-15 minutes (Docker layer caching)
- **With BUILD_CPUS=1**: 2-3 hours

### Local System Build
- **First build**: 60-120 minutes (depending on CPU/RAM)
- **CMake**: ~2 minutes
- **gRPC**: ~15-30 minutes
- **AWS SDK C++**: ~20-40 minutes
- **FreeSWITCH**: ~20-30 minutes
- **Module verification**: ~1 minute

## References

- [FreeSWITCH Documentation](https://freeswitch.org/confluence/)
- [AWS Transcribe Streaming](https://docs.aws.amazon.com/transcribe/latest/dg/streaming.html)
- [Azure Speech Services](https://azure.microsoft.com/en-us/services/cognitive-services/speech-services/)
- [Deepgram API](https://developers.deepgram.com/)
- [Google Cloud Speech-to-Text](https://cloud.google.com/speech-to-text)
