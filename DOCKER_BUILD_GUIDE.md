# Docker Build Guide

This guide explains how to build and verify the FreeSWITCH Docker image with transcription modules.

---

## Prerequisites

- Docker 20.10+ installed
- At least 8GB free disk space
- 4GB+ RAM for build
- Internet connection for downloading dependencies

---

## Quick Start

### Step 1: Verify Before Building

```bash
./verify-dockerfile.sh
```

This validates all files and configuration before starting the build.

**Expected output:**
```
✅ ALL TESTS PASSED

The Dockerfile is ready for building!
```

### Step 2: Build the Image

```bash
./build-locally.sh
```

This reads versions from `.env` and builds the image as `freeswitch-transcribe:latest`.

**Build time:** 45-90 minutes (depending on your system)

---

## Manual Build (Alternative)

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

---

## Build Stages Explained

The Docker build uses 14 multi-stage builds:

| Stage | Purpose | Time | Size |
|-------|---------|------|------|
| 1. base | System packages | ~2 min | 500MB |
| 2. base-cmake | CMake 3.28.3 | ~1 min | +50MB |
| 3. grpc | gRPC + protobuf | ~20 min | +800MB |
| 4. grpc-googleapis | Google Cloud APIs | ~5 min | +200MB |
| 5. websockets | libwebsockets 4.3.3 | ~2 min | +20MB |
| 6. speechsdk | Azure Speech SDK | ~1 min | +100MB |
| 7. aws-sdk-cpp | AWS SDK (transcribe) | ~25 min | +1GB |
| 8. aws-c-common | AWS dependencies | ~2 min | +50MB |
| 9. spandsp | Signal processing | ~3 min | +30MB |
| 10. sofia-sip | SIP stack | ~5 min | +50MB |
| 11. libfvad | Voice detection | ~1 min | +10MB |
| 12. freeswitch-modules | Clone modules | ~1 min | +10MB |
| 13. freeswitch | Build FreeSWITCH | ~25 min | +2GB |
| 14. final | Runtime image | ~2 min | **~500MB** |

**Total build time:** 45-90 minutes
**Final image size:** ~500MB (vs ~5GB for build stages)

---

## Running the Container

### Basic Usage

```bash
docker run -d \
  --name freeswitch \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 8021:8021/tcp \
  freeswitch-transcribe:latest
```

### With Persistent Storage

```bash
docker run -d \
  --name freeswitch \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 8021:8021/tcp \
  -v $(pwd)/logs:/usr/local/freeswitch/log \
  -v $(pwd)/recordings:/usr/local/freeswitch/recordings \
  -v $(pwd)/sounds:/usr/local/freeswitch/sounds \
  freeswitch-transcribe:latest
```

### Interactive Access

```bash
# Connect to fs_cli
docker exec -it freeswitch /usr/local/freeswitch/bin/fs_cli

# Shell access
docker exec -it freeswitch /bin/bash

# View logs
docker logs -f freeswitch
```

---

## Verifying the Build

### 1. Check Image Size

```bash
docker images | grep freeswitch-transcribe
```

**Expected:** ~500MB for the final image

### 2. Verify Modules Are Present

```bash
docker run --rm freeswitch-transcribe:latest ls -lh /usr/local/freeswitch/mod/mod_*.so
```

**Should list:**
- mod_audio_fork.so
- mod_aws_transcribe.so
- mod_azure_transcribe.so
- mod_deepgram_transcribe.so
- mod_google_transcribe.so

### 3. Check Module Dependencies

```bash
docker run --rm freeswitch-transcribe:latest \
  ldd /usr/local/freeswitch/mod/mod_aws_transcribe.so
```

**Should NOT show:** "not found" for any libraries

### 4. Test FreeSWITCH Starts

```bash
docker run --rm freeswitch-transcribe:latest \
  /usr/local/freeswitch/bin/freeswitch -version
```

**Should output:** FreeSWITCH version 1.10.11

### 5. Verify Module Loading

```bash
# Start container
docker run -d --name test-fs freeswitch-transcribe:latest

# Wait 10 seconds for startup
sleep 10

# Check module exists
docker exec test-fs /usr/local/freeswitch/bin/fs_cli -x "module_exists mod_aws_transcribe"

# Clean up
docker rm -f test-fs
```

**Should output:** true or SUCCESS

---

## Build Optimization

### Speed Up Builds

1. **Use build cache:**
   ```bash
   # Subsequent builds will be faster due to layer caching
   ./build-locally.sh
   ```

2. **Parallel builds:**
   ```bash
   # Dockerfile already uses all CPU cores (BUILD_CPUS=nproc)
   docker build --build-arg BUILD_CPUS=8 ...
   ```

3. **BuildKit (faster):**
   ```bash
   DOCKER_BUILDKIT=1 docker build ...
   ```

### Reduce Memory Usage

If build fails with OOM:

```bash
# Modify Dockerfile line 3:
ARG BUILD_CPUS=1  # Instead of nproc

# Or limit Docker memory:
docker build --memory=6g ...
```

---

## Troubleshooting

### Build Fails at gRPC Stage

**Problem:** Out of memory during gRPC build

**Solution:**
```bash
# Increase Docker memory to 6GB+
docker build --memory=6g -t freeswitch-transcribe:latest .
```

### Build Fails at AWS SDK Stage

**Problem:** Slow or OOM during AWS SDK build

**Solution:**
```bash
# Edit Dockerfile line 3
ARG BUILD_CPUS=2  # Reduce parallel jobs

# Rebuild
./build-locally.sh
```

### Module Not Found After Build

**Problem:** Module .so file missing

**Check:**
```bash
# Inspect the image
docker run --rm -it freeswitch-transcribe:latest /bin/bash

# Inside container
ls -lh /usr/local/freeswitch/mod/
```

**Fix:** Ensure `modules/` directory exists and has all 5 modules before building

### Container Won't Start

**Problem:** FreeSWITCH fails to start

**Debug:**
```bash
# Run in foreground to see errors
docker run --rm -it freeswitch-transcribe:latest \
  /usr/local/freeswitch/bin/freeswitch -nc -nonat

# Check logs
docker logs freeswitch
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build FreeSWITCH Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Verify Dockerfile
        run: ./verify-dockerfile.sh

      - name: Build Docker image
        run: ./build-locally.sh

      - name: Test image
        run: |
          docker run -d --name test freeswitch-transcribe:latest
          sleep 10
          docker exec test /usr/local/freeswitch/bin/fs_cli -x "status"
          docker rm -f test
```

---

## Advanced Usage

### Custom Configuration

```bash
# Mount custom config
docker run -d \
  --name freeswitch \
  -v /path/to/custom/freeswitch.xml:/usr/local/freeswitch/conf/freeswitch.xml:ro \
  -p 5060:5060/udp \
  -p 8021:8021/tcp \
  freeswitch-transcribe:latest
```

### Health Check

```bash
docker run -d \
  --name freeswitch \
  --health-cmd="/usr/local/freeswitch/bin/fs_cli -x 'status' || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  -p 5060:5060/udp \
  freeswitch-transcribe:latest
```

### Docker Compose

```yaml
version: '3.8'
services:
  freeswitch:
    image: freeswitch-transcribe:latest
    ports:
      - "5060:5060/udp"
      - "5060:5060/tcp"
      - "8021:8021/tcp"
    volumes:
      - ./logs:/usr/local/freeswitch/log
      - ./recordings:/usr/local/freeswitch/recordings
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - AWS_DEFAULT_REGION=us-east-1
    restart: unless-stopped
```

---

## Performance Tips

1. **Layer Caching:** Don't change `.env` frequently; Docker caches layers
2. **Multi-CPU:** Build machine should have 4+ cores for optimal speed
3. **SSD Storage:** Significantly faster than HDD for Docker builds
4. **Memory:** 8GB+ RAM recommended to avoid swap during build

---

## Maintenance

### Updating Versions

1. Edit `.env` file
2. Run verification: `./verify-dockerfile.sh`
3. Rebuild: `./build-locally.sh`

### Cleaning Up

```bash
# Remove build cache
docker builder prune -a

# Remove old images
docker image prune -a

# Remove everything (use with caution)
docker system prune -a --volumes
```

---

## Support

If you encounter issues:

1. Run `./verify-dockerfile.sh` to check prerequisites
2. Check Docker logs: `docker logs freeswitch`
3. Verify module files exist in `modules/` directory
4. Ensure `.env` has correct versions
5. Check [BUILD.md](BUILD.md) for additional troubleshooting

---

## Summary

**Pre-build:**
```bash
./verify-dockerfile.sh  # Verify everything is ready
```

**Build:**
```bash
./build-locally.sh      # Build the image (45-90 min)
```

**Run:**
```bash
docker run -d --name freeswitch \
  -p 5060:5060/udp -p 8021:8021/tcp \
  freeswitch-transcribe:latest
```

**Verify:**
```bash
docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "module_exists mod_aws_transcribe"
```

🎉 **Success!** FreeSWITCH with all transcription modules is running in Docker.
