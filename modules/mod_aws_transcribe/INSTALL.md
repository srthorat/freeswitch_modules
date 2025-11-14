# mod_aws_transcribe - Complete Installation Guide

This guide provides step-by-step instructions to install and configure `mod_aws_transcribe` on FreeSWITCH with AWS Transcribe and Pusher integration.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Install Dependencies](#install-dependencies)
3. [Build AWS C++ SDK](#build-aws-c-sdk)
4. [Build mod_aws_transcribe](#build-mod_aws_transcribe)
5. [Configure FreeSWITCH](#configure-freeswitch)
6. [Configure Environment Variables](#configure-environment-variables)
7. [Configure Dialplan](#configure-dialplan)
8. [Test the Module](#test-the-module)

---

## Prerequisites

- FreeSWITCH installed (tested with 1.10.x)
- Root or sudo access
- AWS account with Transcribe service access
- Pusher account (optional, for real-time web delivery)
- Ubuntu 20.04/22.04 or CentOS 7/8 (other distros similar)

---

## Install Dependencies

### Ubuntu/Debian

```bash
# Update package lists
sudo apt-get update

# Install build tools
sudo apt-get install -y build-essential cmake git autoconf automake libtool pkg-config

# Install FreeSWITCH development headers
sudo apt-get install -y freeswitch-meta-dev

# Install libcurl with HTTP/2 support
sudo apt-get install -y libcurl4-openssl-dev

# Install OpenSSL development files
sudo apt-get install -y libssl-dev

# Install cJSON (if not available via package manager, install from source)
sudo apt-get install -y libcjson-dev || {
    git clone https://github.com/DaveGamble/cJSON.git
    cd cJSON
    mkdir build && cd build
    cmake ..
    make && sudo make install
    cd ../..
}

# Verify libcurl has HTTP/2 support
curl --version | grep HTTP2
# Should show: Features: ... HTTP2 ...
```

### CentOS/RHEL

```bash
# Update package lists
sudo yum update -y

# Install build tools
sudo yum groupinstall -y "Development Tools"
sudo yum install -y cmake git autoconf automake libtool pkgconfig

# Install FreeSWITCH development headers
sudo yum install -y freeswitch-devel

# Install libcurl with HTTP/2 support
sudo yum install -y libcurl-devel

# Install OpenSSL development files
sudo yum install -y openssl-devel

# Install cJSON from source
git clone https://github.com/DaveGamble/cJSON.git
cd cJSON
mkdir build && cd build
cmake ..
make && sudo make install
cd ../..
```

---

## Build AWS C++ SDK

The module requires AWS C++ SDK for Transcribe Streaming. You can use the automated Ansible role or follow manual steps:

### Option A: Using Ansible (Recommended)

```bash
# Install Ansible
sudo apt-get install -y ansible  # Ubuntu/Debian
# OR
sudo yum install -y ansible      # CentOS/RHEL

# Clone and run the ansible role
git clone https://github.com/davehorton/ansible-role-fsmrf.git
cd ansible-role-fsmrf

# Run the AWS SDK installation task
ansible-playbook -i localhost, -c local tasks/grpc.yml
```

### Option B: Manual Installation

```bash
# Set FreeSWITCH source directory
export FS_SRC_DIR=/usr/src/freeswitch

# Create directory for AWS SDK
sudo mkdir -p ${FS_SRC_DIR}/libs
cd ${FS_SRC_DIR}/libs

# Clone AWS SDK C++
sudo git clone --recurse-submodules https://github.com/aws/aws-sdk-cpp.git
cd aws-sdk-cpp

# Create build directory
sudo mkdir build
cd build

# Configure with only required components
sudo cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_ONLY="transcribestreaming" \
    -DENABLE_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=${FS_SRC_DIR}/libs/aws-sdk-cpp/build/.deps/install

# Build (this takes 15-30 minutes)
sudo make -j$(nproc)

# Install
sudo make install
```

---

## Build mod_aws_transcribe

```bash
# Clone the repository
cd /usr/src
git clone https://github.com/srthorat/freeswitch_modules.git
cd freeswitch_modules/modules/mod_aws_transcribe

# Set FreeSWITCH source directory if not already set
export FS_SRC_DIR=/usr/src/freeswitch

# Generate build files
aclocal
autoconf
automake --add-missing

# Configure
./configure --with-freeswitch-src=${FS_SRC_DIR}

# Build
make

# Install
sudo make install

# The module will be installed to:
# /usr/lib/freeswitch/mod/mod_aws_transcribe.so
```

---

## Configure FreeSWITCH

### 1. Load the Module

Edit `/etc/freeswitch/autoload_configs/modules.conf.xml`:

```xml
<configuration name="modules.conf" description="Modules">
  <modules>
    <!-- Add this line -->
    <load module="mod_aws_transcribe"/>

    <!-- Other modules... -->
  </modules>
</configuration>
```

### 2. Create Module Configuration (Optional)

Create `/etc/freeswitch/autoload_configs/aws_transcribe.conf.xml`:

```xml
<configuration name="aws_transcribe.conf" description="AWS Transcribe Configuration">
  <settings>
    <!-- All settings are optional, can use environment variables instead -->
  </settings>
</configuration>
```

---

## Configure Environment Variables

### Method 1: FreeSWITCH systemd service (Recommended for Production)

Edit `/etc/systemd/system/freeswitch.service` or `/lib/systemd/system/freeswitch.service`:

```ini
[Service]
Type=forking
PIDFile=/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"

# AWS Configuration
Environment="AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX"
Environment="AWS_SECRET_ACCESS_KEY=your-secret-access-key-here"
Environment="AWS_REGION=us-east-1"

# Pusher Configuration (Optional - for real-time web delivery)
Environment="PUSHER_APP_ID=1234567"
Environment="PUSHER_KEY=your-pusher-app-key"
Environment="PUSHER_SECRET=your-pusher-app-secret"
Environment="PUSHER_CLUSTER=us2"

ExecStart=/usr/bin/freeswitch -u freeswitch -g freeswitch -ncwait $DAEMON_OPTS
TimeoutSec=45s
Restart=always
```

After editing, reload systemd and restart FreeSWITCH:

```bash
sudo systemctl daemon-reload
sudo systemctl restart freeswitch
```

### Method 2: Environment file (Alternative)

Create `/etc/default/freeswitch`:

```bash
# AWS Transcribe Configuration
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key-here"
export AWS_REGION="us-east-1"

# Pusher Configuration (Optional)
export PUSHER_APP_ID="1234567"
export PUSHER_KEY="your-pusher-app-key"
export PUSHER_SECRET="your-pusher-app-secret"
export PUSHER_CLUSTER="us2"
```

Then source this file in your systemd service:

```ini
[Service]
EnvironmentFile=/etc/default/freeswitch
```

### Method 3: Shell export (Testing only)

```bash
# In the shell where you start FreeSWITCH
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key-here"
export AWS_REGION="us-east-1"
export PUSHER_APP_ID="1234567"
export PUSHER_KEY="your-pusher-app-key"
export PUSHER_SECRET="your-pusher-app-secret"
export PUSHER_CLUSTER="us2"

# Start FreeSWITCH
sudo -E /usr/bin/freeswitch -nonat -nc
```

---

## Configure Dialplan

### Scenario: Extensions 1000 and 1001 with Automatic Transcription

When extension 1000 calls extension 1001, we want:
- Automatic stereo transcription with speaker diarization
- Caller (1000) = Speaker 0 (left channel)
- Callee (1001) = Speaker 1 (right channel)
- Real-time delivery to Pusher channel `transcription-{uuid}`

### Step 1: Create Transcription Dialplan

Create `/etc/freeswitch/dialplan/default/01_transcribe.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<include>
  <!--
    Local Extension with Automatic Transcription
    This dialplan handles calls between local extensions with real-time transcription
  -->
  <extension name="local_extension_with_transcription">
    <condition field="destination_number" expression="^(10[0-9]{2})$">

      <!-- Set caller and callee information -->
      <action application="set" data="caller_id_number=${caller_id_number}"/>
      <action application="set" data="caller_id_name=${caller_id_name}"/>
      <action application="set" data="callee_id_number=${destination_number}"/>

      <!-- Get callee name from directory -->
      <action application="set" data="callee_id_name=${user_data(${destination_number}@${domain_name} var effective_caller_id_name)}"/>

      <!-- Fallback if callee name not found -->
      <action application="set" data="callee_id_name=${callee_id_name:-Extension ${destination_number}}"/>

      <!-- Log call information -->
      <action application="log" data="INFO Starting transcribed call: ${caller_id_name} (${caller_id_number}) -> ${callee_id_name} (${callee_id_number})"/>

      <!-- Export variables to B-leg -->
      <action application="export" data="transcription_enabled=true"/>
      <action application="export" data="caller_id_number=${caller_id_number}"/>
      <action application="export" data="caller_id_name=${caller_id_name}"/>
      <action application="export" data="callee_id_number=${callee_id_number}"/>
      <action application="export" data="callee_id_name=${callee_id_name}"/>

      <!-- Set codec for better audio quality -->
      <action application="set" data="absolute_codec_string=PCMU,PCMA"/>

      <!-- Bridge with transcription hook -->
      <action application="bridge" data="{api_on_answer='lua transcribe_start.lua'}user/${destination_number}@${domain_name}"/>

    </condition>
  </extension>
</include>
```

### Step 2: Create Lua Script for Transcription

Create `/usr/share/freeswitch/scripts/transcribe_start.lua`:

```lua
-- transcribe_start.lua
-- Automatically starts AWS Transcribe when call is answered

-- Get session
local session = assert(session, "No session available")
local uuid = session:getVariable("uuid")

-- Get caller and callee information
local caller_number = session:getVariable("caller_id_number") or "Unknown"
local caller_name = session:getVariable("caller_id_name") or caller_number
local callee_number = session:getVariable("callee_id_number") or session:getVariable("destination_number") or "Unknown"
local callee_name = session:getVariable("callee_id_name") or callee_number

-- Build speaker metadata
-- Speaker 0 = Caller (left channel in stereo)
-- Speaker 1 = Callee (right channel in stereo)
local speakers = {
    speakers = {
        "Caller: " .. caller_name .. " (" .. caller_number .. ")",
        "Callee: " .. callee_name .. " (" .. callee_number .. ")"
    }
}

-- Convert to JSON
local speaker_json = require("cjson").encode(speakers)

-- Build API command
-- Format: aws_transcribe <uuid> start <lang-code> [interim] [stereo] [bugname] [metadata]
local api_cmd = string.format(
    "aws_transcribe %s start en-US interim stereo transcribe_bug %s",
    uuid,
    speaker_json
)

-- Log the command
freeswitch.consoleLog("INFO", "Starting transcription: " .. api_cmd .. "\n")

-- Execute API command
local result = session:execute("api", api_cmd)

-- Log result
freeswitch.consoleLog("INFO", "Transcription started: " .. tostring(result) .. "\n")

-- Store UUID in channel variable for web app retrieval
session:setVariable("transcription_uuid", uuid)
session:setVariable("transcription_channel", "transcription-" .. uuid)
```

### Step 3: Alternative - Inline Dialplan (No Lua Required)

If you prefer not to use Lua, use this inline dialplan:

Create `/etc/freeswitch/dialplan/default/01_transcribe_inline.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<include>
  <extension name="local_extension_with_transcription_inline">
    <condition field="destination_number" expression="^(10[0-9]{2})$">

      <!-- Set caller and callee information -->
      <action application="set" data="caller_id_number=${caller_id_number}"/>
      <action application="set" data="caller_id_name=${caller_id_name}"/>
      <action application="set" data="callee_id_number=${destination_number}"/>
      <action application="set" data="callee_id_name=${user_data(${destination_number}@${domain_name} var effective_caller_id_name)}"/>
      <action application="set" data="callee_id_name=${callee_id_name:-Extension ${destination_number}}"/>

      <!-- Build speaker metadata JSON -->
      <!-- Speaker 0 = Caller, Speaker 1 = Callee -->
      <action application="set"><![CDATA[data="speaker_meta={\"speakers\":[\"Caller: ${caller_id_name} (${caller_id_number})\",\"Callee: ${callee_id_name} (${callee_id_number})\"]}"]]></action>

      <!-- Export to B-leg -->
      <action application="export" data="nolocal:execute_on_answer=aws_transcribe ${uuid} start en-US interim stereo transcribe_bug ${speaker_meta}"/>
      <action application="export" data="transcription_uuid=${uuid}"/>
      <action application="export" data="transcription_channel=transcription-${uuid}"/>

      <!-- Bridge call -->
      <action application="bridge" data="user/${destination_number}@${domain_name}"/>

    </condition>
  </extension>
</include>
```

### Step 4: Configure User Directory

Edit `/etc/freeswitch/directory/default/1000.xml`:

```xml
<include>
  <user id="1000">
    <params>
      <param name="password" value="1234"/>
      <param name="vm-password" value="1000"/>
    </params>
    <variables>
      <variable name="toll_allow" value="domestic,international,local"/>
      <variable name="accountcode" value="1000"/>
      <variable name="user_context" value="default"/>
      <variable name="effective_caller_id_name" value="John Doe"/>
      <variable name="effective_caller_id_number" value="1000"/>
      <variable name="outbound_caller_id_name" value="John Doe"/>
      <variable name="outbound_caller_id_number" value="1000"/>
    </variables>
  </user>
</include>
```

Edit `/etc/freeswitch/directory/default/1001.xml`:

```xml
<include>
  <user id="1001">
    <params>
      <param name="password" value="1234"/>
      <param name="vm-password" value="1001"/>
    </params>
    <variables>
      <variable name="toll_allow" value="domestic,international,local"/>
      <variable name="accountcode" value="1001"/>
      <variable name="user_context" value="default"/>
      <variable name="effective_caller_id_name" value="Jane Smith"/>
      <variable name="effective_caller_id_number" value="1001"/>
      <variable name="outbound_caller_id_name" value="Jane Smith"/>
      <variable name="outbound_caller_id_number" value="1001"/>
    </variables>
  </user>
</include>
```

---

## Test the Module

### 1. Verify Module is Loaded

```bash
fs_cli -x "module_exists mod_aws_transcribe"
# Should return: true

fs_cli -x "show module mod_aws_transcribe"
# Should show module details
```

### 2. Check Environment Variables

```bash
fs_cli -x "eval ${getenv(AWS_ACCESS_KEY_ID)}"
# Should show your AWS access key

fs_cli -x "eval ${getenv(PUSHER_APP_ID)}"
# Should show your Pusher app ID
```

### 3. Test Transcription Manually

```bash
# In fs_cli
# Originate a call from 1000 to 1001
originate user/1000 &bridge(user/1001)

# Get the call UUID from the output, e.g., abc123-def456-...
# Then check if transcription started
show channels
```

### 4. Test Transcription with API Command

```bash
# In fs_cli, during an active call
# Get UUID
show channels

# Start transcription manually
aws_transcribe <UUID> start en-US interim stereo transcribe_bug {"speakers":["Caller: John Doe (1000)","Callee: Jane Smith (1001)"]}

# Stop transcription
aws_transcribe <UUID> stop
```

### 5. Check FreeSWITCH Logs

```bash
tail -f /var/log/freeswitch/freeswitch.log | grep -i transcribe
```

You should see:
- "Pusher REST API integration enabled"
- "Starting AWS Transcribe session"
- "Successfully sent transcript to Pusher channel transcription-{uuid}"

---

## Web Client Integration

### Get Call UUID for Web Subscription

Your application needs to know the call UUID to subscribe to the correct Pusher channel. There are several ways:

#### Option 1: Via Web API / WebSocket

When initiating a call from your web app, you can create the call and get the UUID:

```javascript
// Example: Using FreeSWITCH ESL or REST API
async function makeCall(from, to) {
    const response = await fetch('https://your-freeswitch-api/originate', {
        method: 'POST',
        body: JSON.stringify({
            from: from,
            to: to
        })
    });

    const data = await response.json();
    const callUuid = data.uuid;

    // Subscribe to Pusher channel
    subscribeToTranscription(callUuid);
}
```

#### Option 2: Via Channel Variables and Web Hook

In your dialplan, send the UUID to your web app:

```xml
<action application="set" data="api_on_answer=curl https://your-webapp.com/api/call-answered uuid=${uuid} caller=${caller_id_number} callee=${callee_id_number}"/>
```

#### Option 3: Via FreeSWITCH Event Socket

Subscribe to call events and extract UUID:

```javascript
// Using Node.js ESL library
const esl = require('modesl');
const conn = new esl.Connection('localhost', 8021, 'ClueCon', function() {
    conn.subscribe(['CHANNEL_ANSWER', 'CHANNEL_HANGUP']);
});

conn.on('esl::event::CHANNEL_ANSWER::**', function(event) {
    const uuid = event.getHeader('Unique-ID');
    const caller = event.getHeader('Caller-Caller-ID-Number');
    const callee = event.getHeader('Caller-Callee-ID-Number');

    // Notify web app to subscribe to transcription-{uuid}
    notifyWebApp(uuid, caller, callee);
});
```

### Web Client Pusher Subscription

```html
<!DOCTYPE html>
<html>
<head>
    <title>Live Transcription</title>
    <script src="https://js.pusher.com/8.0/pusher.min.js"></script>
</head>
<body>
    <h1>Live Call Transcription</h1>
    <div id="transcription"></div>

    <script>
        // Initialize Pusher
        const pusher = new Pusher('YOUR_PUSHER_KEY', {
            cluster: 'YOUR_CLUSTER'
        });

        // Get call UUID from your app (via API, event, etc.)
        const callUuid = 'abc123-def456-...'; // Retrieved from your backend

        // Subscribe to the call's transcription channel
        const channel = pusher.subscribe('transcription-' + callUuid);

        // Bind to transcript events
        channel.bind('transcript', function(data) {
            console.log('Received transcript:', data);

            const transcriptDiv = document.getElementById('transcription');

            if (data.segments) {
                // With speaker diarization
                data.segments.forEach(segment => {
                    const p = document.createElement('p');
                    p.innerHTML = `<strong>${segment.speaker_name}:</strong> ${segment.text}`;

                    if (data.is_final) {
                        p.style.fontWeight = 'bold';
                    } else {
                        p.style.color = '#666';
                        p.style.fontStyle = 'italic';
                    }

                    transcriptDiv.appendChild(p);
                });
            } else {
                // Without diarization
                const p = document.createElement('p');
                p.textContent = data.transcript;
                transcriptDiv.appendChild(p);
            }

            // Auto-scroll
            transcriptDiv.scrollTop = transcriptDiv.scrollHeight;
        });

        // Handle connection state
        pusher.connection.bind('connected', function() {
            console.log('Connected to Pusher');
        });

        pusher.connection.bind('error', function(err) {
            console.error('Pusher error:', err);
        });
    </script>
</body>
</html>
```

---

## Understanding Pusher Channels and Multiple Subscribers

### How Pusher Channels Work

**One channel per call:**
- Each call creates ONE unique Pusher channel: `transcription-{uuid}`
- The UUID is the FreeSWITCH call UUID, which is unique for each call
- Example: `transcription-abc123-def456-789`

**Multiple subscribers to the same channel:**
- Multiple web clients can subscribe to the SAME channel
- All subscribers receive the SAME transcript data in real-time
- This is useful for:
  - Call center supervisor monitoring
  - Multiple agents viewing the same call
  - Recording/compliance systems
  - Analytics dashboards

**Example scenarios:**

1. **Single caller/callee + supervisor:**
   - Extension 1000 calls 1001 → UUID: `abc-123`
   - Channel: `transcription-abc-123`
   - Subscribers:
     - 1000's web app (shows transcription)
     - 1001's web app (shows transcription)
     - Supervisor dashboard (monitors transcription)
   - All three receive the SAME real-time transcript

2. **Multiple concurrent calls:**
   - Call 1: 1000 → 1001, UUID: `abc-123`, Channel: `transcription-abc-123`
   - Call 2: 1002 → 1003, UUID: `def-456`, Channel: `transcription-def-456`
   - Each call has its own isolated channel
   - No cross-talk between channels

### Speaker Mapping (Caller vs Callee)

**Stereo Audio Channels:**
- Left channel (0) = Caller audio
- Right channel (1) = Callee audio

**AWS Speaker Diarization:**
- AWS labels speakers as `spk_0` and `spk_1`
- In stereo mode:
  - `spk_0` = Left channel = Caller
  - `spk_1` = Right channel = Callee

**Our Implementation:**
```json
{
  "speakers": [
    "Caller: John Doe (1000)",    // Index 0 → mapped to spk_0
    "Callee: Jane Smith (1001)"   // Index 1 → mapped to spk_1
  ]
}
```

**Result in Pusher:**
```json
{
  "session_id": "abc-123",
  "is_final": true,
  "segments": [
    {
      "speaker_label": "spk_0",
      "speaker_name": "Caller: John Doe (1000)",
      "text": "Hello, this is John",
      "start_time": 0.5,
      "end_time": 2.3
    },
    {
      "speaker_label": "spk_1",
      "speaker_name": "Callee: Jane Smith (1001)",
      "text": "Hi John, how can I help?",
      "start_time": 2.5,
      "end_time": 4.8
    }
  ]
}
```

**Always consistent:**
- Array index 0 = Caller = spk_0 = Left channel
- Array index 1 = Callee = spk_1 = Right channel

---

## Troubleshooting

### Module fails to load

```bash
# Check dependencies
ldd /usr/lib/freeswitch/mod/mod_aws_transcribe.so

# Check FreeSWITCH logs
tail -f /var/log/freeswitch/freeswitch.log
```

### Transcription not starting

```bash
# Check environment variables are set
fs_cli -x "eval ${getenv(AWS_ACCESS_KEY_ID)}"
fs_cli -x "eval ${getenv(AWS_REGION)}"

# Check AWS credentials are valid
aws transcribe help  # If AWS CLI is installed

# Check FreeSWITCH logs for errors
tail -f /var/log/freeswitch/freeswitch.log | grep -i "aws"
```

### Pusher not receiving data

```bash
# Check Pusher environment variables
fs_cli -x "eval ${getenv(PUSHER_APP_ID)}"
fs_cli -x "eval ${getenv(PUSHER_KEY)}"
fs_cli -x "eval ${getenv(PUSHER_SECRET)}"
fs_cli -x "eval ${getenv(PUSHER_CLUSTER)}"

# Check FreeSWITCH logs for Pusher errors
tail -f /var/log/freeswitch/freeswitch.log | grep -i "pusher"

# Test Pusher credentials with curl
curl -X POST "https://api-us2.pusher.com/apps/YOUR_APP_ID/events?auth_key=YOUR_KEY&auth_timestamp=$(date +%s)&auth_version=1.0" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","channel":"test-channel","data":"{\"message\":\"test\"}"}'
```

### Audio quality issues

```bash
# Use better codec
<action application="set" data="absolute_codec_string=PCMU,PCMA,G722"/>

# Increase audio buffer size (in your SIP profile)
<param name="rtp-timeout-sec" value="300"/>
<param name="rtp-hold-timeout-sec" value="1800"/>
```

---

## Performance Tuning

### For High Volume (1000+ concurrent calls)

1. **HTTP/2 connection limits:**
   - libcurl will reuse HTTP/2 connections automatically
   - Monitor with: `netstat -an | grep :443 | wc -l`

2. **AWS API rate limits:**
   - AWS Transcribe Streaming: No specific limit, billed per second
   - Monitor throttling in CloudWatch

3. **Pusher rate limits:**
   - Free tier: 200k messages/day
   - Pro tier: 10+ million messages/day
   - Each transcript segment = 1 message

4. **FreeSWITCH tuning:**
   ```xml
   <!-- In vars.xml -->
   <X-PRE-PROCESS cmd="set" data="max_sessions=10000"/>
   <X-PRE-PROCESS cmd="set" data="sessions_per_second=1000"/>
   ```

---

## Security Best Practices

1. **Never hardcode credentials** - Always use environment variables
2. **Restrict AWS IAM permissions:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": "transcribe:StartStreamTranscription",
       "Resource": "*"
     }]
   }
   ```
3. **Use Pusher channel authentication** for private channels (requires webhook)
4. **Enable TLS** for all network communications
5. **Rotate credentials** regularly
6. **Monitor CloudWatch logs** for AWS Transcribe errors

---

## Next Steps

- Configure PII redaction (see README.md)
- Set up custom vocabularies for domain-specific terms
- Implement vocabulary filters for profanity
- Add webhook for call recording metadata
- Build dashboard for transcription analytics

For more information, see [README.md](README.md) and [API Reference](API.md).
