-- The slide's sound: the game's own ground slide sounds for its character (Wwise events found in the game's files on
-- 4 November 2026), posted by the mod, as the slide played by the mod is silent. Kevin, 6 November 2026: no
-- publication without them. At the start, the start sound and the loop; at the end, the loop's stop and, when the
-- slide ends on the ground, the end sound.
-- As in Dodge Jump's dodge_jump_sound.lua: the sounds go to an emitter (AkComponent) of the mod's own, attached to the
-- player under its own socket name, so the player's own emitter, which the game uses too, is never touched. An event
-- is played only when the game already holds it: loading it ourselves froze the game (slide_sets.lua).

local R = require("slide_reading")

local M = {}

local DIR = "/Game/Wwise/Events/SFX/Move/Hero/InUse/SFX_Footsteps_Hun_Slide_Ground_"
local STATICS = "/Script/AkAudio.Default__AkGameplayStatics"
local STATICS_CLASS = "/Script/AkAudio.AkGameplayStatics"
local EVENT_CLASS = "/Script/AkAudio.AkAudioEvent"
local EMITTER_CLASS = "/Script/AkAudio.AkComponent"
local SOCKET = "SlideAnywhereSound"
local VOLUME = 1                  -- linear, 1 = as the game made it

local function event(name)
	local path = DIR .. name
	return path .. "." .. path:match("([^/]+)$")
end

local EVENTS = { start = event("Start"), loop = event("Loop"), stop = event("Loop_Stop"), finish = event("End") }

-- kept: the objects found, by path; emitter: the mod's emitter on the player, forgotten at each new pawn; looping: the
-- loop was posted and not stopped yet.
local S = { kept = {}, emitter = nil, socket = nil, looping = false, said = {} }

local function once(say, text)
	if S.said[text] then return end
	S.said[text] = true
	say("%s", text)
end

-- The object at path if it is of class, nil otherwise. Checked again at each use: the kept one may be gone, and
-- another object may sit at its address (slide_reading.lua's usable).
local function find(path, class)
	if R.usable(S.kept[path], class) then return S.kept[path] end
	local obj = nil
	pcall(function() obj = StaticFindObject(path) end)
	if not R.usable(obj, class) then obj = nil end
	S.kept[path] = obj
	return obj
end

-- The mod's emitter on this player, made once per player (main.lua calls M.forget for a new one).
-- GetOrCreateAkComponent(AttachToComponent, ComponentCreated, AttachPointName): UE4SS wants a table for the out flag,
-- and gives back the emitter already under that socket if there is one.
local function emitter(statics, pawn)
	if R.usable(S.emitter, EMITTER_CLASS) then return S.emitter end
	S.emitter = nil
	if S.socket == nil then pcall(function() S.socket = FName(SOCKET) end) end
	local root = nil
	pcall(function() root = pawn:K2_GetRootComponent() end)
	if not R.is_valid(root) or S.socket == nil then return nil end
	pcall(function() S.emitter = statics:GetOrCreateAkComponent(root, {}, S.socket) end)
	if not R.usable(S.emitter, EMITTER_CLASS) then S.emitter = nil end
	return S.emitter
end

-- UE4SS refuses a call without every parameter, and the callback must be nil: an empty table there goes through a
-- UE4SS defect that crashed the game (Dodge Jump, 4 November 2026).
local function post(say, c, which)
	local e = find(EVENTS[which], EVENT_CLASS)
	if e == nil then
		once(say, string.format("sound %s not in memory: not played", EVENTS[which]:match("([^%.]+)$")))
		return false
	end
	local ok = pcall(function()
		c:SetOutputBusVolume(VOLUME)
		return e:PostOnComponent(c, nil, 0, false)
	end)
	if not ok then once(say, "the game refused to play a slide sound; said once") end
	return ok
end

-- The emitter to post on now, or nil (said once).
local function ready(say, pawn)
	local statics = find(STATICS, STATICS_CLASS)
	if statics == nil then
		once(say, "the game's sound engine (Wwise) was not found: the slides stay silent")
		return nil
	end
	local c = emitter(statics, pawn)
	if c == nil then once(say, "the mod's sound emitter could not be made: the slides stay silent") end
	return c
end

-- A slide starts on pawn.
function M.start(say, pawn)
	local c = ready(say, pawn)
	if c == nil then return end
	post(say, c, "start")
	S.looping = post(say, c, "loop")
end

-- The slide is over: the loop stops; ended: on the ground, by itself or by the player, so the end sound plays too.
-- Only the emitter already made is used: the player it is on may be gone.
function M.stop(say, ended)
	local c = S.emitter
	local looping = S.looping
	S.looping = false
	if not R.usable(c, EMITTER_CLASS) then return end
	if looping then post(say, c, "stop") end
	if ended then post(say, c, "finish") end
end

-- A new pawn: what the last level held may be gone, and its emitter is asked again.
function M.forget()
	S.kept, S.emitter, S.looping = {}, nil, false
end

return M
