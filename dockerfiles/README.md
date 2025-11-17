# FreeSWITCH Docker Images

This directory contains Dockerfiles for building FreeSWITCH images with different configurations:

1. **Base Image** - Complete FreeSWITCH installation with all standard modules
2. **Individual Module Images** - Minimal FreeSWITCH with specific modules for testing

---

## 1. FreeSWITCH Base Image (Recommended Starting Point)

**Files**:
- Dockerfile: `Dockerfile.freeswitch-base`
- Build Script: `build-freeswitch-base.sh`
- Detailed Install Guide: `FREESWITCH_INSTALL.md`
- Deployment Guide: `DOCKER_HUB_DEPLOYMENT.md`

### Features
- ✅ FreeSWITCH 1.10.11 (production release) built from source
- ✅ All standard modules compiled (100+ modules)
- ✅ SIP and WebRTC support
- ✅ Event socket enabled (fs_cli ready)
- ✅ Extensions 1000 and 1001 pre-configured (password: 1234)
- ✅ System utilities (ps, netstat, ping, vim, curl)
- ✅ Supervisor for process management

### Quick Start

#### Build the Image
```bash
# Build (30-45 minutes on Intel, 60-90 on Apple Silicon)
./dockerfiles/build-freeswitch-base.sh freeswitch-base:1.10.11
```

#### Run FreeSWITCH
```bash
# Run with all ports mapped
docker run -d --name freeswitch \
    -p 5060:5060/tcp -p 5060:5060/udp \
    -p 5080:5080/tcp -p 8021:8021/tcp \
    -p 16384-16484:16384-16484/udp \
    freeswitch-base:1.10.11

# Wait for startup
sleep 30

# Connect with fs_cli
docker exec -it freeswitch fs_cli
```

#### Verify Installation
```bash
# Check FreeSWITCH status
docker exec freeswitch fs_cli -x "status"

# List loaded modules (should be 100+)
docker exec freeswitch fs_cli -x "show modules" | wc -l

# Check SIP profiles
docker exec freeswitch fs_cli -x "sofia status"

# View logs
docker logs -f freeswitch
```

#### Test Extensions
Pre-configured extensions ready to use:
- **Extension 1000**: Username=1000, Password=1234
- **Extension 1001**: Username=1001, Password=1234

Register SIP clients (Zoiper, Linphone, etc.) and test calling between extensions.

### Use Cases
- ✅ Production-ready FreeSWITCH deployment
- ✅ Testing SIP/WebRTC functionality
- ✅ Base for extending with custom modules
- ✅ Learning FreeSWITCH configuration

### Exposed Ports
| Port | Protocol | Purpose |
|------|----------|---------|
| 5060-5061 | TCP/UDP | SIP signaling |
| 5080-5081 | TCP/UDP | SIP over WebSocket (WebRTC) |
| 8021 | TCP | Event Socket (fs_cli) |
| 7443 | TCP | WebRTC signaling |
| 16384-16484 | UDP | RTP media (audio/video) |

---

## 2. Individual Module Testing

This approach provides several benefits:

## Benefits

1. **Faster Validation** - Build only the required module and dependencies (15-25 min vs 90-150 min)
2. **Individual Testing** - Test each module independently without interference from other modules
3. **Debugging** - Easier to identify module-specific dependency issues
4. **Development** - Quick iteration when developing or modifying a single module
5. **Minimal Footprint** - Smaller Docker images with only necessary dependencies

## Available Modules

### mod_audio_fork

**File**: `Dockerfile.mod_audio_fork`
**Build Script**: `docker-build-mod-audio-fork.sh`
**Base Image**: `srt2011/freeswitch-base:latest` (pre-built production FreeSWITCH)

**Dependencies Built**:
- libwebsockets 4.3.3 (WebSocket connectivity)
- libspeexdsp (speex resampler for audio)

**Build Time**:
- Intel/AMD64: **10-15 minutes** (6x faster than full build!)
- Apple Silicon: **20-30 minutes** (with emulation)

**Usage**:
```bash
# Build the image (with custom tag)
./dockerfiles/docker-build-mod-audio-fork.sh srt2011/freeswitch-mod-audio-fork:latest

# Or use default tag
./dockerfiles/docker-build-mod-audio-fork.sh

# Run FreeSWITCH (inherits base image behavior)
docker run -d --name fs \
  -p 5060:5060/udp \
  -p 8021:8021/tcp \
  srt2011/freeswitch-mod-audio-fork:latest

# Access fs_cli
docker exec -it fs fs_cli

# Verify mod_audio_fork loaded
docker exec -it fs fs_cli -x 'show modules' | grep audio_fork
api,uuid_audio_fork,mod_audio_fork,/usr/local/freeswitch/lib/freeswitch/mod/mod_audio_fork.so

docker exec -it fs grep -i "audio_fork" /usr/local/freeswitch/log/freeswitch.log
==>
2025-11-17 18:37:15.999527 0.00% [NOTICE] mod_audio_fork.c:300 mod_audio_fork API loading..
2025-11-17 18:37:15.999549 0.00% [NOTICE] lws_glue.cpp:372 mod_audio_fork: audio buffer (in secs):    2 secs
2025-11-17 18:37:15.999551 0.00% [NOTICE] lws_glue.cpp:373 mod_audio_fork: sub-protocol:              audio.drachtio.org
2025-11-17 18:37:15.999552 0.00% [NOTICE] lws_glue.cpp:374 mod_audio_fork: lws service threads:       1
2025-11-17 18:37:15.999623 0.00% [NOTICE] mod_audio_fork.c:324 mod_audio_fork API successfully loaded
2025-11-17 18:37:15.999630 0.00% [CONSOLE] switch_loadable_module.c:1772 Successfully Loaded [mod_audio_fork]
2025-11-17 18:37:15.999639 0.00% [NOTICE] switch_loadable_module.c:389 Adding API Function 'uuid_audio_fork'

docker exec -it fs ldd /usr/local/freeswitch/lib/freeswitch/mo
d/mod_audio_fork.so
        linux-vdso.so.1 (0x00007ffc44973000)
        libwebsockets.so.19 => /usr/local/lib/libwebsockets.so.19 (0x000073838879e000)
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x0000738388777000)
        libstdc++.so.6 => /usr/lib/x86_64-linux-gnu/libstdc++.so.6 (0x00007383885aa000)
        libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x0000738388590000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007383883bc000)
        libssl.so.1.1 => /usr/lib/x86_64-linux-gnu/libssl.so.1.1 (0x0000738388329000)
        libcrypto.so.1.1 => /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 (0x0000738388033000)
        /lib64/ld-linux-x86-64.so.2 (0x00007383888d9000)
        libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x0000738387eef000)
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x0000738387ee9000)
```

**Features**:
- ✅ Builds on production FreeSWITCH base image
- ✅ Only builds libwebsockets + mod_audio_fork (minimal dependencies)
- ✅ Inherits all base image configuration (SIP extensions, Event Socket, etc.)
- ✅ Automatic static + runtime validation during build
- ✅ Separate C/C++ compilation for proper type handling
- ✅ 182-line Dockerfile (48% smaller than original)
- ✅ Behaves identically to base image with mod_audio_fork added

## Build Process

### mod_audio_fork (Base Image Approach - RECOMMENDED)

**Uses pre-built production FreeSWITCH as base** - Much faster!

#### Stage 1: Builder - Install Build Dependencies
From `srt2011/freeswitch-base:latest`:
- Install: git, cmake, build-essential, libssl-dev, libspeexdsp-dev
- Base image already contains FreeSWITCH with all configurations

#### Stage 2: Builder - Build libwebsockets
- Clone and build libwebsockets 4.3.3 from source
- Only dependency needed for mod_audio_fork

#### Stage 3: Builder - Compile mod_audio_fork
- Separate C and C++ compilation:
  - `gcc` for mod_audio_fork.c → mod_audio_fork.o
  - `g++` for lws_glue.cpp → lws_glue.o
  - `g++` for audio_pipe.cpp → audio_pipe.o
- Link all object files with g++ shared

#### Stage 4: Builder - Static Validation
- Check module file exists
- Verify dependencies with ldd
- Validate libwebsockets linkage

#### Stage 5: Builder - Update Configuration
- Add `<load module="mod_audio_fork"/>` to modules.conf.xml

#### Stage 6: Builder - Runtime Validation
- Start FreeSWITCH in background
- Verify mod_audio_fork loads without errors
- **Build fails if validation fails**

#### Stage 7: Runtime Image
From `srt2011/freeswitch-base:latest`:
- Copy libwebsockets library
- Copy mod_audio_fork.so
- Copy updated modules.conf.xml
- **Inherit ENTRYPOINT/CMD from base image**
- Behaves exactly like base + mod_audio_fork

**Total Build Time**: 10-15 minutes (vs 90+ minutes for full build!)

---

### Legacy Approach (Full Build from Source)

**Note**: This approach is still documented for other modules that may need it.

#### Stage 1-3: Build FreeSWITCH from Source
(Full FreeSWITCH build with all dependencies)

#### Stage 4-6: Build Module Dependencies
(Module-specific dependencies)

#### Stage 7-8: Validation and Runtime Image
(Similar to base image approach)

## Validation Points

Each Dockerfile includes multiple validation points:

### 1. Static Build-time Validation (Stage 6)
   - **Point 1**: Module file exists
   - **Point 2**: Check module dependencies with ldd
   - **Point 3**: Verify module-specific library linkage (e.g., libwebsockets)
   - **Point 4**: Check for missing dependencies

### 2. Runtime Validation During Build ⭐ **NEW** (Stage 7)
   - **Point 5**: Verify mod_audio_fork appears in FreeSWITCH logs
   - **Point 6**: Check for module loading errors (error/fail/cannot/unable)
   - **Point 7**: Check for critical FreeSWITCH errors (segfault/core dump/fatal)
   - **Full FreeSWITCH startup log** printed for debugging
   - **Build fails** if any validation point fails!

### 3. Container Runtime Validation Script (`/validate-module.sh`)
   - Available in final container (Stage 8)
   - Checks module file exists
   - Runs ldd to verify dependencies
   - Verifies libwebsockets linkage
   - Checks for missing dependencies
   - Can be run manually after container starts

## Differences from Main Production Dockerfile

The individual module Dockerfiles build **PRODUCTION-IDENTICAL FreeSWITCH** but skip heavy dependencies not needed by the specific module:

### What's IDENTICAL to Production ✅

✅ **All FreeSWITCH Patches Applied**
   - switch_core_media.c.patch
   - switch_rtp.c.patch
   - mod_avmd.c.patch
   - mod_httapi.c.patch

✅ **Production Custom Files Applied**
   - switch_event.c
   - mod_conference.h + conference_api.c
   - Note: configure.ac.extra/Makefile.am.extra skipped (designed for production with extra modules)

✅ **Production Configure Flags**
   - `--enable-tcmalloc=yes` (production performance)
   - `--with-lws=yes` (for mod_audio_fork)
   - `--with-extra=yes` (production features)
   - `--with-aws=no` (only difference - we don't build AWS SDK)

✅ **Production Configuration**
   - Codec preferences applied (PCMU,PCMA,OPUS,G722)
   - Same base packages as production
   - Same FreeSWITCH version (v1.10.11)

✅ **FreeSWITCH Core Dependencies**
   - spandsp (v0d2e6ac)
   - sofia-sip (v1.13.17)
   - libfvad

### What We Skip to Save Time ⚡

❌ **Heavy dependencies not needed by specific module:**
   - gRPC + grpc-googleapis (~1 hour build) - only needed by mod_google_transcribe
   - AWS SDK C++ + aws-c-common (~1-2 hours build) - only needed by mod_aws_transcribe
   - Azure Speech SDK - only needed by mod_azure_transcribe

❌ **Unrelated modules:**
   - Only builds 1 module instead of all 6 transcription modules
   - Faster module.conf with only essential modules

### Why This Approach?

1. **Production-identical testing**: Tests against EXACT production FreeSWITCH build
2. **Faster iteration**: 15-25 min vs 90-150 min builds (saves 2-3 hours)
3. **Same stability**: All production patches ensure production compatibility
4. **Clear dependencies**: See exactly what each module needs
5. **Fail-safe**: If it works here, it works in production

### When to Use Which Dockerfile?

**Individual Module Dockerfiles** (`dockerfiles/Dockerfile.mod_*`):
- Development and testing of a specific module
- Quick validation of module changes
- Debugging module-specific issues
- CI/CD module-level testing

**Main Production Dockerfile** (`Dockerfile`):
- Production deployments
- Full feature set needed
- All 6 modules together
- Custom patches and optimizations required

### Configuration Comparison

| Feature | Individual Module | Main Production |
|---------|------------------|-----------------|
| **FreeSWITCH Source** | Production (all patches applied) ✅ | Production (all patches applied) ✅ |
| **Configure Flags** | Production flags + module-specific | Production flags (all) |
| **Modules Built** | 1 module + essentials (~7 total) | All 6 transcription modules + full suite |
| **Custom Patches** | ALL applied ✅ | ALL applied ✅ |
| **Custom Files** | ALL applied ✅ | ALL applied ✅ |
| **Configuration** | Production codec prefs ✅ | Production codec prefs ✅ |
| **Heavy Dependencies** | Only module-specific (libwebsockets) | All (gRPC, AWS SDK, Azure SDK) |
| **Build Time** | 15-25 min (75% faster) | 90-150 min |
| **Image Size** | ~200-300 MB | ~500-800 MB |
| **Use Case** | Fast testing of production build | Full production deployment |
| **Compatibility** | 100% production-identical | Production build |

## Adding New Modules

To add a new module for individual testing:

1. **Create Dockerfile** (`Dockerfile.mod_<module_name>`):
```dockerfile
# Follow the pattern in Dockerfile.mod_audio_fork
# Adjust dependencies based on module requirements
```

2. **Create Build Script** (`docker-build-mod-<module_name>.sh`):
```bash
#!/bin/bash
# Copy and adapt docker-build-mod-audio-fork.sh
# Update module name and dependencies
```

3. **Define Dependencies**:
   - Read module's README.md
   - Identify required libraries
   - Add to base dependencies stage
   - Build from source if not in apt repositories

4. **Create FreeSWITCH Config**:
   - Minimal modules.conf with only required modules
   - Enable target module in modules.conf.xml
   - Configure any module-specific settings

5. **Add Validation**:
   - Verify module-specific dependencies
   - Check module loads successfully
   - Test basic module functionality if possible

## Directory Structure

```
dockerfiles/
├── README.md                           # This file
├── Dockerfile.mod_audio_fork          # mod_audio_fork individual testing
├── docker-build-mod-audio-fork.sh     # Build script for mod_audio_fork
├── Dockerfile.mod_audio_stream        # (future) mod_audio_stream testing
├── docker-build-mod-audio-stream.sh   # (future) Build script
└── ...                                # Additional modules
```

## Environment Variables

Build scripts read versions from the main `.env` file in the repository root:

- `CMAKE_VERSION` - CMake version to build
- `LIBWEBSOCKETS_VERSION` - libwebsockets version (for mod_audio_fork)
- `FREESWITCH_VERSION` - FreeSWITCH version
- `SPANDSP_VERSION` - spandsp library version
- `SOFIA_VERSION` - sofia-sip library version

Module-specific dependencies are added as needed.

## Comparison: Individual vs Full Build

| Aspect | Individual Module | Full Build |
|--------|------------------|------------|
| Build Time | 15-25 min | 90-150 min |
| Docker Image Size | ~200-300 MB | ~500-800 MB |
| Modules Built | 1 module | 6 modules |
| Dependencies | Minimal | All dependencies |
| Use Case | Development, debugging, testing | Production deployment |
| Startup Time | Fast | Slower |
| Configuration | Minimal | Complete |

## Testing Workflow

1. **Development**:
   ```bash
   # Make changes to module source
   vim modules/mod_audio_fork/mod_audio_fork.c

   # Quick rebuild and test
   ./dockerfiles/docker-build-mod-audio-fork.sh freeswitch-test:dev
   docker run --rm freeswitch-test:dev
   ```

2. **Debugging**:
   ```bash
   # Build with debug symbols (modify Dockerfile to add -g flag)
   ./dockerfiles/docker-build-mod-audio-fork.sh

   # Get shell and inspect
   docker run --rm -it freeswitch-mod-audio-fork:latest bash
   gdb /usr/local/freeswitch/bin/freeswitch
   ```

3. **CI/CD Integration**:
   ```bash
   # Quick validation in CI pipeline
   ./dockerfiles/docker-build-mod-audio-fork.sh ci-test:$BUILD_ID
   docker run --rm ci-test:$BUILD_ID /validate-module.sh
   ```

## Platform Support

### Linux (Native)
- Fast builds
- Full functionality
- Production recommended

### macOS (Intel)
- Native amd64 builds
- Good performance
- Development recommended

### macOS (Apple Silicon)
- Requires emulation (linux/amd64)
- Slower builds (2x time)
- Works via Rosetta
- GitHub Codespaces recommended for faster builds

### GitHub Codespaces
- Linux environment in cloud
- Fast builds
- Recommended for Apple Silicon users
- See main INSTALL.md for setup

## Troubleshooting

### Build Failures

**Missing dependencies**:
```bash
# Check Dockerfile base dependencies stage
# Ensure all required -dev packages are installed
```

**Module not found after build**:
```bash
# Check modules.conf in Dockerfile
# Ensure module is listed: applications/mod_audio_fork
```

**Runtime dependency errors**:
```bash
# Check final stage runtime dependencies
# Run ldd in builder stage to see what's needed
docker run --rm <image> ldd /usr/local/freeswitch/mod/mod_audio_fork.so
```

### Module Loading Failures

**Module loads but crashes**:
```bash
# Check FreeSWITCH logs
docker run --rm -it <image> freeswitch -nc -nf
# Look for error messages related to the module
```

**Missing configuration**:
```bash
# Verify modules.conf.xml exists and is correct
docker run --rm <image> cat /usr/local/freeswitch/conf/autoload_configs/modules.conf.xml
```

---

## Testing and Deployment

Once you've built the FreeSWITCH base image, you can test it in two ways:

### Option 1: Deploy to Docker Hub → Test on MacBook (Recommended)

**Best for**: Full testing with real audio, SIP clients, and production-like environment

```bash
# 1. Push to Docker Hub (in development environment)
./dockerfiles/push-to-dockerhub.sh your-username

# 2. Pull and run on MacBook
./dockerfiles/run-on-macbook.sh your-username
```

**Features**:
- ✅ Full audio testing with real SIP clients
- ✅ Support for all SIP transports (UDP/TCP/TLS)
- ✅ Test with Zoiper, Linphone, or any SIP client
- ✅ Production-like networking
- ✅ Test calling between extensions 1000 and 1001

See **DOCKER_HUB_DEPLOYMENT.md** for detailed step-by-step instructions.

### Option 2: Automated Validation Script

**Best for**: Quick health checks, CI/CD validation

```bash
# Run validation script
./dockerfiles/test-freeswitch-base.sh freeswitch-base:1.10.11
```

**Validates**:
- ✅ FreeSWITCH process running
- ✅ fs_cli connectivity (Event Socket)
- ✅ Module loading (100+ modules expected)
- ✅ SIP profiles active
- ✅ Extensions 1000 and 1001 configured
- ✅ System utilities available (ps, netstat, ping, etc.)

**Note**: This validates the build but doesn't test actual calling. For real SIP calling tests, use Option 1.

---

## Resources

- [FreeSWITCH Documentation](https://freeswitch.org/confluence/)
- [Installation Guide](FREESWITCH_INSTALL.md) - Complete dependency guide with all errors documented
- [Docker Hub Deployment](DOCKER_HUB_DEPLOYMENT.md) - Deploy and test on MacBook with SIP clients
- [Main Repository README](../README.md)
- [Individual Module READMEs](../modules/)
