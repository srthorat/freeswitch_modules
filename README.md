# FreeSWITCH Transcription Modules

A collection of FreeSWITCH modules for real-time speech-to-text transcription and audio streaming, supporting multiple cloud providers and services.

## Overview

This repository contains production-ready FreeSWITCH modules for integrating real-time transcription services from major cloud providers:

- **mod_audio_fork** - Stream audio to external services via WebSocket
- **mod_aws_transcribe** - Amazon Transcribe real-time streaming
- **mod_azure_transcribe** - Microsoft Azure Speech Services
- **mod_deepgram_transcribe** - Deepgram real-time transcription
- **mod_google_transcribe** - Google Cloud Speech-to-Text with gRPC streaming

## Modules

| Module | Provider | Protocol | Features |
|--------|----------|----------|----------|
| [mod_audio_fork](modules/mod_audio_fork/) | Generic | WebSocket | Audio streaming to external services |
| [mod_aws_transcribe](modules/mod_aws_transcribe/) | AWS | Native SDK | Streaming transcription, speaker diarization |
| [mod_azure_transcribe](modules/mod_azure_transcribe/) | Azure | WebSocket | Real-time transcription, language detection |
| [mod_deepgram_transcribe](modules/mod_deepgram_transcribe/) | Deepgram | WebSocket | Fast transcription, keyword boosting |
| [mod_google_transcribe](modules/mod_google_transcribe/) | Google Cloud | gRPC | High accuracy, punctuation, interim results |

## Prerequisites

These modules require a **custom build of FreeSWITCH** with additional dependencies:

### Required Dependencies

1. **libwebsockets** - Required by `mod_audio_fork`
2. **gRPC and protobuf** - Required by `mod_google_transcribe`
3. **AWS C++ SDK** - Required by `mod_aws_transcribe`

### FreeSWITCH Version

- FreeSWITCH 1.8 or later
- Custom patches for module support

## Building

This repository provides **4 build scripts** for different use cases:

### Quick Start: Choose Your Build Method

| Script | Use Case | Time | Best For |
|--------|----------|------|----------|
| `build-locally.sh` | Docker build | 60-90 min | Production deployment, CI/CD |
| `build-local-system.sh` | Full system build | 60-120 min | Development, testing, local setup |
| `build-batch.sh` | Incremental batch build | 75-130 min | Learning, debugging, first-time builds |
| `test-batch-simple.sh` | Simplified testing | 75-130 min | Testing without apt-get, validation |

---

### Option 1: Docker Build (Recommended for Production)

Build a complete Docker container with all modules:

```bash
./build-locally.sh
```

**Features:**
- Optimized container (~500MB final size)
- Isolated, reproducible builds
- All 5 transcription modules included
- Production-ready

**Documentation:** See [DOCKER_BUILD_GUIDE.md](DOCKER_BUILD_GUIDE.md)

---

### Option 2: Native System Build

Build FreeSWITCH directly on your system (Ubuntu 20.04/22.04/24.04 or Debian 11):

```bash
sudo ./build-local-system.sh
```

**Features:**
- Installs to `/usr/local/freeswitch/`
- All dependencies installed system-wide
- Automatic module verification
- Full build in one command

**Duration:** 60-120 minutes
**Documentation:** See [BUILD.md](BUILD.md)

---

### Option 3: Incremental Batch Build (Recommended for Learning)

Build in 7 independent batches for better error detection and debugging:

```bash
# Run all batches sequentially
sudo ./build-batch.sh all

# Or run individual batches
sudo ./build-batch.sh 1  # CMake
sudo ./build-batch.sh 2  # gRPC + Protobuf
sudo ./build-batch.sh 3  # googleapis + libwebsockets
sudo ./build-batch.sh 4  # Azure Speech SDK
sudo ./build-batch.sh 5  # spandsp + sofia-sip + libfvad
sudo ./build-batch.sh 6  # AWS SDK C++
sudo ./build-batch.sh 7  # FreeSWITCH + Modules
```

**Features:**
- Catch errors early (fail fast)
- Resume from last successful batch
- Understand dependencies
- Faster iteration during development

**Documentation:** See [INCREMENTAL_BUILD_GUIDE.md](INCREMENTAL_BUILD_GUIDE.md)

---

### Option 4: Simplified Test Build

Test the build process without installing system packages:

```bash
# Run specific batch (requires sudo for make install)
sudo ./test-batch-simple.sh 1

# Or run all batches
sudo ./test-batch-simple.sh all
```

**Features:**
- Builds in `/tmp/freeswitch-build/`
- No apt-get calls (skips package installation)
- Useful for testing on systems where you can't install packages
- Requires root only for `make install` and `ldconfig`

**Documentation:** See [INCREMENTAL_BUILD_GUIDE.md](INCREMENTAL_BUILD_GUIDE.md#scripts-available)

---

### Build Scripts Comparison

| Feature | Docker | Native | Batch | Test |
|---------|--------|--------|-------|------|
| Install system packages | ✓ | ✓ | ✓ | ✗ |
| Requires root | ✓ | ✓ | ✓ | ✓* |
| Build location | Container | /usr/local | /usr/local/src | /tmp |
| Resume capability | ✗ | ✗ | ✓ | ✓ |
| Module verification | ✓ | ✓ | ✓ | ✓ |
| Production ready | ✓ | ✓ | ✓ | ✗ |

*Only for `make install` and `ldconfig`

## Configuration

Each module has its own configuration file in `/usr/local/freeswitch/conf/autoload_configs/`:

- `audio_fork.conf.xml`
- `aws_transcribe.conf.xml`
- `azure_transcribe.conf.xml`
- `deepgram_transcribe.conf.xml`
- `google_transcribe.conf.xml`

See individual module README files for configuration details.

## Usage Examples

### AWS Transcribe with Speaker Diarization

```xml
<action application="aws_transcribe" data="en-US,us-east-1,interim=true,speaker_diarization=true"/>
```

### Google Cloud Speech-to-Text

```xml
<action application="google_transcribe" data="en-US,interim=true"/>
```

### Deepgram Real-time

```xml
<action application="deepgram_transcribe" data="en-US,interim=true"/>
```

### Audio Fork to WebSocket

```xml
<action application="audio_fork" data="wss://your-service.com/ws"/>
```

## Module Details

For detailed documentation on each module, see the individual README files:

- [mod_audio_fork README](modules/mod_audio_fork/README.md)
- [mod_aws_transcribe README](modules/mod_aws_transcribe/README.md)
- [mod_azure_transcribe README](modules/mod_azure_transcribe/README.md)
- [mod_deepgram_transcribe README](modules/mod_deepgram_transcribe/README.md)
- [mod_google_transcribe README](modules/mod_google_transcribe/README.md)

## Build Dependencies Summary

| Module | Dependencies |
|--------|--------------|
| mod_audio_fork | libwebsockets |
| mod_aws_transcribe | AWS C++ SDK (transcribestreaming) |
| mod_azure_transcribe | libwebsockets |
| mod_deepgram_transcribe | libwebsockets |
| mod_google_transcribe | gRPC, protobuf, Google Cloud Speech API |

## Troubleshooting

### Common Issues

1. **cJSON conflicts** - Ensure you're using the build process from ansible-role-fsmrf which handles header conflicts
2. **Missing symbols** - Verify all dependencies are properly installed and ldconfig has been run
3. **Module not loading** - Check FreeSWITCH logs and ensure module is in modules.conf

### Getting Help

- Check individual module README files for specific issues
- Review the [ansible-role-fsmrf tasks](https://github.com/drachtio/ansible-role-fsmrf/tree/main/tasks) for build guidance
- Examine [patch files](https://github.com/drachtio/ansible-role-fsmrf/tree/main/files) for required FreeSWITCH modifications

## Credits

These modules are based on the work from:
- [drachtio-freeswitch-modules](https://github.com/mdslaney/drachtio-freeswitch-modules) by mdslaney
- [drachtio project](https://drachtio.org/) by Dave Horton

## License

See individual module source files for licensing information.

## Contributing

Contributions are welcome! Please:
1. Test your changes with the ansible build process
2. Update module README files
3. Follow FreeSWITCH coding conventions
4. Submit pull requests with clear descriptions
