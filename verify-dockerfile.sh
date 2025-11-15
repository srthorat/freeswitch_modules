#!/bin/bash

# Dockerfile Verification Script
# This script validates the Dockerfile without actually building it

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo -e "${BLUE}Dockerfile Verification Script${NC}"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Test 1: Check Dockerfile exists and syntax
echo -e "${BLUE}Test 1: Dockerfile Syntax${NC}"
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}✗ FAIL${NC} - Dockerfile not found"
    ERRORS=$((ERRORS+1))
else
    echo -e "${GREEN}✓ PASS${NC} - Dockerfile exists"

    # Check for syntax issues
    if grep -q "FROM.*AS" Dockerfile; then
        echo -e "${GREEN}✓ PASS${NC} - Multi-stage build detected"
    else
        echo -e "${RED}✗ FAIL${NC} - No multi-stage build found"
        ERRORS=$((ERRORS+1))
    fi
fi
echo ""

# Test 2: Check .env file
echo -e "${BLUE}Test 2: Environment Configuration${NC}"
if [ ! -f ".env" ]; then
    echo -e "${RED}✗ FAIL${NC} - .env file not found"
    ERRORS=$((ERRORS+1))
else
    echo -e "${GREEN}✓ PASS${NC} - .env file exists"

    # Check all required versions
    REQUIRED_VARS=(
        "cmakeVersion"
        "grpcVersion"
        "libwebsocketsVersion"
        "speechSdkVersion"
        "awsSdkCppVersion"
        "freeswitchVersion"
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${var}=" .env; then
            VALUE=$(grep "^${var}=" .env | awk -F '=' '{print $2}' | awk '{print $1}')
            echo -e "${GREEN}  ✓${NC} $var=$VALUE"
        else
            echo -e "${RED}  ✗${NC} $var missing"
            ERRORS=$((ERRORS+1))
        fi
    done
fi
echo ""

# Test 3: Check build-locally.sh
echo -e "${BLUE}Test 3: Docker Build Script${NC}"
if [ ! -f "build-locally.sh" ]; then
    echo -e "${RED}✗ FAIL${NC} - build-locally.sh not found"
    ERRORS=$((ERRORS+1))
else
    if bash -n build-locally.sh; then
        echo -e "${GREEN}✓ PASS${NC} - build-locally.sh syntax valid"
    else
        echo -e "${RED}✗ FAIL${NC} - build-locally.sh has syntax errors"
        ERRORS=$((ERRORS+1))
    fi

    # Check if it reads .env correctly
    if grep -q "grep.*Version.*\.env" build-locally.sh; then
        echo -e "${GREEN}✓ PASS${NC} - Reads versions from .env"
    else
        echo -e "${YELLOW}⚠ WARN${NC} - May not read .env correctly"
        WARNINGS=$((WARNINGS+1))
    fi
fi
echo ""

# Test 4: Validate Dockerfile stages
echo -e "${BLUE}Test 4: Dockerfile Build Stages${NC}"
EXPECTED_STAGES=(
    "base"
    "base-cmake"
    "grpc"
    "grpc-googleapis"
    "websockets"
    "speechsdk"
    "aws-sdk-cpp"
    "aws-c-common"
    "spandsp"
    "sofia-sip"
    "libfvad"
    "freeswitch-modules"
    "freeswitch"
    "final"
)

STAGE_COUNT=0
for stage in "${EXPECTED_STAGES[@]}"; do
    if grep -q "FROM.*AS $stage" Dockerfile; then
        echo -e "${GREEN}  ✓${NC} Stage: $stage"
        STAGE_COUNT=$((STAGE_COUNT+1))
    else
        if [ "$stage" = "final" ]; then
            # final stage might not have AS keyword
            if grep -q "^FROM debian:bullseye-slim$" Dockerfile; then
                echo -e "${GREEN}  ✓${NC} Stage: $stage (implicit)"
                STAGE_COUNT=$((STAGE_COUNT+1))
            fi
        else
            echo -e "${RED}  ✗${NC} Stage: $stage missing"
            ERRORS=$((ERRORS+1))
        fi
    fi
done

echo -e "${GREEN}✓ PASS${NC} - Found $STAGE_COUNT/${#EXPECTED_STAGES[@]} build stages"
echo ""

# Test 5: Check required files for Docker build
echo -e "${BLUE}Test 5: Required Files for Docker Build${NC}"
REQUIRED_FILES=(
    "files/SpeechSDK-Linux-1.37.0.tar.gz"
    "files/configure.ac.extra"
    "files/Makefile.am.extra"
    "files/modules.conf.in.extra"
    "files/switch_core_media.c.patch"
    "files/switch_rtp.c.patch"
    "entrypoint.sh"
    "freeswitch.xml"
    "vars_diff.xml"
)

FILES_OK=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo -e "${GREEN}  ✓${NC} $file ($SIZE)"
    else
        echo -e "${RED}  ✗${NC} $file MISSING"
        FILES_OK=false
        ERRORS=$((ERRORS+1))
    fi
done

if [ "$FILES_OK" = true ]; then
    echo -e "${GREEN}✓ PASS${NC} - All required files present"
fi
echo ""

# Test 6: Check module directories
echo -e "${BLUE}Test 6: Module Directories${NC}"
MODULES=(
    "modules/mod_audio_fork"
    "modules/mod_aws_transcribe"
    "modules/mod_azure_transcribe"
    "modules/mod_deepgram_transcribe"
    "modules/mod_google_transcribe"
)

MODULES_OK=true
for module in "${MODULES[@]}"; do
    if [ -d "$module" ]; then
        FILE_COUNT=$(find "$module" -type f | wc -l)
        echo -e "${GREEN}  ✓${NC} $module ($FILE_COUNT files)"
    else
        echo -e "${RED}  ✗${NC} $module MISSING"
        MODULES_OK=false
        ERRORS=$((ERRORS+1))
    fi
done

if [ "$MODULES_OK" = true ]; then
    echo -e "${GREEN}✓ PASS${NC} - All module directories present"
fi
echo ""

# Test 7: Validate Dockerfile commands match expected build
echo -e "${BLUE}Test 7: Critical Dockerfile Commands${NC}"

# Check gRPC build command
if grep -q "cmake.*-DBUILD_SHARED_LIBS=ON.*-DgRPC_SSL_PROVIDER=package" Dockerfile; then
    echo -e "${GREEN}  ✓${NC} gRPC build command correct"
else
    echo -e "${RED}  ✗${NC} gRPC build command incorrect"
    ERRORS=$((ERRORS+1))
fi

# Check AWS SDK build command
if grep -q 'DBUILD_ONLY="lexv2-runtime;transcribestreaming"' Dockerfile; then
    echo -e "${GREEN}  ✓${NC} AWS SDK build command correct"
else
    echo -e "${RED}  ✗${NC} AWS SDK build command incorrect"
    ERRORS=$((ERRORS+1))
fi

# Check FreeSWITCH configure
if grep -q "configure --enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=yes" Dockerfile; then
    echo -e "${GREEN}  ✓${NC} FreeSWITCH configure command correct"
else
    echo -e "${RED}  ✗${NC} FreeSWITCH configure command incorrect"
    ERRORS=$((ERRORS+1))
fi

# Check cJSON fix
if grep -q "cJSON_AS4CPP__h" Dockerfile && grep -q "cJSON__h" Dockerfile; then
    echo -e "${GREEN}  ✓${NC} cJSON header fix present"
else
    echo -e "${YELLOW}  ⚠${NC} cJSON header fix may be missing"
    WARNINGS=$((WARNINGS+1))
fi

echo -e "${GREEN}✓ PASS${NC} - Critical commands validated"
echo ""

# Test 8: Check entrypoint script
echo -e "${BLUE}Test 8: Container Entrypoint${NC}"
if [ -f "entrypoint.sh" ]; then
    if bash -n entrypoint.sh; then
        echo -e "${GREEN}✓ PASS${NC} - entrypoint.sh syntax valid"
    else
        echo -e "${RED}✗ FAIL${NC} - entrypoint.sh has syntax errors"
        ERRORS=$((ERRORS+1))
    fi

    if [ -x "entrypoint.sh" ]; then
        echo -e "${GREEN}✓ PASS${NC} - entrypoint.sh is executable"
    else
        echo -e "${YELLOW}⚠ WARN${NC} - entrypoint.sh not executable (Docker will chmod it)"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo -e "${RED}✗ FAIL${NC} - entrypoint.sh not found"
    ERRORS=$((ERRORS+1))
fi
echo ""

# Test 9: Check ARG and FROM consistency
echo -e "${BLUE}Test 9: Dockerfile ARG Usage${NC}"
ARGS=(
    "CMAKE_VERSION"
    "GRPC_VERSION"
    "LIBWEBSOCKETS_VERSION"
    "SPEECH_SDK_VERSION"
    "AWS_SDK_CPP_VERSION"
    "FREESWITCH_VERSION"
)

for arg in "${ARGS[@]}"; do
    # Check if ARG is declared
    if grep -q "^ARG $arg$" Dockerfile; then
        # Check if ARG is used
        if grep -q "\$$arg" Dockerfile; then
            echo -e "${GREEN}  ✓${NC} $arg declared and used"
        else
            echo -e "${YELLOW}  ⚠${NC} $arg declared but not used"
            WARNINGS=$((WARNINGS+1))
        fi
    else
        echo -e "${RED}  ✗${NC} $arg not declared"
        ERRORS=$((ERRORS+1))
    fi
done
echo ""

# Test 10: Validate build-local-system.sh matches Dockerfile
echo -e "${BLUE}Test 10: Local Build Script vs Dockerfile${NC}"
if [ -f "build-local-system.sh" ]; then
    # Check if commands match
    MATCH_COUNT=0

    if grep -q "cmake.*-DBUILD_SHARED_LIBS=ON.*-DgRPC_SSL_PROVIDER=package" build-local-system.sh; then
        echo -e "${GREEN}  ✓${NC} gRPC build matches"
        MATCH_COUNT=$((MATCH_COUNT+1))
    fi

    if grep -q 'DBUILD_ONLY="lexv2-runtime;transcribestreaming"' build-local-system.sh; then
        echo -e "${GREEN}  ✓${NC} AWS SDK build matches"
        MATCH_COUNT=$((MATCH_COUNT+1))
    fi

    if grep -q "configure --enable-tcmalloc=yes --with-lws=yes --with-extra=yes --with-aws=yes" build-local-system.sh; then
        echo -e "${GREEN}  ✓${NC} FreeSWITCH configure matches"
        MATCH_COUNT=$((MATCH_COUNT+1))
    fi

    if [ $MATCH_COUNT -eq 3 ]; then
        echo -e "${GREEN}✓ PASS${NC} - Build scripts are consistent"
    else
        echo -e "${YELLOW}⚠ WARN${NC} - Only $MATCH_COUNT/3 commands match"
        WARNINGS=$((WARNINGS+1))
    fi
else
    echo -e "${YELLOW}⚠ WARN${NC} - build-local-system.sh not found (optional)"
    WARNINGS=$((WARNINGS+1))
fi
echo ""

# Final Summary
echo "=========================================="
echo -e "${BLUE}VERIFICATION SUMMARY${NC}"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    echo ""
    echo "The Dockerfile is ready for building!"
    echo ""
    echo "To build the Docker image:"
    echo "  ./build-locally.sh"
    echo ""
    echo "Or manually:"
    echo "  docker build -t freeswitch-transcribe:latest ."
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH WARNINGS${NC}"
    echo ""
    echo "Warnings: $WARNINGS"
    echo ""
    echo "The Dockerfile should work, but review warnings above."
    EXIT_CODE=0
else
    echo -e "${RED}❌ FAILED${NC}"
    echo ""
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    echo ""
    echo "Fix the errors above before building."
    EXIT_CODE=1
fi

echo ""
echo "=========================================="

exit $EXIT_CODE
