-- The sound of an air jump. The game plays its dodge sound from its compiled code, not from the dodge animations
-- (DodgeSoundProbe, 4 November 2026): played by the mod, the double and triple jumps were silent. So the mod posts
-- the game's Wwise sound events itself. One sound per jump: two played together did not sound like a dodge (test of
-- 4 November 2026).
--
-- The sounds go to an AkComponent of the mod's own, attached to the player under its own socket name, with its
-- volume set before each post. Posted on the player itself, they went to the player's own emitter ("Ak"), which the
-- game uses too, so lowering it would lower the game's sounds; the game's posts look for the socket None and never
-- land on the mod's emitter.

local U = require("dodge_jump_unreal")
local Objects = require("dodge_jump_objects")

local M = {}

local COMMON = "/Game/Wwise/Events/SFX/Combat/Special/Hero_Special/Hun/Common/"
local STATICS = "/Script/AkAudio.Default__AkGameplayStatics"
local STATICS_CLASS = "/Script/AkAudio.AkGameplayStatics"
local EVENT_CLASS = "/Script/AkAudio.AkAudioEvent"
local EMITTER_CLASS = "/Script/AkAudio.AkComponent"
local SOCKET = "DodgeJumpSound"

local function sound(dir, name, volume)
	return { event = dir .. name .. "." .. name, volume = volume }
end

-- The double jump's sound, then the triple jump's, picked by ear among the game's dodge sounds (4 November 2026).
-- Each with its volume (linear, 1 = as the game made it), which brings it to the loudness of the game's ground dodge,
-- measured on a recording of the PC's output.
local JUMPS = {
	sound(COMMON, "SFX_Combat_Hun_Common_Roll_Cloth_Short", 0.47),
	sound(COMMON, "SFX_Combat_Hun_Common_RollGround", 0.56),
}

local said = {}                   -- what was already logged, by text: each problem is said once
local own = { emitter = nil, pawn = nil, socket = nil }

local function once(log, text)
	if said[text] then return end
	said[text] = true
	log(text)
end

-- The mod's emitter on this player, made once per player. GetOrCreateAkComponent(AttachToComponent,
-- ComponentCreated, AttachPointName): UE4SS wants a table for the out flag, and gives back the emitter already on
-- the player under that socket if there is one. The kept emitter is handed to the game at each sound: its class is
-- checked as the objects found by path are (dodge_jump_objects.lua).
local function emitter(statics, pawn)
	local addr = U.address(pawn)
	if own.pawn == addr and Objects.usable(own.emitter, EMITTER_CLASS) then return own.emitter end
	own.emitter, own.pawn = nil, addr
	if own.socket == nil then pcall(function() own.socket = FName(SOCKET) end) end
	local root = nil
	pcall(function() root = pawn:K2_GetRootComponent() end)
	if not U.is_valid(root) or own.socket == nil then return nil end
	pcall(function() own.emitter = statics:GetOrCreateAkComponent(root, {}, own.socket) end)
	if not Objects.usable(own.emitter, EMITTER_CLASS) then own.emitter = nil end
	return own.emitter
end

-- UE4SS refuses a call without every parameter, and the callback must be nil: an empty table there goes through a
-- UE4SS defect (push_delegateproperty) that can crash the game, which it did on 4 November 2026 at 4:27.
local function post(e, c, volume)
	return (pcall(function()
		c:SetOutputBusVolume(volume)
		return e:PostOnComponent(c, nil, 0, false)
	end))
end

-- Plays the sound of an air jump for the player, which: 1 for a double jump, 2 for a triple jump, at share (0 to 1)
-- of its volume. Returns 1 when posted, 0 otherwise. At 0, nothing of the game is looked up.
function M.play(pawn, which, share, log)
	local s = JUMPS[which]
	if s == nil or share <= 0 then return 0 end
	local statics = Objects.find(STATICS, STATICS_CLASS)
	if statics == nil then
		once(log, "the game's sound engine (Wwise) was not found: air jumps stay silent")
		return 0
	end
	local e = Objects.find(s.event, EVENT_CLASS)
	if e == nil then
		once(log, string.format("sound %s not loaded: not played", s.event:match("([^%.]+)$")))
		return 0
	end
	local c = emitter(statics, pawn)
	if c == nil then
		once(log, "the mod's sound emitter could not be made: air jumps stay silent")
		return 0
	end
	if post(e, c, s.volume * share) then return 1 end
	once(log, "the game refused to play an air jump sound; said once")
	return 0
end

-- A new pawn: its emitter is asked again (GetOrCreateAkComponent gives back the one already under the socket).
function M.forget()
	own.emitter, own.pawn = nil, nil
end

return M
