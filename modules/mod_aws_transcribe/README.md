# mod_aws_transcribe

A Freeswitch module that generates real-time transcriptions on a Freeswitch channel by using AWS streaming transcription API with integrated Pusher support for real-time delivery to web/mobile clients.

## Quick Links

- **[Installation Guide](INSTALL.md)** - Complete step-by-step installation instructions
- **[Example Configurations](examples/)** - FreeSWITCH dialplan and web client examples
- **[API Reference](#api)** - Complete API documentation

## Features

- Real-time speech-to-text transcription using AWS Transcribe
- Speaker diarization with custom speaker name mapping
- Integrated Pusher REST API support for real-time transcript delivery
- Support for interim and final transcription results
- Stereo/mono audio support with speaker channel isolation
- Voice Activity Detection (VAD)
- Custom vocabulary and filtering
- HTTP/2 connection pooling for high-volume concurrent calls

## API

### Commands
The freeswitch module exposes the following API commands:

```
aws_transcribe <uuid> start <lang-code> [interim] [stereo|mono] [bugname] [{"speakers":["Name1","Name2"]}]
```
Attaches media bug to channel and performs streaming recognize request.
- `uuid` - unique identifier of Freeswitch channel
- `lang-code` - a valid AWS [language code](https://docs.aws.amazon.com/transcribe/latest/dg/what-is-transcribe.html) that is supported for streaming transcription
- `interim` - If the 'interim' keyword is present then both interim and final transcription results will be returned; otherwise only final transcriptions will be returned
- `stereo|mono` - Audio channel mode (optional, default: mono)
- `bugname` - Custom media bug name (optional)
- `{"speakers":[...]}` - JSON metadata with speaker names (optional, requires AWS_SHOW_SPEAKER_LABEL to be set)

**Example with speaker names:**
```
aws_transcribe abc-123 start en-US interim stereo my_bug {"speakers":["John Doe","Jane Smith"]}
```

```
aws_transcribe <uuid> stop [bugname]
```
Stop transcription on the channel.

### AWS Authentication
The plugin will first look for channel variables, then environment variables. If neither are found, then the default AWS profile on the server will be used.

**Environment Variables:**

| Variable | Description |
| --- | ----------- |
| AWS_ACCESS_KEY_ID | The AWS access key ID |
| AWS_SECRET_ACCESS_KEY | The AWS secret access key |
| AWS_REGION | The AWS region |
| AWS_SESSION_TOKEN | AWS session token (for temporary credentials) |

**Channel Variables:**

All environment variables above can also be set as channel variables for per-call configuration.

Additional channel variables:

| Variable | Description |
| --- | ----------- |
| AWS_SHOW_SPEAKER_LABEL | Enable speaker diarization (set to any value) |
| AWS_ENABLE_CHANNEL_IDENTIFICATION | Enable channel-based speaker identification |
| AWS_VOCABULARY_NAME | Custom vocabulary name |
| AWS_VOCABULARY_FILTER_NAME | Vocabulary filter name |
| AWS_VOCABULARY_FILTER_METHOD | Filtering method (mask/remove/tag) |

### Pusher Integration

The module includes built-in Pusher REST API integration for real-time transcript delivery to web/mobile clients. Uses HTTP/2 connection pooling for optimal performance with thousands of concurrent calls.

**Environment Variables:**

| Variable | Description |
| --- | ----------- |
| PUSHER_APP_ID | Pusher application ID |
| PUSHER_KEY | Pusher application key |
| PUSHER_SECRET | Pusher application secret |
| PUSHER_CLUSTER | Pusher cluster (e.g., us2, eu, ap1, ap2) |

**How it works:**
1. Uses Pusher REST API with HMAC-SHA256 authentication
2. Transcriptions are automatically sent to Pusher channel `transcription-{uuid}`
3. Speaker labels (spk_0, spk_1) are mapped to real names from the JSON metadata
4. Events are sent with event name `transcript` via HTTP/2
5. HTTP/2 multiplexing allows efficient handling of thousands of concurrent calls

**Pusher Payload Format:**
```json
{
  "session_id": "abc-123-def",
  "is_final": true,
  "timestamp": "",
  "segments": [
    {
      "speaker_name": "John Doe",
      "speaker_label": "spk_0",
      "text": "Hello, how can I help you today?"
    },
    {
      "speaker_name": "Jane Smith",
      "speaker_label": "spk_1",
      "text": "I need help with my account"
    }
  ]
}
```


### Events
`aws_transcribe::transcription` - returns an interim or final transcription.  The event contains a JSON body describing the transcription result:
```js
[
  {
    "is_final": true,
    "alternatives": [{
      "transcript": "Hello. Can you hear me?"
    }]
  }
]
```

## Usage

### Basic Usage
When using [drachtio-fsrmf](https://www.npmjs.com/package/drachtio-fsmrf), you can access this API command via the api method on the 'endpoint' object.
```js
ep.api('aws_transcribe', `${ep.uuid} start en-US interim`);
```

### With Speaker Diarization
Enable speaker diarization and provide speaker names:
```js
// Set channel variable to enable speaker labels
ep.set('AWS_SHOW_SPEAKER_LABEL', 'true');

// Start transcription with speaker names
const speakers = {speakers: ["Agent: John Doe", "Customer: Jane Smith"]};
ep.api('aws_transcribe', `${ep.uuid} start en-US interim stereo mybug ${JSON.stringify(speakers)}`);
```

### Speaker Mapping in Stereo Mode

When using **stereo mode** with speaker diarization, the speaker mapping is **deterministic and consistent**:

**Audio Channels:**
- **Left channel (0)** = Caller's audio
- **Right channel (1)** = Callee's audio

**AWS Speaker Labels:**
- `spk_0` = Speaker from left channel = **Caller**
- `spk_1` = Speaker from right channel = **Callee**

**Speaker Names Array Mapping:**
```json
{
  "speakers": [
    "Caller: John Doe (1000)",    // Index 0 → mapped to spk_0 (left channel/caller)
    "Callee: Jane Smith (1001)"   // Index 1 → mapped to spk_1 (right channel/callee)
  ]
}
```

**Important:**
- Array index 0 **always** corresponds to the **caller** (left channel, spk_0)
- Array index 1 **always** corresponds to the **callee** (right channel, spk_1)
- This mapping is guaranteed when using stereo mode
- The module automatically maps AWS speaker labels to your provided names

**Example in FreeSWITCH dialplan:**
```xml
<!-- Caller = 1000, Callee = 1001 -->
<action application="set"><![CDATA[data="speaker_meta={\"speakers\":[\"Caller: ${caller_id_name} (${caller_id_number})\",\"Callee: ${callee_id_name} (${callee_id_number})\"]}"]]></action>
```

**Result in Pusher transcript:**
```json
{
  "segments": [
    {
      "speaker_label": "spk_0",
      "speaker_name": "Caller: John Doe (1000)",  // Always the caller
      "text": "Hello, this is John calling"
    },
    {
      "speaker_label": "spk_1",
      "speaker_name": "Callee: Jane Smith (1001)",  // Always the callee
      "text": "Hi John, how can I help?"
    }
  ]
}
```

### Understanding Pusher Channels

**One channel per call:**
- Each call creates a unique Pusher channel: `transcription-{uuid}`
- The UUID is the FreeSWITCH call UUID (unique for each call)
- Example: `transcription-abc123-def456-789`

**Multiple subscribers:**
- Multiple web clients can subscribe to the **same** channel
- All subscribers receive the **same** real-time transcripts
- Useful for:
  - Supervisor monitoring
  - Multiple agents viewing the same call
  - Recording/compliance systems
  - Analytics dashboards

**Example scenarios:**

**Scenario 1: Single call with multiple viewers**
- Extension 1000 calls 1001
- Call UUID: `abc-123`
- Pusher channel: `transcription-abc-123`
- Subscribers:
  - Caller's web app (1000)
  - Callee's web app (1001)
  - Supervisor dashboard
- All three receive the **same** real-time transcript

**Scenario 2: Multiple concurrent calls**
- Call 1: 1000 → 1001, UUID: `abc-123`, Channel: `transcription-abc-123`
- Call 2: 1002 → 1003, UUID: `def-456`, Channel: `transcription-def-456`
- Each call has its **own isolated** channel
- No cross-talk between channels

### Receiving Transcripts from Pusher (Frontend)
```javascript
const pusher = new Pusher('YOUR_PUSHER_KEY', {
  cluster: 'YOUR_CLUSTER'
});

const channel = pusher.subscribe('transcription-' + sessionId);

// Bind to the transcript event
channel.bind('transcript', function(data) {
  console.log('Transcription received:', data);

  if (data.segments) {
    // With speaker diarization
    data.segments.forEach(segment => {
      console.log(`${segment.speaker_name}: ${segment.text}`);
    });
  }

  if (data.is_final) {
    console.log('Final transcript received');
  }
});
```

### Environment Setup
```bash
# AWS Configuration
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Pusher REST API Configuration (optional)
export PUSHER_APP_ID="your-pusher-app-id"
export PUSHER_KEY="your-pusher-app-key"
export PUSHER_SECRET="your-pusher-app-secret"
export PUSHER_CLUSTER="us2"  # or eu, ap1, ap2, ap3, ap4
```

## Building

### Dependencies

1. **AWS C++ SDK**: You can use [this ansible role](https://github.com/davehorton/ansible-role-fsmrf), or refer to the specific steps [here](https://github.com/davehorton/ansible-role-fsmrf/blob/a1947cc24e89dee7d6b42053c53295f9198340c1/tasks/grpc.yml#L28).

2. **libcurl with HTTP/2 support**: Required for Pusher REST API integration
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libcurl4-openssl-dev

   # CentOS/RHEL
   sudo yum install libcurl-devel

   # Verify HTTP/2 support
   curl --version | grep HTTP2
   ```

3. **OpenSSL**: Required for HMAC-SHA256 authentication (usually pre-installed)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libssl-dev

   # CentOS/RHEL
   sudo yum install openssl-devel
   ```

### Pusher Configuration

To use Pusher integration:
1. Go to your Pusher dashboard at https://dashboard.pusher.com/
2. Select or create your application
3. Note down your App ID, Key, Secret, and Cluster from the "App Keys" tab
4. Set the environment variables as shown in the Environment Setup section above
5. No special Pusher app settings are required (client events are NOT needed for REST API)

## Examples
[aws_transcribe.js](../../examples/aws_transcribe.js)