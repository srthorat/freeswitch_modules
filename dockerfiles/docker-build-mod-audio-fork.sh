#!/bin/bash
# ============================================================================
# Docker Build Script for mod_audio_fork Individual Testing
# ============================================================================
# This script builds a Docker image containing FreeSWITCH with ONLY the
# mod_audio_fork module for faster validation and individual testing.
#
# Usage:
#   ./dockerfiles/docker-build-mod-audio-fork.sh [IMAGE_NAME]
#
# Example:
#   ./dockerfiles/docker-build-mod-audio-fork.sh freeswitch-mod-audio-fork:test
#   ./dockerfiles/docker-build-mod-audio-fork.sh  # Uses default name
# ============================================================================

set -e

# Default image name
IMAGE_NAME=${1:-freeswitch-mod-audio-fork:latest}

echo "============================================="
echo "mod_audio_fork Docker Build Script"
echo "============================================="
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ ERROR: .env file not found in current directory"
    echo "Please run this script from the repository root"
    exit 1
fi

echo "✅ Found .env file"
echo ""

# Detect platform
PLATFORM="linux/amd64"
if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
    echo "🔍 Detected ARM64 architecture (Apple Silicon or ARM Linux)"
    echo "📋 Note: Building for linux/amd64 with emulation"
    echo "⚠️  This will be slower on Apple Silicon Macs"
    echo ""
fi

# Read versions from .env
echo "📖 Reading build versions from .env..."
CMAKE_VERSION=$(grep cmakeVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
LIBWEBSOCKETS_VERSION=$(grep libwebsocketsVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SPANDSP_VERSION=$(grep spandspVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
SOFIA_VERSION=$(grep sofiaVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')
FREESWITCH_VERSION=$(grep freeswitchVersion .env | awk -F '=' '{print $2}' | awk '{print $1}')

# Validate versions
if [ -z "$CMAKE_VERSION" ] || [ -z "$LIBWEBSOCKETS_VERSION" ] || [ -z "$FREESWITCH_VERSION" ]; then
    echo "❌ ERROR: Failed to read required versions from .env"
    echo "   CMAKE_VERSION: $CMAKE_VERSION"
    echo "   LIBWEBSOCKETS_VERSION: $LIBWEBSOCKETS_VERSION"
    echo "   FREESWITCH_VERSION: $FREESWITCH_VERSION"
    exit 1
fi

echo "✅ Build configuration:"
echo "   CMake Version:         $CMAKE_VERSION"
echo "   libwebsockets Version: $LIBWEBSOCKETS_VERSION"
echo "   spandsp Version:       $SPANDSP_VERSION"
echo "   sofia-sip Version:     $SOFIA_VERSION"
echo "   FreeSWITCH Version:    $FREESWITCH_VERSION"
echo "   Target Image:          $IMAGE_NAME"
echo "   Platform:              $PLATFORM"
echo ""

# Check if mod_audio_fork module exists
if [ ! -d "modules/mod_audio_fork" ]; then
    echo "❌ ERROR: modules/mod_audio_fork directory not found"
    echo "Please ensure you're running from the repository root"
    exit 1
fi

echo "✅ Found mod_audio_fork module"
echo ""

# Confirm build
echo "============================================="
echo "Ready to build Docker image for mod_audio_fork"
echo "============================================="
echo ""
echo "This will:"
echo "  1. Build CMake $CMAKE_VERSION"
echo "  2. Build libwebsockets $LIBWEBSOCKETS_VERSION"
echo "  3. Build FreeSWITCH $FREESWITCH_VERSION (minimal)"
echo "  4. Build mod_audio_fork module"
echo "  5. Validate module dependencies"
echo "  6. Create runtime image with validation script"
echo ""
echo "Estimated build time:"
echo "  - Intel/AMD64: 15-25 minutes"
echo "  - Apple Silicon (with emulation): 30-45 minutes"
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Build Docker image with all build arguments
echo "============================================="
echo "Starting Docker build..."
echo "============================================="
echo ""

# Record start time
START_TIME=$(date +%s)

docker build \
    --platform "$PLATFORM" \
    --build-arg CMAKE_VERSION="$CMAKE_VERSION" \
    --build-arg LIBWEBSOCKETS_VERSION="$LIBWEBSOCKETS_VERSION" \
    --build-arg SPANDSP_VERSION="$SPANDSP_VERSION" \
    --build-arg SOFIA_VERSION="$SOFIA_VERSION" \
    --build-arg FREESWITCH_VERSION="$FREESWITCH_VERSION" \
    -f dockerfiles/Dockerfile.mod_audio_fork \
    -t "$IMAGE_NAME" \
    .

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "============================================="
echo "✅ Build completed successfully!"
echo "============================================="
echo ""
echo "Build time: ${MINUTES}m ${SECONDS}s"
echo "Image name: $IMAGE_NAME"
echo ""
echo "============================================="
echo "Next Steps:"
echo "============================================="
echo ""
echo "1. Run validation (default):"
echo "   docker run --rm $IMAGE_NAME"
echo ""
echo "2. Run validation with verbose output:"
echo "   docker run --rm $IMAGE_NAME /validate-module.sh"
echo ""
echo "3. Start FreeSWITCH interactively:"
echo "   docker run --rm -it $IMAGE_NAME freeswitch -nc -nf"
echo ""
echo "4. Get a shell in the container:"
echo "   docker run --rm -it $IMAGE_NAME bash"
echo ""
echo "5. Check module file directly:"
echo "   docker run --rm $IMAGE_NAME ls -lh /usr/local/freeswitch/mod/mod_audio_fork.so"
echo ""
echo "6. Check module dependencies:"
echo "   docker run --rm $IMAGE_NAME ldd /usr/local/freeswitch/mod/mod_audio_fork.so"
echo ""
echo "============================================="
echo "Module Testing Commands:"
echo "============================================="
echo ""
echo "To test mod_audio_fork functionality, you'll need:"
echo "  - A websocket server endpoint (ws:// or wss://)"
echo "  - An active FreeSWITCH call session"
echo ""
echo "Example API command (from FreeSWITCH console):"
echo "  uuid_audio_fork <uuid> start ws://your-server:port mono 8k"
echo ""
echo "See modules/mod_audio_fork/README.md for full API documentation"
echo ""
echo "============================================="
