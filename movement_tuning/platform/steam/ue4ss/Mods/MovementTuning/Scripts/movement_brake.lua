-- Stops without the slide (Kevin, 9 November 2026: sped up, "when I stop at once, the character goes on sliding for 1
-- or 2 m"). The engine brakes a character with no input by a deceleration (BrakingDecelerationWalking)
-- plus a friction (BrakingFriction x BrakingFrictionFactor: the game brakes with a friction of its own,
-- bUseSeparateBrakingFriction on, verified in game) times the speed (Unreal's ApplyVelocityBraking), so a faster
-- character needs more room to stop: its stopping distance grows with the square of the speed for the first part. At
-- k times the game's speed, the deceleration x k^2 and the braking friction x k stop it over the game's own distance,
-- in 1/k of the game's time (v = k u, t = s / k gives the game's equation back). The game's stop animations are fitted
-- to its own distance (single source: another mod's notes). Only braking reads these two values; GroundFriction, which
-- only turning reads, is the grip's (movement_grip.lua). The first stops are measured in UE4SS.log. The game's own
-- values are built on, never the mod's (movement_held.lua). Slower than the game (under 1), the game's braking stays: a
-- slower character stops sooner, as the game's own walk does, while a braking x k^2 would make it slide over the
-- distance of a stop at the game's speed.

local U = require("movement_unreal")
local Held = require("movement_held")

local M = {}

local WALKING = U.WALKING
local NEUTRAL = 1.001      -- a factor this close to 1 changes nothing
local FIELDS = { { name = "BrakingDecelerationWalking", power = 2 }, { name = "BrakingFrictionFactor", power = 1 } }
-- The first stops measured, for the log: a stick let go under LET_GO while faster than STOP_FROM, until the speed is
-- under STOPPED, the stick pushed again, or MAX_STOP seconds.
local MAX_STOP_LINES = 6
local LET_GO, STOP_FROM, STOPPED, MAX_STOP = 0.05, 300, 10, 3

-- held: the values the mod holds. broken: a field cannot be read or written, said once. stop: the stop being
-- measured; lines: stops written to the log.
local B = { held = Held.new(), lines = 0 }

-- A new character. What was written is kept: the same component given back (a cutscene, a restart) still holds the
-- mod's values, and reading them as the game's would scale them twice. Another component's values are not the mod's,
-- so they are taken as its game values.
function M.forget()
	B.broken, B.stop = false, nil
end
M.forget()

-- Gives the game its values back where the mod's are still in place.
function M.release(cmc)
	Held.release(B.held, cmc)
end

-- The speed is read only while the stick is let go, and only until the last stop measured.
local function measure(cmc, k, push, now, say)
	if B.lines >= MAX_STOP_LINES or push == nil then return end
	if push >= LET_GO then
		B.stop = nil
		return
	end
	local _, _, speed = U.velocity(cmc)
	if speed == nil then return end
	local s = B.stop
	if s == nil then
		if speed > STOP_FROM then B.stop = { from = speed, start = now, last = now, dist = 0, k = k } end
		return
	end
	s.dist, s.last = s.dist + speed * (now - s.last), now
	if speed < STOPPED or now - s.start > MAX_STOP then
		B.stop, B.lines = nil, B.lines + 1
		say("stop: from %.0f, %.0f cm in %.2f s%s", s.from, s.dist, now - s.start,
			s.k and string.format(" (braking for %.2f times the game's speed)", s.k) or " (the game's braking)")
	end
end

-- cmc, mode: the movement component and its MovementMode. k: how many times the game's speed the mod gives (the ground
-- speeds' factor, nil when the mod leaves the speed to the game: the ground speeds alone decide in which movements, on
-- the ground and in the air). push: the left stick's, nil when unread.
function M.frame(cmc, mode, k, push, now, say)
	if cmc == nil then return end
	local on = k ~= nil and k > NEUTRAL and not B.broken
	if on then
		for _, field in ipairs(FIELDS) do
			if not Held.hold(B.held, cmc, field.name, k ^ field.power) then
				B.broken, on = true, false
				say("the braking cannot be changed (%s): stops keep the game's braking", field.name)
				break
			end
		end
	end
	if not on then M.release(cmc) end
	if mode == WALKING then measure(cmc, on and k or nil, push, now, say) else B.stop = nil end
end

function M.holding()
	return Held.holding(B.held)
end

return M
