--[[
  transcribe_start.lua

  Automatically starts AWS Transcribe when a call is answered

  Place this file in: /usr/share/freeswitch/scripts/transcribe_start.lua

  Usage in dialplan:
  <action application="bridge" data="{api_on_answer='lua transcribe_start.lua'}user/${destination_number}@${domain_name}"/>

  Features:
  - Retrieves caller and callee information
  - Maps caller to speaker 0, callee to speaker 1
  - Starts stereo transcription with interim results
  - Sends real-time transcripts to Pusher
]]

-- Ensure session is available
if not session then
    freeswitch.consoleLog("ERR", "No session available for transcription\n")
    return
end

-- Get call UUID
local uuid = session:getVariable("uuid")
if not uuid then
    freeswitch.consoleLog("ERR", "No UUID available for transcription\n")
    return
end

-- Get caller information
local caller_number = session:getVariable("caller_id_number") or "Unknown"
local caller_name = session:getVariable("caller_id_name") or caller_number

-- Get callee information
local callee_number = session:getVariable("callee_id_number") or
                     session:getVariable("destination_number") or
                     "Unknown"
local callee_name = session:getVariable("callee_id_name") or callee_number

-- Log call information
freeswitch.consoleLog("INFO", "====================================================\n")
freeswitch.consoleLog("INFO", "Starting AWS Transcribe for call: " .. uuid .. "\n")
freeswitch.consoleLog("INFO", "Caller: " .. caller_name .. " <" .. caller_number .. ">\n")
freeswitch.consoleLog("INFO", "Callee: " .. callee_name .. " <" .. callee_number .. ">\n")
freeswitch.consoleLog("INFO", "Pusher Channel: transcription-" .. uuid .. "\n")
freeswitch.consoleLog("INFO", "====================================================\n")

-- Build speaker metadata
-- Speaker 0 = Caller (left channel in stereo)
-- Speaker 1 = Callee (right channel in stereo)
local speakers = {
    speakers = {
        "Caller: " .. caller_name .. " (" .. caller_number .. ")",
        "Callee: " .. callee_name .. " (" .. callee_number .. ")"
    }
}

-- Convert to JSON using cjson library
local cjson = require("cjson")
local speaker_json = cjson.encode(speakers)

-- Build API command
-- Format: aws_transcribe <uuid> start <lang-code> [interim] [stereo] [bugname] [metadata]
local api_cmd = string.format(
    "aws_transcribe %s start en-US interim stereo transcribe_bug %s",
    uuid,
    speaker_json
)

-- Log the command
freeswitch.consoleLog("INFO", "Executing: " .. api_cmd .. "\n")

-- Execute API command
local api = freeswitch.API()
local result = api:executeString(api_cmd)

-- Log result
if result then
    freeswitch.consoleLog("INFO", "Transcription started successfully: " .. result .. "\n")

    -- Store UUID in channel variables for web app retrieval
    session:setVariable("transcription_uuid", uuid)
    session:setVariable("transcription_channel", "transcription-" .. uuid)
    session:setVariable("transcription_status", "active")
else
    freeswitch.consoleLog("ERR", "Failed to start transcription\n")
    session:setVariable("transcription_status", "failed")
end

-- Optional: Set up hangup hook to stop transcription
session:setHangupHook("transcription_hangup_handler")

function transcription_hangup_handler(s, status)
    freeswitch.consoleLog("INFO", "Call ending, stopping transcription for: " .. uuid .. "\n")

    local stop_cmd = string.format("aws_transcribe %s stop", uuid)
    local api = freeswitch.API()
    api:executeString(stop_cmd)

    freeswitch.consoleLog("INFO", "Transcription stopped for: " .. uuid .. "\n")
end
