# Build Scripts Comparison

This repository provides two build scripts for different use cases:

## 1. build-locally.sh (Docker Build)

**Purpose:** Build Docker container for production deployment

**What it does:**
- Reads versions from `.env` file
- Passes all build arguments to `docker build`
- Creates optimized container image (~500MB final size)
- Isolated, reproducible builds

**Usage:**
```bash
./build-locally.sh
```

**Output:** Docker image `freeswitch-transcribe:latest`

**Best for:**
- Production deployments
- Consistent environments
- CI/CD pipelines
- Quick deployment

---

## 2. build-local-system.sh (Native System Build)

**Purpose:** Build FreeSWITCH directly on host system with verification

**What it does:**
- Mirrors **all 14 Docker build stages exactly**
- Installs to `/usr/local/freeswitch`
- **Verifies all modules load successfully**
- Checks for missing dependencies
- Tests FreeSWITCH startup

**Usage:**
```bash
sudo ./build-local-system.sh
```

**Output:** Native FreeSWITCH installation at `/usr/local/freeswitch`

**Build Stages (matches Dockerfile):**

| Stage | Component | Version | Purpose |
|-------|-----------|---------|---------|
| 1 | System Packages | Debian/Ubuntu | gcc, g++, autotools, libraries |
| 2 | CMake | 3.28.3 | Modern build system |
| 3 | gRPC | 1.64.2 | Google Cloud Speech API |
| 4 | googleapis | d81d0b9 | Google Cloud protobuf definitions |
| 5 | libwebsockets | 4.3.3 | WebSocket support (audio_fork, azure, deepgram) |
| 6 | Azure Speech SDK | 1.37.0 | Microsoft Speech Services |
| 7 | spandsp | 0d2e6ac | Signal processing |
| 8 | sofia-sip | 1.13.17 | SIP stack |
| 9 | libfvad | latest | Voice Activity Detection |
| 10 | AWS SDK C++ | 1.11.345 | AWS Transcribe Streaming |
| 11 | AWS C Common | latest | AWS dependencies |
| 12 | FreeSWITCH | 1.10.11 | Telephony platform |
| 13 | Module Verification | - | **Verify all modules load** |

**Best for:**
- Development and debugging
- Testing module changes
- Verifying module dependencies
- Native performance
- Direct access to source

---

## Module Verification (build-local-system.sh only)

The local build script includes comprehensive module verification:

### 1. File Existence Check
```
✓ mod_audio_fork.so found
✓ mod_aws_transcribe.so found
✓ mod_azure_transcribe.so found
✓ mod_deepgram_transcribe.so found
✓ mod_google_transcribe.so found
```

### 2. Dependency Verification
```
Checking module dependencies...
  Checking mod_audio_fork...
  ✓ mod_audio_fork dependencies OK
  Checking mod_aws_transcribe...
  ✓ mod_aws_transcribe dependencies OK
  ...
```

### 3. FreeSWITCH Startup Test
- Starts FreeSWITCH in test mode
- Verifies no startup errors
- Tests module loading
- Cleanly shuts down

### 4. Module Load Test
```
Testing module loading with FreeSWITCH...
FreeSWITCH started successfully
Module verification results:
  ✓ mod_audio_fork loaded successfully
  ✓ mod_aws_transcribe loaded successfully
  ✓ mod_azure_transcribe loaded successfully
  ✓ mod_deepgram_transcribe loaded successfully
  ✓ mod_google_transcribe loaded successfully
```

---

## Quick Reference

| Feature | build-locally.sh | build-local-system.sh |
|---------|------------------|------------------------|
| Build Type | Docker container | Native system install |
| Requires root | No (docker group) | Yes (sudo) |
| Output location | Docker image | /usr/local/freeswitch |
| Verification | Manual | **Automatic** |
| Build time | 45-90 min | 60-120 min |
| Disk space | 8GB | 20GB |
| Isolation | Full (container) | None (host system) |
| Debugging | Docker exec | Native gdb |
| Best for | Production | Development |

---

## After Build

### Docker Build (build-locally.sh)
```bash
# Run container
docker run -d --name freeswitch \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 8021:8021/tcp \
  freeswitch-transcribe:latest

# Connect
docker exec -it freeswitch /usr/local/freeswitch/bin/fs_cli

# View logs
docker logs -f freeswitch
```

### Local Build (build-local-system.sh)
```bash
# Start FreeSWITCH
/usr/local/freeswitch/bin/freeswitch -nc

# Connect
/usr/local/freeswitch/bin/fs_cli

# Check modules
fs_cli -x "module_exists mod_aws_transcribe"

# View logs
tail -f /usr/local/freeswitch/log/freeswitch.log
```

---

## Choosing the Right Script

**Use `build-locally.sh` (Docker) when:**
- Deploying to production
- Need consistent, reproducible builds
- Want isolated environments
- Using orchestration (Kubernetes, Docker Swarm)
- Limited development environment setup

**Use `build-local-system.sh` (Native) when:**
- Developing or modifying modules
- Need to debug with gdb
- Testing module dependencies
- Want direct filesystem access
- Need to verify module loading before Docker build
- Developing on a dedicated build server

Both scripts use the same `.env` configuration file and produce
functionally identical FreeSWITCH installations.
