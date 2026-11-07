-- Plays the slide's montages on the player the way Dodge Jump plays the dodges (Montage_Play). Whether the montage
-- playing now is ours is told by its address. While our push moves the character, the animation's own motion is
-- ignored (RootMotionMode 1), or it would take over the movement; the mode the game had is put back when the slide
-- ends, whatever ends it.

local R = require("slide_reading")
local Trial = require("slide_trial")

local M = {}

local MONTAGE_LENGTH = 0          -- EMontagePlayReturnType::MontageLength
local IGNORE_ROOT_MOTION = 1      -- ERootMotionMode
local BLEND = 0.2
local MONTAGE = "/Script/Engine.AnimMontage"

-- playing: the address of the montage we played last.
local A = { root = nil, playing = nil }

function M.anim(pawn)
	local anim = nil
	pcall(function() anim = pawn.Mesh:GetAnimInstance() end)
	return R.is_valid(anim) and anim or nil
end

-- Returns how long the montage lasts at its rate, or nil when it did not play. The montage was found when the slide
-- started and is handed to the game again at each loop: its class is checked first.
function M.play(anim, obj, entry)
	if not R.usable(obj, MONTAGE) then return nil end
	local length = nil
	pcall(function() length = R.num(anim:Montage_Play(obj, entry.rate, MONTAGE_LENGTH, 0, true), nil) end)
	if length == nil or length <= 0 then return nil end
	A.playing = R.address(obj)
	return length / entry.rate
end

-- The montage playing now, or nil, and whether it is the one we played last.
function M.current(anim)
	local m = nil
	pcall(function() m = anim:GetCurrentActiveMontage() end)
	if not R.is_valid(m) then return nil, false end
	return m, A.playing ~= nil and R.address(m) == A.playing
end

-- A montage's short name, for the log: read only when a line is written.
function M.name(m)
	return R.short(R.path(m))
end

function M.stop(anim)
	local m, ours = M.current(anim)
	if m ~= nil and ours then pcall(function() anim:Montage_Stop(BLEND, m) end) end
	A.playing = nil
end

function M.forget()
	A.playing = nil
end

function M.ignore_root_motion(say, anim)
	local before, after = nil, nil
	pcall(function() before = R.num(anim.RootMotionMode, nil) end)
	if before == nil then
		say("root motion mode not readable: the animation's own motion stays")
		return
	end
	local how = "SetRootMotionMode"
	local ok = pcall(function() anim:SetRootMotionMode(IGNORE_ROOT_MOTION) end)
	if not ok then
		how = "field"
		ok = pcall(function() anim.RootMotionMode = IGNORE_ROOT_MOTION end)
	end
	if not ok then
		say("the animation's own motion cannot be ignored: SetRootMotionMode and the field both failed")
	elseif Trial.open() then
		pcall(function() after = R.num(anim.RootMotionMode, nil) end)
		Trial.say("root motion mode %s -> %s by %s", R.f(before), R.f(after), how)
	end
	if ok then A.root = { anim = anim, mode = before, how = how } end
end

function M.restore_root_motion(say)
	local r = A.root
	A.root = nil
	if r == nil or not R.is_valid(r.anim) then return end
	local ok = false
	if r.how == "SetRootMotionMode" then ok = pcall(function() r.anim:SetRootMotionMode(r.mode) end) end
	if not ok then ok = pcall(function() r.anim.RootMotionMode = r.mode end) end
	if not ok then say("root motion mode could not be put back to %s", R.f(r.mode)) end
end

return M
