-- Realism (Kevin, 9 November 2026): a run dropping to a walk, or a sprint to a run, in about DURATION s. With the stick
-- still pushed, the game drops its speed allowed (MaxWalkSpeed) at once and the engine brakes the character down to
-- it: 300 to 500 cm/s lost in 0.08 to 0.10 s (RealismProbe, 4 such drops, with and without the mod, verified in
-- game). The speed allowed, the one movement_ground.lua writes, comes down instead at a steady rate, so that the
-- engine's braking, which never takes the speed under the one allowed, follows it. Only while the stick is pushed on
-- the ground: a stop (the stick let go) brakes the engine's way whatever the speed allowed, and a speed held high after
-- a stop would let the next push run faster than the game allows; there, and in the air, the game's speed at once.

local U = require("movement_unreal")

local M = {}

local WALKING = U.WALKING
local DURATION = 0.4       -- seconds for a drop of the speed allowed, whatever its size
local SAME = 0.5           -- cm/s: a speed this close is the same
local MAX_LINES = 6        -- the first drops eased, written to the log

-- last, at: the speed returned at the last frame and its clock. from, start, rate: the drop being eased (its first
-- speed, its clock, cm/s a second), nil when none. lines: drops written to the log.
local D = { lines = 0 }

local function stop_easing()
	D.from, D.start, D.rate = nil, nil, nil
end

function M.forget()
	D.last, D.at = nil, nil
	stop_easing()
end
M.forget()

local function pushed(cmc)
	local _, _, size = U.acceleration(cmc)
	return size ~= nil and size > U.PUSHED
end

local function finish(want, cmc, now, say)
	if D.lines < MAX_LINES then
		D.lines = D.lines + 1
		local _, _, speed = U.velocity(cmc)
		say("downshift: speed allowed %.0f -> %.0f over %.2f s, speed now %s", D.from, want, now - D.start,
			speed and string.format("%.0f", speed) or "unread")
	end
	stop_easing()
end

-- want: the speed allowed this frame (movement_ground.lua's). Returns the one to write: want, or above it while a drop
-- is eased. The acceleration is read only during a drop.
function M.soften(want, cmc, mode, now, say)
	local last, at = D.last, D.at
	D.last, D.at = want, now
	local dt = at and now - at or 0
	if last == nil or want >= last - SAME or mode ~= WALKING or dt <= 0 or dt > U.PAUSE or not pushed(cmc) then
		stop_easing()
		return want
	end
	if D.from == nil then D.from, D.start, D.rate = last, at, 0 end
	-- A drop that goes on (the game eases its own over a few frames) quickens the rate: the rest in DURATION s.
	D.rate = math.max(D.rate, (last - want) / DURATION)
	local eased = last - D.rate * dt
	if eased <= want + SAME then
		finish(want, cmc, now, say)
		return want
	end
	D.last = eased
	return eased
end

return M
