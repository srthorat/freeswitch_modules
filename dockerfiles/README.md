# Individual Module Testing with Docker

This directory contains Dockerfiles for testing individual FreeSWITCH modules in isolation. This approach provides several benefits:

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
**Dependencies**:
- libwebsockets (for WebSocket connectivity)
- FreeSWITCH core (minimal build)

**Build Time**:
- Intel/AMD64: 15-25 minutes
- Apple Silicon: 30-45 minutes (with emulation)

**Usage**:
```bash
# Build the image
./dockerfiles/docker-build-mod-audio-fork.sh

# Run validation (default)
docker run --rm freeswitch-mod-audio-fork:latest

# Interactive FreeSWITCH
docker run --rm -it freeswitch-mod-audio-fork:latest freeswitch -nc -nf

# Get a shell
docker run --rm -it freeswitch-mod-audio-fork:latest bash
```

**Features**:
- Minimal FreeSWITCH configuration with only mod_audio_fork loaded
- Automatic module validation on startup
- Detailed logging at each build stage
- Dependency verification with ldd
- Runtime validation script at `/validate-module.sh`

## Build Process

Each Dockerfile follows this pattern:

### Stage 1: Base Dependencies
Install system packages required for building

### Stage 2: Build CMake
Build CMake from source (required for some dependencies)

### Stage 3: Build FreeSWITCH Core Dependencies
Build FreeSWITCH dependencies (same as production):
- spandsp (FreeSWITCH dependency)
- sofia-sip (FreeSWITCH dependency)
- libfvad (FreeSWITCH dependency)

### Stage 4: Build Module-Specific Dependencies
Build only the dependencies needed by the specific module:
- For mod_audio_fork: libwebsockets v4.3.3
- Skips: gRPC, AWS SDK, Azure SDK (not needed by mod_audio_fork)

### Stage 5: Build FULL Production FreeSWITCH from Source
**This is a COMPLETE production build from source, NOT minimal!**
- Clones FreeSWITCH v1.10.11 source code
- Applies ALL production patches (switch_core_media.c, switch_rtp.c, mod_avmd.c, mod_httapi.c)
- Copies ALL custom files (switch_event.c, mod_conference.h, configure.ac.extra, Makefile.am.extra, etc.)
- Runs `./bootstrap.sh -j` (same as production)
- Uses production configure flags: `--enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=no`
- Compiles FreeSWITCH with `make -j $(nproc)` (same as production)
- Applies production codec preferences (PCMU,PCMA,OPUS,G722)
- Only difference: minimal modules.conf (just mod_audio_fork + essentials, not all 6 modules)

### Stage 6: Static Validation
Validate module compilation and dependencies:
- Check module file exists
- Verify dependencies with ldd
- Check for missing libraries
- Validate module-specific linkage

### Stage 7: Runtime Validation ⭐ **NEW**
**Actually runs FreeSWITCH to verify module loads successfully:**
- Creates minimal FreeSWITCH configuration
- Starts FreeSWITCH in background
- Waits for initialization (15 seconds)
- Checks logs for mod_audio_fork loading
- Verifies no loading errors
- Confirms successful module load
- Checks for critical errors (segfaults, etc.)
- Stops FreeSWITCH cleanly
- **Build fails if module doesn't load!**

This stage guarantees that the built image actually works, not just that files exist.

### Stage 8: Runtime Image
Create minimal runtime image with:
- Only runtime dependencies
- FreeSWITCH binaries from **validated build**
- Module file (proven to load successfully)
- Validation scripts
- FreeSWITCH configuration

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

## Resources

- [FreeSWITCH Documentation](https://freeswitch.org/confluence/)
- [Main Repository README](../README.md)
- [Installation Guide](../INSTALL.md)
- [Individual Module READMEs](../modules/)
