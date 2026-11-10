-- The Realism row (Kevin, 9 November 2026): Realistic holds the turning grip (movement_grip.lua) and eases the speed's
-- drops (movement_downshift.lua, through movement_ground.lua); HyperRealistic adds a slower start, a slower body and
-- speed lost in sharp turns (movement_hyper.lua). The body's facing and the velocity are read here, once a frame for
-- both, and only while one of them needs them.

local U = require("movement_unreal")
local Grip = require("movement_grip")
local Hyper = require("movement_hyper")

local M = {}

-- F: this frame's readings; R: the ground speeds' part. Both reused, made once. level: the choice at the last frame.
local F, R = {}, { keep = 1 }
local level_was = nil

function M.forget()
	Grip.forget()
	Hyper.forget()
end

function M.holding()
	return Grip.holding() or Hyper.holding()
end

-- level: the Realism row's choice, nil when None or the mod is off; hyper: HyperRealistic chosen. factor: the ground
-- speeds' factor at the last frame (movement_ground.lua's factor_now), nil when the game's. Returns nil when off, else
-- what the ground speeds take (movement_ground.lua): keep, the share of the speed kept in a turn.
function M.frame(pawn, cmc, mode, level, hyper, now, say, factor)
	if level ~= level_was then
		level_was = level
		if level == nil then Hyper.calm() else Grip.new_level() end
	end
	local free = Hyper.hold(cmc, mode, hyper, say)
	F.yaw, F.vx, F.vy, F.speed, F.factor = nil, nil, nil, nil, factor
	if level ~= nil and cmc ~= nil and mode == U.WALKING and (free or Grip.measuring()) then
		F.yaw = U.yaw(pawn)
		F.vx, F.vy, F.speed = U.velocity(cmc)
	end
	Grip.frame(cmc, mode, level ~= nil, now, say, F)
	R.keep = Hyper.keep(hyper, free, now, say, F)
	return level ~= nil and R or nil
end

return M
