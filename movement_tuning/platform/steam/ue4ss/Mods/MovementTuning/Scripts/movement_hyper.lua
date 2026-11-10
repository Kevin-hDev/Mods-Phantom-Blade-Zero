-- Realism, HyperRealistic (Kevin, 9 November 2026; the values accepted on 10 November): Realistic, plus a slower start,
-- a body that turns slower and speed lost in sharp turns. Only while running freely, the game turning the body toward
-- the stick (RotationTargetProvider_LastMoveInput): under any other the game's values stay, as fights must not change
-- (a crouched dodge was turned down on 9 November for delaying the dodge). The game turns to RotationTargetProvider_
-- LockTarget with an enemy locked and to RotationTargetProvider_WeakFocus_C in fights (Tap Strafe's logs, 4 November
-- 2026, verified in game).
-- - Start: the game pushes at MaxAcceleration, 1000 while running, and reaches 90% of its run (540 of 600) in 0.52 to
--   0.58 s (RealismProbe, verified in game): held at ACCEL times the game's, starts take 1.5 times as long.
-- - Body: the engine turns it toward the stick at RotationRate.Yaw (orient to movement on), 500 deg/s at every gait
--   (verified in game): held at TURN times the game's, 330 deg/s.
-- - Turns: the body turning faster than GENTLE deg/s above MOVING cm/s loses speed, up to LOSS at its top rate. The loss
--   moves toward that by LOSS in RECOVER s, both ways: a lost speed comes back in RECOVER s, wherever the character
--   goes next (the air, a fight), since the speed itself was lost on the ground. The ground speeds take the share kept
--   (movement_ground.lua). A body turned faster than SNAP times its top rate was turned by the game at once (over 2,000
--   deg/s after a dodge, verified in game), not by the player.
-- Both values held on the game's own (movement_held.lua), on the ground only.

local U = require("movement_unreal")
local Held = require("movement_held")

local M = {}

local FREE = "RotationTargetProvider_LastMoveInput"
local ACCEL, TURN = 1 / 1.5, 0.66
local GAME_TURN = 500           -- the game's body turn rate (RealismProbe), the top rate when it cannot be held
local LOSS, RECOVER, GENTLE, MOVING, SNAP = 0.15, 0.5, 90, 300, 1.5
local MAX_CLASSES = 16          -- providers told apart by their class; more would be a fault: the list starts over
local MAX_LINES = 6             -- lines saying free running starts or ends
-- The first starts measured, for the log: from standing (under STILL cm/s) to START_TO cm/s, the 90% of its run that
-- RealismProbe timed in the game, dropped after START_LONGEST s, a stop, a pause or the end of free running.
local STILL, START_TO, START_LONGEST, MAX_START_LINES = 10, 540, 3, 6

local ROTATION = {
	get = function(cmc) return cmc.RotationRate.Yaw end,
	-- UE4SS writes a structure from a table of all its fields.
	set = function(cmc, _, v)
		local r = cmc.RotationRate
		cmc.RotationRate = { Pitch = r.Pitch, Yaw = v, Roll = r.Roll }
	end,
}
local FIELDS = {
	{ name = "MaxAcceleration", factor = ACCEL, broken = "the start's acceleration cannot be changed: starts keep the "
		.. "game's" },
	{ name = "RotationRate", factor = TURN, access = ROTATION, broken = "the body's turn rate cannot be changed: it "
		.. "keeps the game's" },
}

-- held: the values held (kept for a character given back, as movement_brake.lua's). broken: the fields that cannot be
-- held, said once. classes: each provider class seen (by address), its name. free: running freely at the last frame
-- on the ground. yaw, at: the body's facing and the clock at the last frame. loss: the share of the speed lost. start:
-- the start being measured; still: standing at the last frame.
local H = { held = Held.new(), lines = 0, start_lines = 0 }

function M.forget()
	H.broken, H.classes, H.count, H.free, H.yaw, H.at, H.loss, H.start, H.still = {}, {}, 0, nil, nil, nil, 0, nil, false
end
M.forget()

function M.holding()
	return Held.holding(H.held)
end

-- Realism off (None or the mod off): the share of the speed is no longer used, and a loss left would greet the next
-- Hyper realistic.
function M.calm()
	H.loss, H.yaw, H.at, H.start, H.still = 0, nil, nil, nil, false
end

local function provider_of(cmc) return cmc.CurrentPassiveRotationTargetProvider end

local function provider_name(cmc)
	local ok, p = pcall(provider_of, cmc)
	if not ok or not U.is_valid(p) then return nil end
	local addr = U.class_address(p, true)
	if addr == nil then return nil end
	local name = H.classes[addr]
	if name == nil then
		if H.count >= MAX_CLASSES then H.classes, H.count = {}, 0 end
		name = U.class_name(p) or "?"
		H.classes[addr], H.count = name, H.count + 1
	end
	return name
end

local function running_freely(cmc, say)
	local name = provider_name(cmc)
	local free = name == FREE
	if free ~= H.free then
		H.free = free
		if H.lines < MAX_LINES then
			H.lines = H.lines + 1
			say("hyper realistic: %s (body turned by %s)", free and "on" or "the game's start, body and turns",
				name or "nothing")
		end
	end
	return free
end

local function hold_field(cmc, field, say)
	if H.broken[field.name] then return end
	if not Held.hold(H.held, cmc, field.name, field.factor, field.access) then
		H.broken[field.name] = true
		say(field.broken)
	end
end

-- on: HyperRealistic chosen. Holds the two values while running freely on the ground and gives them back elsewhere;
-- returns whether the character runs freely. A frame without the movement component keeps what was written, as
-- movement_grip.lua and movement_brake.lua do: the same component back still holds the mod's values.
function M.hold(cmc, mode, on, say)
	if cmc == nil or (not on and not Held.holding(H.held)) then return false end
	local free = on and mode == U.WALKING and running_freely(cmc, say)
	if free then
		for i = 1, #FIELDS do hold_field(cmc, FIELDS[i], say) end
	else
		Held.release(H.held, cmc)
	end
	return free
end

local function measure_start(now, dt, speed, say)
	local s = H.start
	if s == nil then
		if H.still and speed >= STILL then H.start = { at = now - dt, cm = speed * dt } end
		H.still = speed < STILL
		return
	end
	if speed < STILL or now - s.at > START_LONGEST then
		H.start, H.still = nil, speed < STILL
		return
	end
	s.cm = s.cm + speed * dt
	if speed < START_TO then return end
	H.start, H.start_lines = nil, H.start_lines + 1
	local accel = H.held.written.MaxAcceleration
	say("start: 0 -> %.0f cm/s in %.2f s over %.0f cm (acceleration %s)", START_TO, now - s.at, s.cm,
		accel and string.format("%.0f, %.2f times the game's", accel, ACCEL) or "the game's")
end

local function share(free, last, dt, f)
	local target = 0
	if free and last ~= nil and f.yaw ~= nil and f.speed ~= nil and f.speed >= MOVING then
		local top = H.held.written.RotationRate or GAME_TURN
		local rate = math.abs(U.angle(f.yaw, last)) / dt
		-- A body held at GENTLE or under turns no faster than a wide curve: no turn is sharp enough to lose speed.
		if top > GENTLE and rate <= top * SNAP then
			target = LOSS * math.min(math.max((rate - GENTLE) / (top - GENTLE), 0), 1)
		end
	end
	local step = LOSS / RECOVER * dt
	H.loss = H.loss + math.min(math.max(target - H.loss, -step), step)
	return 1 - H.loss
end

-- on, free: HyperRealistic chosen, running freely (M.hold). f: this frame's body facing and speed
-- (movement_realism.lua). Returns the share of the speed kept, 1 when none is lost.
function M.keep(on, free, now, say, f)
	if not on and H.loss == 0 then
		H.at, H.yaw, H.start, H.still = nil, nil, nil, false
		return 1
	end
	if not free then H.start, H.still = nil, false end
	local last, at = H.yaw, H.at
	H.yaw, H.at = free and f.yaw or nil, now
	local dt = at and now - at or 0
	if dt <= 0 or dt > U.PAUSE then
		H.start = nil
		return 1 - H.loss
	end
	if free and f.speed ~= nil and H.start_lines < MAX_START_LINES then measure_start(now, dt, f.speed, say) end
	return share(free, last, dt, f)
end

return M
