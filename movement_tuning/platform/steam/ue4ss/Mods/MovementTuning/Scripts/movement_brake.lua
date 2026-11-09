-- Stops without the slide (Kevin, 9 November 2026: sped up, "quand je m'arrete d'un coup, le personnage continue de
-- gliser sur 1 ou 2m"). The engine brakes a character with no input by a deceleration (BrakingDecelerationWalking)
-- plus a friction (GroundFriction x BrakingFrictionFactor) times the speed (Unreal's ApplyVelocityBraking), so a
-- faster character needs more room to stop: its stopping distance grows with the square of the speed for the first
-- part. At k times the game's speed, the deceleration x k^2 and the braking friction x k stop it over the game's own
-- distance, in 1/k of the game's time (v = k u, t = s / k gives the game's equation back). The game's stop animations
-- are fitted to its own distance (single source: another mod's notes). Only braking reads these two values; the
-- friction's own value, which turning also uses, is left alone. Not verified in game: the first stops are measured in
-- UE4SS.log, with or without the change. Like the ground speeds, the game's own values are built on, never the mod's.

local U = require("movement_unreal")

local M = {}

local WALKING = 1
local NEUTRAL = 1.001      -- a factor this close to 1 changes nothing
local SAME = 1e-3          -- a value this close to the one written is still the mod's
local FIELDS = { { name = "BrakingDecelerationWalking", power = 2 }, { name = "BrakingFrictionFactor", power = 1 } }
-- The first stops measured, for the log: a stick let go under LET_GO while faster than STOP_FROM, until the speed is
-- under STOPPED, the stick pushed again, or MAX_STOP seconds.
local MAX_STOP_LINES = 6
local LET_GO, STOP_FROM, STOPPED, MAX_STOP = 0.05, 300, 10, 3

-- base, written: each field's game value and the value the mod wrote, by name. broken: a field cannot be read or
-- written, said once. stop: the stop being measured; lines: stops written to the log.
local B = { base = {}, written = {}, lines = 0 }

-- A new character. What was written is kept: the same component given back (a cutscene, a restart) still holds the
-- mod's values, and reading them as the game's would scale them twice. Another component's values are not the mod's,
-- so they are taken as its game values.
function M.forget()
	B.broken, B.stop = false, nil
end
M.forget()

-- Gives the game its values back where the mod's are still in place.
function M.release(cmc)
	if next(B.written) == nil then return end
	for _, field in ipairs(FIELDS) do
		local written = B.written[field.name]
		if cmc ~= nil and written ~= nil then
			local cur = nil
			pcall(function() cur = U.num(cmc[field.name]) end)
			if cur ~= nil and math.abs(cur - written) <= SAME then
				pcall(function() cmc[field.name] = B.base[field.name] end)
			end
		end
	end
	B.base, B.written = {}, {}
end

-- One field at the game's value times k^power; false when it cannot be read or written.
local function hold(cmc, field, k)
	local name, cur = field.name, nil
	pcall(function() cur = U.num(cmc[name]) end)
	if cur == nil then return false end
	local written = B.written[name]
	if written == nil or math.abs(cur - written) > SAME then B.base[name] = cur end
	local want = B.base[name] * k ^ field.power
	if math.abs(cur - want) > SAME and not pcall(function() cmc[name] = want end) then return false end
	B.written[name] = want
	return true
end

local function speed_of(cmc)
	local v = nil
	pcall(function() v = cmc.Velocity end)
	local _, _, speed = U.flat(v)
	return speed
end

-- The speed is read only while the stick is let go, and only until the last stop measured.
local function measure(cmc, k, push, now, say)
	if B.lines >= MAX_STOP_LINES or push == nil then return end
	if push >= LET_GO then
		B.stop = nil
		return
	end
	local speed = speed_of(cmc)
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
			if not hold(cmc, field, k) then
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
	return next(B.written) ~= nil
end

return M
