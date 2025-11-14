# mod_aws_transcribe - AWS Speaker Diarization Support

This branch adds speaker diarization support to mod_aws_transcribe using AWS Transcribe's native speaker identification feature.

## Features Added

- Speaker metadata structure for mapping AWS speaker labels to real names
- JSON metadata parsing in API command
- Support for passing speaker names via API call
- Integration with AWS Transcribe speaker diarization

## API Usage

```
aws_transcribe <uuid> start <lang-code> [interim] [stereo|mono] [bugname] [{"speakers":["Name1","Name2"]}]
```

**Example:**
```
aws_transcribe abc-123 start en-US interim stereo my_bug {"speakers":["Caller: John Doe","Callee: Jane Smith"]}
```

## Speaker Mapping

When using stereo mode with speaker diarization:
- **spk_0** (left channel) = First name in speakers array (typically caller)
- **spk_1** (right channel) = Second name in speakers array (typically callee)

## Configuration

Enable speaker diarization by setting the channel variable:
```
AWS_SHOW_SPEAKER_LABEL=true
```

## Dependencies

- AWS C++ SDK for Transcribe Streaming
- FreeSWITCH with media bug support
- cJSON for JSON parsing

## Building

```bash
./configure --with-freeswitch-src=/path/to/freeswitch
make
sudo make install
```

## Notes

- This branch provides the foundation for speaker diarization
- Speaker metadata is passed through the response handler for custom processing
- Can be used standalone or extended with additional integrations (e.g., Pusher, webhooks)
