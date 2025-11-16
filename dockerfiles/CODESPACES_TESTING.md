# Testing FreeSWITCH Directly in GitHub Codespaces

This guide shows how to test FreeSWITCH calling features directly in your GitHub Codespaces environment using port forwarding - no Docker Hub needed!

---

## Overview

GitHub Codespaces automatically forwards ports from the container to your local machine via HTTPS tunnels. This means you can:
- Build and run FreeSWITCH in Codespaces
- Access it from SIP clients on your local machine
- Test calling between extensions immediately

**Advantages**:
- ✅ No Docker Hub push/pull needed
- ✅ Instant testing during development
- ✅ No need to switch machines
- ✅ Easy debugging with logs and fs_cli

**Limitations**:
- ⚠️ UDP port forwarding not supported (use TCP or WebSocket)
- ⚠️ RTP media requires special NAT configuration
- ⚠️ Best for basic SIP testing, not production

---

## Quick Start

### Step 1: Build the FreeSWITCH Image

```bash
# In your Codespaces terminal
cd /workspaces/freeswitch_modules

# Build the image (30-45 minutes on Codespaces)
./dockerfiles/build-freeswitch-base.sh freeswitch-base:1.10.11
```

### Step 2: Run FreeSWITCH Container

```bash
# Run with all required ports
docker run -d \
    --name freeswitch \
    --platform linux/amd64 \
    -p 5060:5060/tcp \
    -p 5060:5060/udp \
    -p 5080:5080/tcp \
    -p 8021:8021/tcp \
    -p 16384-16484:16384-16484/udp \
    freeswitch-base:1.10.11
```

### Step 3: Check Port Forwarding

1. **In Codespaces**, click the "PORTS" tab (bottom panel)
2. You should see ports automatically forwarded:
   - `5060` - SIP (TCP)
   - `5080` - SIP over WebSocket
   - `8021` - Event Socket
   - `16384-16484` - RTP (may not forward automatically)

3. **Make ports public** (important for SIP clients):
   - Right-click on port 5060 → "Port Visibility" → "Public"
   - Right-click on port 5080 → "Port Visibility" → "Public"
   - Right-click on port 8021 → "Port Visibility" → "Public"

### Step 4: Get Forwarded Port URLs

```bash
# In Codespaces terminal, get the forwarded URLs
gh codespace ports
```

Or click the "PORTS" tab and note the "Forwarded Address" for each port.

Example forwarded addresses:
- Port 5060: `https://username-repo-12345-5060.app.github.dev`
- Port 5080: `https://username-repo-12345-5080.app.github.dev`
- Port 8021: `https://username-repo-12345-8021.app.github.dev`

---

## Testing Options

You have three options for testing, ranked from easiest to most complex:

### Option A: Use fs_cli in Codespaces (Easiest)

Test calling using the built-in softphone features:

```bash
# Access fs_cli
docker exec -it freeswitch fs_cli

# Originate a call from 1000 to 1001
freeswitch@internal> originate user/1000 &bridge(user/1001)

# This will ring extension 1000, when answered, it bridges to 1001
```

**Pros**: No SIP client needed, instant testing
**Cons**: Can't test real audio, only call flow

---

### Option B: SIP Client via TCP (Recommended)

Use a SIP client on your local machine with TCP transport.

#### Configure SIP Client (Zoiper/Linphone)

**IMPORTANT**: Codespaces port forwarding is HTTPS-based, which makes raw SIP tricky. The best approach is to use **SIP over WebSocket** (see Option C).

However, for TCP-based SIP clients, you need to:

1. **Extract hostname from Codespaces URL**:
   - If port 5060 forwards to: `https://username-repo-12345-5060.app.github.dev`
   - Use hostname: `username-repo-12345-5060.app.github.dev`
   - Port: `443` (HTTPS)
   - Transport: `TLS` or `TCP`

2. **Configure Extension 1000**:
   ```
   Username: 1000
   Password: 1234
   Domain: username-repo-12345-5060.app.github.dev
   Port: 443
   Transport: TLS
   ```

**Challenge**: Most Codespaces port forwarding uses HTTPS, which won't work directly with standard SIP. You need WebSocket (Option C).

---

### Option C: WebRTC via SIP over WebSocket (Best for Codespaces)

This is the **recommended approach** for Codespaces testing.

#### Use a WebRTC-enabled SIP Client

**Recommended Clients**:
1. **JsSIP Demo** (Browser-based, easiest)
2. **SIPjs** (Browser-based)
3. **Linphone Web** (Browser-based)
4. **Zoiper** (if supports WebSocket)

#### Setup with JsSIP Demo

1. **Open JsSIP Demo**: https://tryit.jssip.net/

2. **Configure Settings**:
   ```
   WebSocket URL: wss://YOUR-CODESPACE-URL-5080.app.github.dev
   SIP URI: sip:1000@YOUR-CODESPACE-URL
   Password: 1234
   Display Name: Extension 1000
   ```

3. **Click "Connect"** - should show "Registered"

4. **Open second browser window** for extension 1001

5. **Make a call**: From 1000, call `1001@YOUR-CODESPACE-URL`

**Note**: FreeSWITCH vanilla config may need WebSocket configuration enabled.

---

### Option D: Local SIP Client with SSH Tunnel (Advanced)

Forward UDP ports through SSH tunnel:

```bash
# On your local machine
gh codespace ports forward 5060:5060 --codespace YOUR_CODESPACE_NAME

# Configure SIP client to use localhost:5060
```

---

## Configure FreeSWITCH for Codespaces NAT

FreeSWITCH needs to know it's behind NAT (Codespaces port forwarding).

### Step 1: Get Codespaces Public URL

```bash
# In Codespaces terminal
echo $CODESPACE_NAME
gh codespace view
```

### Step 2: Update FreeSWITCH NAT Settings

```bash
# Edit vars.xml
docker exec -it freeswitch vim /usr/local/freeswitch/conf/vars.xml
```

Find and update these variables:

```xml
<!-- External IP (use your Codespace's public URL domain) -->
<X-PRE-PROCESS cmd="set" data="external_sip_ip=YOUR-CODESPACE-5060.app.github.dev"/>
<X-PRE-PROCESS cmd="set" data="external_rtp_ip=YOUR-CODESPACE-5060.app.github.dev"/>

<!-- Local IP detection -->
<X-PRE-PROCESS cmd="set" data="local_ip_v4=auto"/>
```

### Step 3: Update SIP Profile for External Access

```bash
# Edit internal SIP profile
docker exec -it freeswitch vim /usr/local/freeswitch/conf/sip_profiles/internal.xml
```

Add these settings inside `<profile>` tag:

```xml
<param name="ext-rtp-ip" value="$${external_rtp_ip}"/>
<param name="ext-sip-ip" value="$${external_sip_ip}"/>
<param name="rtp-ip" value="$${local_ip_v4}"/>
<param name="sip-ip" value="$${local_ip_v4}"/>
```

### Step 4: Reload Configuration

```bash
docker exec -it freeswitch fs_cli -x "reloadxml"
docker exec -it freeswitch fs_cli -x "sofia profile internal restart"
```

---

## Testing Script for Codespaces

Save this as `test-in-codespaces.sh`:

```bash
#!/bin/bash
# Test FreeSWITCH calling in Codespaces

set -e

echo "============================================="
echo "FreeSWITCH Codespaces Testing"
echo "============================================="
echo ""

# Check if container is running
if ! docker ps | grep -q freeswitch; then
    echo "❌ FreeSWITCH container not running!"
    echo ""
    echo "Start it with:"
    echo "  docker run -d --name freeswitch -p 5060:5060/tcp -p 5080:5080/tcp -p 8021:8021/tcp freeswitch-base:1.10.11"
    exit 1
fi

echo "✅ FreeSWITCH container is running"
echo ""

# Test fs_cli connection
echo "Testing fs_cli connection..."
if docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "status" >/dev/null 2>&1; then
    echo "✅ fs_cli connected"
else
    echo "❌ fs_cli connection failed"
    exit 1
fi
echo ""

# Show FreeSWITCH status
echo "============================================="
echo "FreeSWITCH Status"
echo "============================================="
docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "status"
echo ""

# Show SIP profiles
echo "============================================="
echo "SIP Profiles"
echo "============================================="
docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "sofia status"
echo ""

# Show port forwarding info
echo "============================================="
echo "Codespaces Port Forwarding"
echo "============================================="
echo ""
echo "Check forwarded ports in the PORTS tab below."
echo "Make sure ports 5060, 5080, and 8021 are PUBLIC."
echo ""
echo "Get forwarded URLs with:"
echo "  gh codespace ports"
echo ""

# Test call simulation
echo "============================================="
echo "Test Call Simulation"
echo "============================================="
echo ""
echo "Simulating a call from extension 1000 to 1001..."
echo ""

# Originate a test call
docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "bgapi originate user/1000 &park()"

sleep 2

# Show active channels
echo "Active channels:"
docker exec freeswitch /usr/local/freeswitch/bin/fs_cli -x "show channels"
echo ""

echo "============================================="
echo "Testing Complete!"
echo "============================================="
echo ""
echo "Extension Credentials:"
echo "  Extension 1000: username=1000, password=1234"
echo "  Extension 1001: username=1001, password=1234"
echo ""
echo "For WebRTC testing:"
echo "  1. Open https://tryit.jssip.net/ in two browser windows"
echo "  2. Configure WebSocket URL: wss://YOUR-CODESPACE-5080.app.github.dev"
echo "  3. Register as 1000 and 1001"
echo "  4. Call between extensions"
echo ""
echo "For fs_cli access:"
echo "  docker exec -it freeswitch fs_cli"
echo ""
```

---

## Simple Test: Call Between Extensions in fs_cli

The easiest way to verify calling works:

### Test 1: Originate Call to Park

```bash
docker exec -it freeswitch fs_cli

# Originate call from 1000, park it
freeswitch@internal> originate user/1000 &park()

# Check if channel exists
freeswitch@internal> show channels
```

### Test 2: Bridge Two Extensions

```bash
# Originate from 1000, bridge to 1001
freeswitch@internal> originate user/1000 &bridge(user/1001)
```

This will:
1. Ring extension 1000
2. When answered, ring extension 1001
3. When both answer, bridge them together

### Test 3: Playback Audio

```bash
# Call 1000 and play music
freeswitch@internal> originate user/1000 &playback(/usr/local/freeswitch/sounds/en/us/callie/misc/8000/misc-freeswitch_is_state_of_the_art.wav)
```

---

## Monitoring and Debugging

### View Logs

```bash
# Follow FreeSWITCH logs
docker logs -f freeswitch

# View log file in container
docker exec -it freeswitch tail -f /usr/local/freeswitch/log/freeswitch.log
```

### Check SIP Registrations

```bash
docker exec -it freeswitch fs_cli -x "sofia status profile internal reg"
```

Should show registered users (when SIP clients connect).

### Debug SIP Messages

```bash
docker exec -it freeswitch fs_cli

# Enable SIP tracing
freeswitch@internal> sofia global siptrace on

# Watch SIP messages in real-time
freeswitch@internal> console loglevel debug
```

### Test Network Connectivity

```bash
# From inside container
docker exec -it freeswitch bash

# Check listening ports
netstat -an | grep LISTEN

# Test DNS
ping -c 3 google.com
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs freeswitch

# Remove and recreate
docker rm -f freeswitch
docker run -d --name freeswitch -p 5060:5060/tcp -p 5080:5080/tcp -p 8021:8021/tcp freeswitch-base:1.10.11
```

### Ports Not Forwarding

1. Check PORTS tab in Codespaces
2. Manually forward: Right-click → "Forward Port"
3. Make sure visibility is "Public"

### SIP Client Can't Register

**Issue**: Can't connect to forwarded SIP port

**Solution**: Use WebRTC (SIP over WebSocket on port 5080) instead of traditional SIP. Codespaces HTTPS forwarding works better with WebSocket.

### No Audio During Calls

**Issue**: Calls connect but no audio

**Cause**: RTP ports (16384-16484) can't be forwarded via Codespaces HTTPS tunnels

**Solutions**:
1. Test with fs_cli call origination (no real audio needed)
2. Use WebRTC which tunnels RTP over WebSocket
3. Deploy to real server for full audio testing

---

## Quick Commands Reference

```bash
# Build image
./dockerfiles/build-freeswitch-base.sh

# Run container
docker run -d --name freeswitch \
    -p 5060:5060/tcp -p 5080:5080/tcp -p 8021:8021/tcp \
    freeswitch-base:1.10.11

# Access fs_cli
docker exec -it freeswitch fs_cli

# View status
docker exec freeswitch fs_cli -x "status"

# Check SIP profiles
docker exec freeswitch fs_cli -x "sofia status"

# Show active calls
docker exec freeswitch fs_cli -x "show channels"

# Test call (1000 to 1001)
docker exec freeswitch fs_cli -x "originate user/1000 &bridge(user/1001)"

# View logs
docker logs -f freeswitch

# Restart container
docker restart freeswitch

# Stop and remove
docker rm -f freeswitch
```

---

## Comparison: Codespaces vs Docker Hub

| Feature | Codespaces Testing | Docker Hub + MacBook |
|---------|-------------------|---------------------|
| Setup Time | ⚡ Instant | 🕐 15-20 min (push/pull) |
| Real Audio | ⚠️ Limited (WebRTC only) | ✅ Full audio |
| Network | ⚠️ HTTPS tunnels | ✅ Direct UDP/TCP |
| Debugging | ✅ Easy (same environment) | ⚠️ Remote |
| Use Case | ✅ Development/Testing | ✅ Production-like |
| SIP Clients | ⚠️ WebRTC clients only | ✅ Any SIP client |

---

## Recommendation

**For Quick Development Testing**: Use Codespaces with fs_cli call origination
```bash
docker exec -it freeswitch fs_cli -x "originate user/1000 &bridge(user/1001)"
```

**For Real Audio Testing**: Push to Docker Hub and test on MacBook with real SIP clients
```bash
./dockerfiles/push-to-dockerhub.sh your-username
./dockerfiles/run-on-macbook.sh your-username  # On MacBook
```

**For WebRTC Testing**: Use Codespaces with WebSocket-based clients (JsSIP, SIPjs)

---

## Next Steps

1. ✅ Build FreeSWITCH in Codespaces
2. ✅ Test call flow with fs_cli
3. ✅ Verify extensions can bridge
4. ⏭️ For real calling, deploy to Docker Hub → MacBook
5. ⏭️ For production, deploy to VPS/cloud with public IP

---

**Happy Testing!** 🎉📞
