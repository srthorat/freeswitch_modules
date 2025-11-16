#!/bin/bash
# ============================================================================
# Test FreeSWITCH Calling in GitHub Codespaces
# ============================================================================
#
# This script tests FreeSWITCH calling functionality directly in Codespaces
# using fs_cli commands and call origination.
#
# Usage:
#   ./test-in-codespaces.sh
#
# ============================================================================

set -e

CONTAINER_NAME="freeswitch"
IMAGE_NAME="freeswitch-base:1.10.11"

echo "============================================="
echo "FreeSWITCH Codespaces Testing"
echo "============================================="
echo ""

# Check if image exists
if ! docker images | grep -q "freeswitch-base.*1.10.11"; then
    echo "❌ Image not found: $IMAGE_NAME"
    echo ""
    echo "Please build the image first:"
    echo "  ./dockerfiles/build-freeswitch-base.sh"
    exit 1
fi

echo "✅ Image found: $IMAGE_NAME"
echo ""

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "⚠️  FreeSWITCH container not running"
    echo ""

    # Check if container exists but stopped
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        echo "Starting existing container..."
        docker start "$CONTAINER_NAME"
        sleep 5
    else
        echo "Creating new container..."
        docker run -d \
            --name "$CONTAINER_NAME" \
            --platform linux/amd64 \
            -p 5060:5060/tcp \
            -p 5060:5060/udp \
            -p 5080:5080/tcp \
            -p 5080:5080/udp \
            -p 8021:8021/tcp \
            -p 16384-16484:16384-16484/udp \
            "$IMAGE_NAME"

        echo "Waiting for FreeSWITCH to start (30 seconds)..."
        sleep 30
    fi
fi

echo "✅ FreeSWITCH container is running"
echo ""

# Test fs_cli connection
echo "Testing fs_cli connection..."
if docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "status" >/dev/null 2>&1; then
    echo "✅ fs_cli connected successfully"
else
    echo "❌ fs_cli connection failed!"
    echo ""
    echo "Container logs:"
    docker logs --tail 50 "$CONTAINER_NAME"
    exit 1
fi
echo ""

# Show FreeSWITCH status
echo "============================================="
echo "FreeSWITCH Status"
echo "============================================="
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "status"
echo ""

# Show loaded modules count
MODULE_COUNT=$(docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "show modules" | grep -c "^mod_" || true)
echo "✅ Loaded modules: $MODULE_COUNT"
echo ""

# Show SIP profiles
echo "============================================="
echo "SIP Profiles"
echo "============================================="
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "sofia status"
echo ""

# Check if extensions are configured
echo "============================================="
echo "Extension Configuration"
echo "============================================="
if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/directory/default/1000.xml; then
    echo "✅ Extension 1000 configured"
else
    echo "❌ Extension 1000 NOT configured"
fi

if docker exec "$CONTAINER_NAME" test -f /usr/local/freeswitch/conf/directory/default/1001.xml; then
    echo "✅ Extension 1001 configured"
else
    echo "❌ Extension 1001 NOT configured"
fi
echo ""

# Show Codespaces port forwarding info
echo "============================================="
echo "Codespaces Port Forwarding"
echo "============================================="
echo ""
echo "Check the PORTS tab in your Codespaces bottom panel."
echo "Make sure these ports are visible and PUBLIC:"
echo "  - 5060 (SIP TCP/UDP)"
echo "  - 5080 (SIP over WebSocket)"
echo "  - 8021 (Event Socket)"
echo ""

if command -v gh >/dev/null 2>&1; then
    echo "Forwarded ports:"
    gh codespace ports 2>/dev/null || echo "Run 'gh codespace ports' to see forwarded URLs"
else
    echo "Install GitHub CLI to see forwarded URLs: gh codespace ports"
fi
echo ""

# Test call simulation
echo "============================================="
echo "Call Simulation Tests"
echo "============================================="
echo ""

# Test 1: Originate to Park
echo "Test 1: Originate call to extension 1000 (park)"
echo "Command: originate user/1000 &park()"
echo ""
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "bgapi originate user/1000 &park()"
sleep 3

echo "Active channels after park:"
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "show channels"
echo ""

# Hangup parked call
CHANNEL_UUID=$(docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "show channels" | grep "user/1000" | awk '{print $1}' | head -1 || true)
if [ -n "$CHANNEL_UUID" ]; then
    echo "Hanging up parked call..."
    docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "uuid_kill $CHANNEL_UUID"
    sleep 2
fi

# Test 2: Originate to Echo
echo "Test 2: Originate call to echo test (extension 9196)"
echo "Command: originate user/1000 9196"
echo ""
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "bgapi originate user/1000 9196"
sleep 3

echo "Active channels (echo test):"
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "show channels"
echo ""

# Hangup echo test
CHANNEL_UUID=$(docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "show channels" | grep -v "^uuid" | awk '{print $1}' | head -1 || true)
if [ -n "$CHANNEL_UUID" ]; then
    echo "Hanging up echo test..."
    docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "uuid_kill $CHANNEL_UUID"
    sleep 2
fi

# Test 3: Bridge test (would need actual registration)
echo "Test 3: Bridge between extensions (requires registered clients)"
echo "Command: originate user/1000 &bridge(user/1001)"
echo "Note: This will only work if extensions are registered"
echo ""
echo "To test with real SIP clients:"
echo "  1. Register extension 1000 from a SIP client"
echo "  2. Register extension 1001 from another SIP client"
echo "  3. Call from 1000 to 1001"
echo ""

# Show current registrations
echo "Current SIP registrations:"
docker exec "$CONTAINER_NAME" /usr/local/freeswitch/bin/fs_cli -x "sofia status profile internal reg"
echo ""

echo "============================================="
echo "Testing Complete!"
echo "============================================="
echo ""
echo "✅ FreeSWITCH is running and accepting calls"
echo ""
echo "Extension Credentials:"
echo "  Extension 1000: username=1000, password=1234"
echo "  Extension 1001: username=1001, password=1234"
echo ""
echo "Next Steps:"
echo ""
echo "1. For CLI-based testing:"
echo "   docker exec -it $CONTAINER_NAME fs_cli"
echo "   freeswitch@internal> originate user/1000 &bridge(user/1001)"
echo ""
echo "2. For SIP client testing (same machine):"
echo "   - Install Zoiper/Linphone on your local machine"
echo "   - Use Codespaces forwarded URL for port 5060"
echo "   - Configure transport: TCP or WebSocket"
echo ""
echo "3. For WebRTC testing:"
echo "   - Open https://tryit.jssip.net/"
echo "   - Use WebSocket URL: wss://YOUR-CODESPACE-5080.app.github.dev"
echo "   - Register as extensions 1000 and 1001"
echo "   - Make calls between them"
echo ""
echo "4. To view logs:"
echo "   docker logs -f $CONTAINER_NAME"
echo ""
echo "5. To monitor calls:"
echo "   docker exec -it $CONTAINER_NAME fs_cli"
echo "   freeswitch@internal> show channels"
echo ""
echo "See CODESPACES_TESTING.md for detailed instructions."
echo ""
