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

### Option 1: Using Ansible (Recommended)

The easiest way to build FreeSWITCH with these modules is using the [drachtio/ansible-role-fsmrf](https://github.com/drachtio/ansible-role-fsmrf) Ansible role:

```bash
# Clone the ansible role
git clone https://github.com/drachtio/ansible-role-fsmrf.git

# Review the role's tasks to understand the build process
cat ansible-role-fsmrf/tasks/*.yml

# Use in your playbook
```

This role handles:
- Installing all dependencies
- Applying necessary patches
- Building FreeSWITCH with module support
- Installing and configuring modules

**Note:** The ansible role assumes Debian 9 (stretch) as the target OS.

### Option 2: Manual Build

If you prefer not to use Ansible, you can follow the build steps manually:

#### 1. Build AWS C++ SDK (for mod_aws_transcribe)

```bash
# Install dependencies
apt-get install -y libcurl4-openssl-dev libssl-dev cmake build-essential

# Clone and build AWS SDK
git clone --depth 1 --branch 1.11.200 https://github.com/aws/aws-sdk-cpp.git
cd aws-sdk-cpp
git submodule update --init --recursive

mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_ONLY="transcribestreaming" \
  -DENABLE_TESTING=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local

make -j$(nproc)
make install
ldconfig
```

For detailed AWS SDK build instructions, see: https://github.com/drachtio/ansible-role-fsmrf/blob/main/tasks/grpc.yml#L28

#### 2. Build gRPC and protobuf (for mod_google_transcribe)

```bash
# Follow the official gRPC build instructions
# Or refer to: https://github.com/drachtio/ansible-role-fsmrf/blob/main/tasks/grpc.yml
```

#### 3. Install libwebsockets (for mod_audio_fork)

```bash
apt-get install -y libwebsockets-dev
```

#### 4. Build FreeSWITCH

```bash
# Clone FreeSWITCH
git clone https://github.com/signalwire/freeswitch.git
cd freeswitch

# Apply patches from ansible role
# See: https://github.com/drachtio/ansible-role-fsmrf/tree/main/files

# Configure and build
./bootstrap.sh
./configure
make -j$(nproc)
make install
```

#### 5. Build and Install Modules

```bash
# Copy modules to FreeSWITCH source
cp -r modules/mod_* /usr/src/freeswitch/src/mod/applications/

# Add modules to modules.conf
echo "applications/mod_audio_fork" >> /usr/src/freeswitch/modules.conf
echo "applications/mod_aws_transcribe" >> /usr/src/freeswitch/modules.conf
# ... add other modules

# Build modules
cd /usr/src/freeswitch
make mod_audio_fork-install
make mod_aws_transcribe-install
# ... build other modules
```

### Option 3: Using Docker

Pre-built Docker images are available with most modules:

```bash
# Pull the image (includes all modules except mod_aws_transcribe)
docker pull drachtio/drachtio-freeswitch-mrf:v1.10.1-full

# Run
docker run -d \
  --name freeswitch \
  --network host \
  drachtio/drachtio-freeswitch-mrf:v1.10.1-full
```

**Note:** The Docker image does not include `mod_aws_transcribe` due to licensing considerations.

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
