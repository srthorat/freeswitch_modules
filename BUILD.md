# Building FreeSWITCH with Transcription Modules

This repository provides a Docker-based build system for FreeSWITCH with transcription modules.

## Prerequisites

- Docker (20.10 or later)
- At least 8GB of free disk space
- 4GB+ RAM recommended for build

## Quick Start

### Using the Build Script (Recommended)

```bash
./build-locally.sh
```

This script:
1. Reads version configuration from `.env` file
2. Builds the Docker image with all dependencies
3. Tags the image as `freeswitch-transcribe:latest`

### Manual Build

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

## Build Configuration

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

## Build Stages

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

## Running the Container

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

## Included Modules

The build includes these transcription modules:

- **mod_audio_fork** - Generic WebSocket audio streaming
- **mod_aws_transcribe** - AWS Transcribe with speaker diarization
- **mod_azure_transcribe** - Azure Speech Services
- **mod_deepgram_transcribe** - Deepgram transcription
- **mod_google_transcribe** - Google Cloud Speech-to-Text

## Troubleshooting

### Build fails at dependency stage

If a build stage fails (e.g., grpc, aws-sdk-cpp), try:
1. Increase Docker memory limit to 6GB+
2. Set `BUILD_CPUS=1` for lower memory usage (slower build)

### Out of disk space

Multi-stage builds can use significant disk space. Clean up:
```bash
docker system prune -a
```

### Module not loading

Check FreeSWITCH logs:
```bash
docker logs freeswitch
```

Verify module is enabled in `/usr/local/freeswitch/conf/autoload_configs/modules.conf.xml`

## Build Time

Expected build times (approximate):
- **First build**: 45-90 minutes (depending on CPU/RAM)
- **Incremental builds**: 5-15 minutes (Docker layer caching)
- **With BUILD_CPUS=1**: 2-3 hours

## References

- [FreeSWITCH Documentation](https://freeswitch.org/confluence/)
- [AWS Transcribe Streaming](https://docs.aws.amazon.com/transcribe/latest/dg/streaming.html)
- [Azure Speech Services](https://azure.microsoft.com/en-us/services/cognitive-services/speech-services/)
- [Deepgram API](https://developers.deepgram.com/)
- [Google Cloud Speech-to-Text](https://cloud.google.com/speech-to-text)
