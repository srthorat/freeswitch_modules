# mod_aws_transcribe - AWS Speaker Diarization Support

Complete installation guide for adding speaker diarization support to mod_aws_transcribe using AWS Transcribe's native speaker identification feature.

## Table of Contents
1. [Features](#features)
2. [Prerequisites](#prerequisites)
3. [Installation Steps](#installation-steps)
   - [Install System Dependencies](#step-1-install-system-dependencies)
   - [Install AWS C++ SDK](#step-2-install-aws-c-sdk)
   - [Build mod_aws_transcribe](#step-3-build-mod_aws_transcribe)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Features

- **Speaker metadata structure** for mapping AWS speaker labels to real names
- **JSON metadata parsing** in API command for passing speaker names
- **Stereo audio support** with deterministic speaker channel isolation
- **Integration with AWS Transcribe** speaker diarization feature
- **Foundation for extensions** - can be integrated with webhooks, Pusher, or other services

---

## Prerequisites

- Ubuntu 20.04/22.04 or Debian 10/11 (other distros similar)
- FreeSWITCH 1.10.x installed and configured
- Root or sudo access
- AWS account with Transcribe service access
- At least 4GB RAM and 10GB free disk space (for building AWS SDK)

---

## Installation Steps

### Step 1: Install System Dependencies

#### Ubuntu/Debian

```bash
# Update package lists
sudo apt-get update

# Install build essentials
sudo apt-get install -y build-essential git cmake autoconf automake libtool pkg-config

# Install FreeSWITCH development headers
sudo apt-get install -y freeswitch-meta-dev

# If FreeSWITCH dev headers not available via package, install from source
# See: https://freeswitch.org/confluence/display/FREESWITCH/Installation

# Install required libraries
sudo apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    zlib1g-dev \
    libcjson-dev \
    uuid-dev

# Install cJSON (if not available via package manager)
if ! dpkg -l | grep -q libcjson-dev; then
    cd /tmp
    git clone https://github.com/DaveGamble/cJSON.git
    cd cJSON
    mkdir build && cd build
    cmake ..
    make
    sudo make install
    sudo ldconfig
fi
```

#### CentOS/RHEL 7/8

```bash
# Update package lists
sudo yum update -y

# Install build tools
sudo yum groupinstall -y "Development Tools"
sudo yum install -y cmake3 git autoconf automake libtool pkgconfig

# Install FreeSWITCH development headers
sudo yum install -y freeswitch-devel

# Install required libraries
sudo yum install -y \
    libcurl-devel \
    openssl-devel \
    zlib-devel \
    libuuid-devel

# Install cJSON from source
cd /tmp
git clone https://github.com/DaveGamble/cJSON.git
cd cJSON
mkdir build && cd build
cmake3 ..
make
sudo make install
sudo ldconfig
```

### Step 2: Install AWS C++ SDK

The AWS C++ SDK is required for AWS Transcribe Streaming API.

#### Option A: Automated Installation (Recommended)

Using the ansible role:

```bash
# Install Ansible
sudo apt-get install -y ansible  # Ubuntu/Debian
# OR
sudo yum install -y ansible      # CentOS/RHEL

# Clone the ansible role
cd /tmp
git clone https://github.com/davehorton/ansible-role-fsmrf.git
cd ansible-role-fsmrf

# Run only the AWS SDK installation task
ansible-playbook -i localhost, -c local tasks/grpc.yml

# This will install AWS SDK to:
# /usr/src/freeswitch/libs/aws-sdk-cpp
```

#### Option B: Manual Installation (Full Control)

```bash
# Set FreeSWITCH source directory
# Adjust this path if your FreeSWITCH source is elsewhere
export FS_SRC_DIR=/usr/src/freeswitch

# Create libs directory if it doesn't exist
sudo mkdir -p ${FS_SRC_DIR}/libs
cd ${FS_SRC_DIR}/libs

# Clone AWS SDK C++ (this will take a few minutes)
sudo git clone --recurse-submodules https://github.com/aws/aws-sdk-cpp.git
cd aws-sdk-cpp

# Create build directory
sudo mkdir build
cd build

# Configure CMake
# We only build the transcribestreaming component to save time and space
sudo cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_ONLY="transcribestreaming" \
    -DENABLE_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=${FS_SRC_DIR}/libs/aws-sdk-cpp/build/.deps/install

# Build (this takes 15-30 minutes depending on your system)
# Use -j$(nproc) to use all CPU cores
sudo make -j$(nproc)

# Install
sudo make install

# Verify installation
ls -la ${FS_SRC_DIR}/libs/aws-sdk-cpp/build/.deps/install/lib/
# You should see libaws-cpp-sdk-*.so files
```

**Note:** If you get compilation errors, you may need to update your GCC:

```bash
# Ubuntu/Debian
sudo apt-get install -y gcc-9 g++-9
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 90

# CentOS/RHEL
sudo yum install -y centos-release-scl
sudo yum install -y devtoolset-9
scl enable devtoolset-9 bash
```

### Step 3: Build mod_aws_transcribe

```bash
# Clone the repository
cd /usr/src
sudo git clone https://github.com/srthorat/freeswitch_modules.git
cd freeswitch_modules

# Checkout the AWS diarization branch
sudo git checkout claude/aws-transcribe-speaker-diarization-011CV5rDARmbG2qx8jdzGpq9

# Navigate to module directory
cd modules/mod_aws_transcribe

# Set FreeSWITCH source directory (if not already set)
export FS_SRC_DIR=/usr/src/freeswitch

# Generate build configuration files
aclocal
autoconf
automake --add-missing

# If automake complains about missing files, create them:
touch NEWS README AUTHORS ChangeLog

# Configure the module
./configure --with-freeswitch-src=${FS_SRC_DIR}

# If configure fails with "cannot find freeswitch headers", ensure:
# 1. FreeSWITCH is installed or source is available
# 2. FS_SRC_DIR points to the correct location

# Build the module
make

# If build is successful, install it
sudo make install

# Verify installation
ls -la /usr/lib/freeswitch/mod/mod_aws_transcribe.so
# The file should exist and be around 1-2 MB
```

**Common Build Issues:**

```bash
# If you get "aws_transcribe_glue.h: No such file"
# Make sure you're in the correct directory:
pwd  # Should show: /usr/src/freeswitch_modules/modules/mod_aws_transcribe

# If you get linker errors about AWS SDK
# Verify AWS SDK path in Makefile.am matches your installation
grep "aws-sdk-cpp" Makefile.am

# If you get "cannot find -laws-cpp-sdk-transcribestreaming"
# Check that AWS SDK built successfully:
ls ${FS_SRC_DIR}/libs/aws-sdk-cpp/build/aws-cpp-sdk-transcribestreaming/
# Should see libaws-cpp-sdk-transcribestreaming.so
```

---

## Configuration

### 1. Load the Module in FreeSWITCH

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

### 2. Configure AWS Credentials

#### Method 1: Environment Variables (Recommended)

Edit FreeSWITCH systemd service file:

```bash
sudo nano /etc/systemd/system/freeswitch.service
# or
sudo nano /lib/systemd/system/freeswitch.service
```

Add environment variables:

```ini
[Service]
Type=forking
PIDFile=/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"

# AWS Configuration
Environment="AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX"
Environment="AWS_SECRET_ACCESS_KEY=your-secret-access-key-here"
Environment="AWS_REGION=us-east-1"

# Optional: For temporary credentials
# Environment="AWS_SESSION_TOKEN=your-session-token"

ExecStart=/usr/bin/freeswitch -u freeswitch -g freeswitch -ncwait $DAEMON_OPTS
TimeoutSec=45s
Restart=always
```

Reload and restart FreeSWITCH:

```bash
sudo systemctl daemon-reload
sudo systemctl restart freeswitch
```

#### Method 2: Environment File

Create `/etc/default/freeswitch`:

```bash
# AWS Transcribe Configuration
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key-here"
export AWS_REGION="us-east-1"
```

Make it secure:

```bash
sudo chmod 600 /etc/default/freeswitch
sudo chown freeswitch:freeswitch /etc/default/freeswitch
```

Reference in systemd service:

```ini
[Service]
EnvironmentFile=/etc/default/freeswitch
```

#### Method 3: Per-Call Channel Variables

Set channel variables before starting transcription:

```xml
<action application="set" data="AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX"/>
<action application="set" data="AWS_SECRET_ACCESS_KEY=your-secret-key"/>
<action application="set" data="AWS_REGION=us-east-1"/>
```

### 3. Get AWS Credentials

If you don't have AWS credentials:

```bash
# Install AWS CLI
sudo apt-get install -y awscli  # Ubuntu/Debian
# OR
sudo yum install -y aws-cli     # CentOS/RHEL

# Configure AWS CLI
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)

# Verify credentials
aws sts get-caller-identity

# Your credentials are stored in:
cat ~/.aws/credentials
```

**Create IAM User for FreeSWITCH:**

1. Go to AWS Console → IAM → Users → Add User
2. User name: `freeswitch-transcribe`
3. Access type: Programmatic access
4. Attach policy: Create custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "transcribe:StartStreamTranscription",
        "transcribe:StartStreamTranscriptionWebSocket"
      ],
      "Resource": "*"
    }
  ]
}
```

5. Copy Access Key ID and Secret Access Key

---

## Usage

### Basic API Command

```bash
aws_transcribe <uuid> start <lang-code> [interim] [stereo|mono] [bugname] [{"speakers":["Name1","Name2"]}]
```

### Example 1: Simple Transcription (No Speaker Diarization)

```bash
# In fs_cli
# Start a call
originate user/1000 &echo

# Get UUID from output, then start transcription
aws_transcribe <UUID> start en-US interim
```

### Example 2: With Speaker Diarization

Enable speaker diarization with channel variable:

```bash
# In fs_cli
originate {AWS_SHOW_SPEAKER_LABEL=true}user/1000 &echo

# Start transcription with speaker names
aws_transcribe <UUID> start en-US interim stereo mybug {"speakers":["Alice","Bob"]}
```

### Example 3: FreeSWITCH Dialplan Integration

Create `/etc/freeswitch/dialplan/default/01_aws_transcribe.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<include>
  <extension name="transcribe_test">
    <condition field="destination_number" expression="^9999$">

      <!-- Enable speaker diarization -->
      <action application="set" data="AWS_SHOW_SPEAKER_LABEL=true"/>

      <!-- Answer the call -->
      <action application="answer"/>

      <!-- Start transcription -->
      <action application="inline" data="aws_transcribe ${uuid} start en-US interim stereo transcribe_bug {&quot;speakers&quot;:[&quot;Caller&quot;,&quot;System&quot;]}"/>

      <!-- Play audio for testing -->
      <action application="playback" data="/usr/share/freeswitch/sounds/en/us/callie/ivr/8000/ivr-thank_you_for_calling.wav"/>

      <!-- Stop transcription -->
      <action application="inline" data="aws_transcribe ${uuid} stop transcribe_bug"/>

      <action application="hangup"/>
    </condition>
  </extension>
</include>
```

Reload dialplan:

```bash
fs_cli -x "reloadxml"
```

### Example 4: Node.js Integration (drachtio-fsmrf)

```javascript
const Mrf = require('drachtio-fsmrf');
const mrf = new Mrf(require('drachtio')());

mrf.connect({address: '127.0.0.1', port: 8021, secret: 'ClueCon'})
  .then((mediaserver) => {
    return mediaserver.createEndpoint({remoteSdp: remoteSdp});
  })
  .then((endpoint) => {
    // Enable speaker diarization
    endpoint.set('AWS_SHOW_SPEAKER_LABEL', 'true');

    // Start transcription with speaker names
    const speakers = {speakers: ["Agent: John", "Customer: Jane"]};
    endpoint.api('aws_transcribe',
      `${endpoint.uuid} start en-US interim stereo mybug ${JSON.stringify(speakers)}`);

    // Subscribe to transcription events
    endpoint.on('aws_transcribe::transcription', (evt) => {
      console.log('Transcription:', evt.body);
      // Process transcription...
    });
  });
```

### Speaker Mapping in Stereo Mode

When using **stereo mode**, speaker mapping is deterministic:

- **Left channel (0)** = Caller → `spk_0` → speakers[0]
- **Right channel (1)** = Callee → `spk_1` → speakers[1]

**Example:**

```json
{"speakers": ["Caller: John (1000)", "Callee: Jane (1001)"]}
```

AWS will label:
- John as `spk_0` (always)
- Jane as `spk_1` (always)

---

## Testing

### Test 1: Verify Module Loaded

```bash
fs_cli -x "module_exists mod_aws_transcribe"
# Should return: true

fs_cli -x "show module mod_aws_transcribe"
# Should show module details
```

### Test 2: Verify AWS Credentials

```bash
fs_cli -x "eval \${getenv(AWS_ACCESS_KEY_ID)}"
# Should show your access key

fs_cli -x "eval \${getenv(AWS_REGION)}"
# Should show your region (e.g., us-east-1)
```

### Test 3: Test Transcription

```bash
# Dial extension 9999 (if you created the dialplan above)
# Or create a test call:

fs_cli
> originate {AWS_SHOW_SPEAKER_LABEL=true}user/1000 &echo
# Note the UUID from output

> aws_transcribe <UUID> start en-US interim stereo test_bug {"speakers":["Speaker1","Speaker2"]}
# Should return: +OK Success

# Talk into the call...

# Check FreeSWITCH logs
> console loglevel DEBUG
# You should see transcription events

# Stop transcription
> aws_transcribe <UUID> stop test_bug
```

### Test 4: Monitor Events

```bash
# In fs_cli
> events plain custom aws_transcribe::transcription

# Make a call and start transcription
# You should see events like:
# Event-Name: CUSTOM
# Event-Subclass: aws_transcribe::transcription
# transcription-vendor: aws
# Content-Length: <size>
#
# [{"is_final":true,"alternatives":[{"transcript":"hello world"}]}]
```

---

## Troubleshooting

### Module fails to load

**Error:** `Cannot load module mod_aws_transcribe`

```bash
# Check module file exists
ls -la /usr/lib/freeswitch/mod/mod_aws_transcribe.so

# Check dependencies
ldd /usr/lib/freeswitch/mod/mod_aws_transcribe.so
# All libraries should be found (=> /path/to/lib.so)
# If you see "not found", install missing library

# Check FreeSWITCH logs
tail -f /var/log/freeswitch/freeswitch.log | grep -i aws
```

**Solution:**

```bash
# If AWS SDK libraries not found:
export LD_LIBRARY_PATH=/usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install/lib:$LD_LIBRARY_PATH
sudo ldconfig

# Or add to /etc/ld.so.conf.d/freeswitch.conf:
echo "/usr/src/freeswitch/libs/aws-sdk-cpp/build/.deps/install/lib" | sudo tee /etc/ld.so.conf.d/aws-sdk.conf
sudo ldconfig
```

### Transcription not starting

**Error:** `-ERR Operation Failed`

```bash
# Check AWS credentials
fs_cli -x "eval \${getenv(AWS_ACCESS_KEY_ID)}"
fs_cli -x "eval \${getenv(AWS_SECRET_ACCESS_KEY)}"
fs_cli -x "eval \${getenv(AWS_REGION)}"

# Test AWS credentials with CLI
aws transcribe help

# Check FreeSWITCH logs for AWS errors
tail -f /var/log/freeswitch/freeswitch.log | grep -i "aws\|transcribe"
```

**Common errors:**

- `InvalidSignatureException`: Check AWS_SECRET_ACCESS_KEY
- `UnrecognizedClientException`: Check AWS_ACCESS_KEY_ID
- `AccessDeniedException`: Check IAM permissions
- `Region not supported`: Use supported region (us-east-1, us-west-2, etc.)

### No transcription events received

```bash
# Ensure you're subscribed to events
fs_cli
> events plain custom aws_transcribe::transcription

# Check if transcription actually started
> show channels

# Increase log level
> console loglevel DEBUG

# Check if audio is being sent
> uuid_audio_fork <UUID> start /tmp/test.wav 20 both
# This will record audio to /tmp/test.wav for debugging
```

### Speaker diarization not working

```bash
# Ensure AWS_SHOW_SPEAKER_LABEL is set
fs_cli -x "uuid_getvar <UUID> AWS_SHOW_SPEAKER_LABEL"
# Should return: true

# Ensure using stereo mode
# The command should include "stereo"
aws_transcribe <UUID> start en-US interim stereo ...

# Check transcription output for speaker_label field
```

### Build errors

**Error:** `aws_transcribe_glue.h: No such file or directory`

```bash
# Ensure you're in the correct directory
pwd
# Should be: /usr/src/freeswitch_modules/modules/mod_aws_transcribe

# List files
ls -la
# Should see: aws_transcribe_glue.cpp, aws_transcribe_glue.h, mod_aws_transcribe.c
```

**Error:** `cannot find -laws-cpp-sdk-transcribestreaming`

```bash
# Check AWS SDK installation
ls /usr/src/freeswitch/libs/aws-sdk-cpp/build/aws-cpp-sdk-transcribestreaming/
# Should see libaws-cpp-sdk-transcribestreaming.so

# Check Makefile.am paths match your installation
grep "aws-sdk-cpp" Makefile.am

# If paths don't match, update Makefile.am with correct paths
```

**Error:** `aclocal: command not found`

```bash
# Install autotools
sudo apt-get install -y autoconf automake libtool  # Ubuntu/Debian
sudo yum install -y autoconf automake libtool      # CentOS/RHEL
```

### Performance issues

For high-volume deployments (100+ concurrent calls):

```bash
# Increase FreeSWITCH session limits
# Edit /etc/freeswitch/autoload_configs/switch.conf.xml
<param name="max-sessions" value="10000"/>
<param name="sessions-per-second" value="1000"/>

# Monitor system resources
top -p $(pidof freeswitch)

# Monitor AWS API usage
# Check AWS CloudWatch → Transcribe metrics

# Increase system limits
# Edit /etc/security/limits.conf
freeswitch soft nofile 999999
freeswitch hard nofile 999999
freeswitch soft core unlimited
freeswitch hard core unlimited
```

---

## Advanced Configuration

### Features Overview

| Feature | Default Status | External AWS Config Required | Notes |
|---------|---------------|------------------------------|-------|
| **PII Redaction** | ❌ Disabled | ❌ No | Enable via channel variable |
| **Partial Results Stabilization** | ✅ Enabled | ❌ No | Can be disabled if needed |
| **Auto Punctuation** | ✅ Always On | ❌ No | Cannot be disabled |
| **Word Confidence Scores** | ✅ Always Included | ❌ No | Part of standard response |
| **Content Moderation** | ❌ Disabled | ⚠️ Yes | Requires vocabulary filter in AWS |
| **Custom Vocabulary** | ❌ Disabled | ⚠️ Yes | Requires vocabulary in AWS |
| **Speaker Diarization** | ❌ Disabled | ❌ No | Enable via channel variable |

### PII Redaction (Sensitive Data Protection)

**Automatically redacts Personally Identifiable Information (PII) from transcripts for privacy and compliance.**

**Enable PII Redaction:**

```xml
<!-- Redact all PII types (default) -->
<action application="set" data="AWS_CONTENT_REDACTION_TYPE=PII"/>
```

**Redact specific PII types:**

```xml
<action application="set" data="AWS_CONTENT_REDACTION_TYPE=PII"/>
<action application="set" data="AWS_PII_ENTITY_TYPES=CREDIT_DEBIT_NUMBER,SSN,NAME,PHONE"/>
```

**Supported PII Entity Types:**
- `ALL` - All PII types (default)
- `BANK_ACCOUNT_NUMBER` - Bank account numbers
- `BANK_ROUTING` - Bank routing numbers
- `CREDIT_DEBIT_NUMBER` - Credit/debit card numbers
- `CREDIT_DEBIT_CVV` - Card CVV codes
- `CREDIT_DEBIT_EXPIRY` - Card expiration dates
- `PIN` - Personal identification numbers
- `EMAIL` - Email addresses
- `ADDRESS` - Physical addresses
- `NAME` - Person names
- `PHONE` - Phone numbers
- `SSN` - Social security numbers

**Example:** Protect payment information

```xml
<extension name="payment_call">
  <condition field="destination_number" expression="^1000$">
    <!-- Enable PII redaction for payment info -->
    <action application="set" data="AWS_CONTENT_REDACTION_TYPE=PII"/>
    <action application="set" data="AWS_PII_ENTITY_TYPES=CREDIT_DEBIT_NUMBER,CREDIT_DEBIT_CVV,CREDIT_DEBIT_EXPIRY,PIN"/>
    <action application="set" data="AWS_SHOW_SPEAKER_LABEL=true"/>

    <action application="answer"/>
    <action application="inline" data="aws_transcribe ${uuid} start en-US interim"/>
    <action application="playback" data="payment_prompt.wav"/>
  </condition>
</extension>
```

**Redacted output example:**
```
Original: "My credit card number is 4532-1234-5678-9010"
Redacted: "My credit card number is [CREDIT_DEBIT_NUMBER]"
```

**Notes:**
- PII redaction is performed by AWS in real-time
- No additional AWS configuration required
- Does NOT require external services
- Enabled per-call via channel variables
- Redaction happens before transcripts are returned

### Partial Results Stabilization

**Improves the quality and consistency of interim (partial) results.**

**Status:** ✅ **ENABLED BY DEFAULT**

This feature is automatically enabled for better interim transcription accuracy. It reduces "flipping" where interim results change significantly between updates.

**To disable (not recommended):**

```xml
<action application="set" data="AWS_ENABLE_PARTIAL_RESULTS_STABILIZATION=false"/>
```

**Benefits:**
- More stable interim results
- Less text "flipping" during real-time transcription
- Better user experience for live transcription displays
- No additional cost

**Notes:**
- Enabled by default - no configuration needed
- Only affects interim results, not final results
- Does NOT require external configuration
- Improves real-time transcription quality

### Content Moderation (Vocabulary Filtering)

**Filters inappropriate content or specific words from transcripts.**

**Requires:** AWS Vocabulary Filter created in AWS Console

**How to create a vocabulary filter:**

1. Go to AWS Console → Amazon Transcribe → Vocabulary filtering
2. Click "Create vocabulary filter"
3. Enter filter name (e.g., `profanity-filter`)
4. Choose language
5. Add words to filter (one per line)
6. Save filter

**Use in FreeSWITCH:**

```xml
<!-- Mask filtered words with [***] -->
<action application="set" data="AWS_VOCABULARY_FILTER_NAME=profanity-filter"/>
<action application="set" data="AWS_VOCABULARY_FILTER_METHOD=mask"/>
```

**Filter Methods:**
- `mask` - Replace filtered words with `[***]` (recommended)
- `remove` - Remove filtered words entirely
- `tag` - Keep words but tag them in output

**Example:**

```xml
<extension name="customer_service">
  <condition field="destination_number" expression="^8000$">
    <!-- Enable profanity filter -->
    <action application="set" data="AWS_VOCABULARY_FILTER_NAME=profanity-filter"/>
    <action application="set" data="AWS_VOCABULARY_FILTER_METHOD=mask"/>

    <action application="answer"/>
    <action application="inline" data="aws_transcribe ${uuid} start en-US interim"/>
  </condition>
</extension>
```

**Notes:**
- ⚠️ **Requires external AWS configuration** (must create vocabulary filter in AWS Console)
- Filter must be created in the same region as transcription
- Can filter profanity, competitor names, or any custom words
- Enabled per-call via channel variables

### Automatic Punctuation and Capitalization

**Status:** ✅ **ALWAYS ENABLED**

AWS Transcribe Streaming automatically adds punctuation and capitalization to transcripts. This feature is built-in and cannot be disabled.

**Benefits:**
- Professional, readable transcripts
- No manual editing needed
- Proper sentence structure
- Correct capitalization

**Example output:**
```
"Hello, my name is John. How can I help you today?"
```

**Notes:**
- Always enabled - no configuration needed
- Works with all languages supported by AWS Transcribe
- Does NOT require external configuration
- Included at no additional cost

### Word-Level Confidence Scores

**Status:** ✅ **ALWAYS INCLUDED**

AWS Transcribe includes confidence scores for each word in the transcript, helping you evaluate accuracy.

**Access confidence scores:**

Confidence scores are included in the raw AWS Transcribe response. Parse the JSON response to extract them:

```javascript
// Example: Processing transcription event
endpoint.on('aws_transcribe::transcription', (evt) => {
  const results = JSON.parse(evt.body);

  results.forEach(result => {
    if (result.alternatives && result.alternatives[0].items) {
      result.alternatives[0].items.forEach(item => {
        console.log(`Word: ${item.content}`);
        console.log(`Confidence: ${item.confidence}`);
        console.log(`Type: ${item.type}`); // pronunciation or punctuation
      });
    }
  });
});
```

**Confidence score range:** 0.0 to 1.0
- 0.9 - 1.0: High confidence
- 0.7 - 0.9: Medium confidence
- 0.0 - 0.7: Low confidence

**Use cases:**
- Quality assurance
- Identifying sections needing review
- Training custom vocabularies
- Analytics and reporting

**Notes:**
- Always included - no configuration needed
- Part of standard AWS Transcribe response
- Does NOT require external configuration
- Available for all transcription results

### Custom Vocabulary (Domain-Specific Terms)

**Improve accuracy for industry-specific terms, product names, or acronyms.**

**Requires:** AWS Custom Vocabulary created in AWS Console

**How to create a custom vocabulary:**

1. Go to AWS Console → Amazon Transcribe → Custom vocabulary
2. Click "Create vocabulary"
3. Enter vocabulary name (e.g., `medical-terms`)
4. Choose language
5. Add terms in one of these formats:
   - Text file with phrases
   - Table format (Phrase, IPA, SoundsLike, DisplayAs)
6. Save and wait for processing

**Use in FreeSWITCH:**

```xml
<action application="set" data="AWS_VOCABULARY_NAME=medical-terms"/>
```

**Example:**

```xml
<extension name="medical_transcription">
  <condition field="destination_number" expression="^9000$">
    <!-- Use medical vocabulary -->
    <action application="set" data="AWS_VOCABULARY_NAME=medical-terms"/>
    <action application="set" data="AWS_SHOW_SPEAKER_LABEL=true"/>

    <action application="answer"/>
    <action application="inline" data="aws_transcribe ${uuid} start en-US interim"/>
  </condition>
</extension>
```

**Notes:**
- ⚠️ **Requires external AWS configuration** (must create vocabulary in AWS Console)
- Vocabulary must be in "Ready" state before use
- Can contain up to 256,000 entries
- Improves recognition of specified terms

### Audio Formats

Supported sample rates:
- 8000 Hz (narrow-band)
- 16000 Hz (wide-band)
- 48000 Hz (ultra-wide-band)

FreeSWITCH will automatically resample audio to match AWS Transcribe requirements.

### Multiple Concurrent Transcriptions

You can run multiple transcriptions on the same call with different bug names:

```bash
aws_transcribe <UUID> start en-US interim mono bug1
aws_transcribe <UUID> start es-US interim mono bug2
```

---

## Next Steps

- Integrate with webhooks for real-time transcript delivery
- Add Pusher integration (see pusher-integration branch)
- Implement custom vocabulary for domain-specific terms
- Set up CloudWatch monitoring for AWS API usage
- Build analytics dashboard for transcription data

---

## Support

For issues and questions:
- FreeSWITCH: https://freeswitch.org/confluence/
- AWS Transcribe: https://docs.aws.amazon.com/transcribe/
- Module issues: https://github.com/srthorat/freeswitch_modules/issues

---

## License

Same as FreeSWITCH (MPL 1.1)
