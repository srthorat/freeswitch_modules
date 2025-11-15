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

### Stage 3: Build Module Dependencies
Build module-specific dependencies (e.g., libwebsockets for mod_audio_fork)

### Stage 4: Build FreeSWITCH Core
Build FreeSWITCH with minimal modules enabled

### Stage 5: Build Target Module
Build the specific module being tested

### Stage 6: Validation
Validate module compilation and dependencies:
- Check module file exists
- Verify dependencies with ldd
- Check for missing libraries
- Validate module-specific linkage

### Stage 7: Runtime Image
Create minimal runtime image with:
- Only runtime dependencies
- FreeSWITCH binaries
- Module file
- Validation scripts
- FreeSWITCH configuration

## Validation Points

Each Dockerfile includes multiple validation points:

1. **Build-time Validation**:
   - Module file exists
   - Dependencies resolved
   - No missing libraries
   - Module-specific libraries linked correctly

2. **Runtime Validation**:
   - Module can be loaded by FreeSWITCH
   - No runtime dependency errors
   - Module appears in FreeSWITCH logs

3. **Validation Script** (`/validate-module.sh`):
   - Checks module file
   - Runs ldd to verify dependencies
   - Starts FreeSWITCH to test module loading
   - Checks FreeSWITCH logs for successful load

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
