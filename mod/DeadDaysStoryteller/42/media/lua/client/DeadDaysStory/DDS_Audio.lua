-- Client audio: radio SFX and character voice lines.
-- Voice lines are optional: they exist only if the ElevenLabs generator has
-- been run for this world's story (see tools/Generate-Voices.ps1), which also
-- writes DDS_VoiceManifest so we never ask the engine for a missing sound.

require "DeadDaysStory/DDS_Core"

DDS.Audio = DDS.Audio or { staticHandle = nil, voiceHandle = nil }
local A = DDS.Audio

local function sm()
    local ok, m = pcall(getSoundManager)
    return ok and m or nil
end

function A.play(name)
    local m = sm()
    if m == nil then return nil end
    local ok, handle = pcall(function() return m:playUISound(name) end)
    return ok and handle or nil
end

function A.stop(handle)
    local m = sm()
    if m == nil or handle == nil then return end
    pcall(function() m:stopUISound(handle) end)
end

function A.incomingCall()
    A.play("DDSRadioIncoming")
end

-- A radio conversation opened / closed.
function A.radioOpen()
    A.play("DDSRadioOpen")
    if A.staticHandle == nil then A.staticHandle = A.play("DDSRadioStatic") end
end

function A.radioClose()
    A.stopVoice()
    if A.staticHandle then A.stop(A.staticHandle); A.staticHandle = nil end
    A.play("DDSRadioClose")
end

function A.stopVoice()
    if A.voiceHandle then A.stop(A.voiceHandle); A.voiceHandle = nil end
end

-- Play a character's line if it was generated for this world.
function A.voice(voiceId)
    A.stopVoice()
    if voiceId == nil then return false end
    local manifest = DDS.VoiceManifest
    if type(manifest) ~= "table" or not manifest[voiceId] then return false end
    A.voiceHandle = A.play("DDSVoice_" .. voiceId)
    return A.voiceHandle ~= nil
end

-- Buddy banter and other one-off lines sent by the server.
DDS.Net.onClient("voice", function(args)
    if args and args.id and not (DDS.UI and DDS.UI.Dialogue and DDS.UI.Dialogue.instance
            and DDS.UI.Dialogue.instance:isVisible()) then
        A.voice(args.id)
    end
end)

return A
