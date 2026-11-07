-- While a slide runs, only the slide steers the character: the game would turn the body toward the stick at its own
-- rotation rate (500°/s, MoveProbe) and bend the velocity with the stick's acceleration. The movement component's
-- MaxAcceleration and RotationRate are held at zero during the slide, and put back after.
-- This was added for a steering fault that Kevin never had (a misread of his report, 4 November 2026: steering
-- already worked). It costs about 7 calls to the engine a frame and is kept because the game writes both values again
-- every frame (second trial; 837 frames in one slide of 0.5.2): without it, the game would steer the body off the
-- slide's line, which it keeps (second trial: 0 to 5.5°). The value the game wrote last is the one put back.

local R = require("slide_reading")
local Trial = require("slide_trial")

local M = {}

local ZERO = { Pitch = 0, Yaw = 0, Roll = 0 }
local C = { held = nil }

local function rotation(cmc)
	local r = nil
	pcall(function()
		local raw = cmc.RotationRate
		r = { Pitch = R.num(raw.Pitch, 0), Yaw = R.num(raw.Yaw, nil), Roll = R.num(raw.Roll, 0) }
	end)
	if r == nil or r.Yaw == nil then return nil end
	return r
end

local function acceleration(cmc)
	local a = nil
	pcall(function() a = R.num(cmc.MaxAcceleration, nil) end)
	return a
end

function M.hold(say, cmc)
	local acc, rot = acceleration(cmc), rotation(cmc)
	C.held = { cmc = cmc, acc = acc, rot = rot, rewritten = 0 }
	if Trial.open() then
		Trial.say("game steering held: MaxAcceleration %s RotationRate.Yaw %s -> 0", R.f(acc), R.f(rot and rot.Yaw))
	end
end

-- Every frame of the slide, before the movement component runs.
function M.frame()
	local h = C.held
	if h == nil or not R.is_valid(h.cmc) then return end
	local acc, rot = acceleration(h.cmc), rotation(h.cmc)
	if (acc ~= nil and acc ~= 0) or (rot ~= nil and rot.Yaw ~= 0) then
		if h.written then h.rewritten = h.rewritten + 1 end
		if acc ~= nil and acc ~= 0 then h.acc = acc end
		if rot ~= nil and rot.Yaw ~= 0 then h.rot = rot end
	end
	if h.acc ~= nil then pcall(function() h.cmc.MaxAcceleration = 0 end) end
	if h.rot ~= nil then pcall(function() h.cmc.RotationRate = ZERO end) end
	h.written = true
end

-- Returns how many frames the game wrote its values again during the slide.
function M.release(say)
	local h = C.held
	C.held = nil
	if h == nil then return 0 end
	if not R.is_valid(h.cmc) then return h.rewritten end
	local ok = true
	if h.acc ~= nil then ok = pcall(function() h.cmc.MaxAcceleration = h.acc end) and ok end
	if h.rot ~= nil then ok = pcall(function() h.cmc.RotationRate = h.rot end) and ok end
	if not ok then say("game steering could not be put back") end
	return h.rewritten
end

return M
