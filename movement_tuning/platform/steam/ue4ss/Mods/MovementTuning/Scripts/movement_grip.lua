-- Realism, Realistic (Kevin, 9 November 2026): no sideways glide in turns. The game pushes the character along the
-- body's facing (RealismProbe: the acceleration at 0 deg from the body in every turn) and turns the body toward the
-- stick at 500 deg/s, and the speed swings toward the facing at GroundFriction a second (Unreal's CalcVelocity: the
-- velocity turned toward the acceleration by min(dt x friction, 1) each frame); the game's friction is 5, 6 in its
-- sprint. So the movement lags behind the body: 23 to 47 deg in the game's own turns, 39 to 44 at x1.5 (verified in
-- game, 10 November 2026). That formula, run frame by frame, gives 30 to 53 deg for the game's own friction, and
-- under 9 deg at 144 frames a second (4 at 60) for GRIP times it. GroundFriction is read only for that: the game
-- brakes with a friction of its own (bUseSeparateBrakingFriction on, verified in game), so stops keep their braking
-- (movement_brake.lua), and the game ignores the stick during a dodge or an exit animation (movement_dodge.lua), so
-- they are not bent. Held on the ground, on the game's own value (movement_held.lua).

local U = require("movement_unreal")
local Held = require("movement_held")

local M = {}

local WALKING = U.WALKING
local FIELD, GRIP = "GroundFriction", 8
-- The first turns measured, for the log: the body turning faster than TURN_FROM deg/s above MOVING cm/s, until it
-- turns slower than TURN_UNTIL for SETTLE s, the speed falls under MOVING, or a frame lasts over U.PAUSE s.
-- MAX_TURN_LINES for each Realism choice, to compare them in one session.
local MAX_TURN_LINES = 6
local TURN_FROM, TURN_UNTIL, SETTLE, MOVING = 200, 30, 0.15, 300

-- held: the grip the mod holds (kept for a character given back: see movement_brake.lua's forget). broken: the grip
-- cannot be read or written, said once. yaw, at: the body's facing and the clock at the last frame measured. turn: the
-- turn being measured; lines: turns written to the log.
local G = { held = Held.new(), lines = 0 }

function M.forget()
	G.broken, G.yaw, G.at, G.turn = false, nil, nil, nil
end
M.forget()

function M.release(cmc)
	Held.release(G.held, cmc)
	G.yaw, G.turn = nil, nil
end

function M.holding()
	return Held.holding(G.held)
end

-- Whether the turns are still measured: the body's facing and the velocity are then read (movement_realism.lua).
function M.measuring()
	return G.lines < MAX_TURN_LINES
end

-- Another Realism choice: its own turn lines.
function M.new_level()
	G.lines, G.turn = 0, nil
end

-- The turn's time ends at its last frame still turning: the SETTLE that ends it is not part of it.
local function finish(t, speed, say)
	G.turn, G.lines = nil, G.lines + 1
	say("turn: body turned %.0f deg in %.2f s (fastest %.0f deg/s), widest slip %.0f deg, speed %.0f -> %.0f (grip %.0f "
		.. "times the game's)", t.turned, t.last - t.start, t.fastest, t.widest, t.from, speed, GRIP)
end

-- f: this frame's body facing and velocity (movement_realism.lua), nil fields when unread.
local function measure(f, now, say)
	if G.lines >= MAX_TURN_LINES then return end
	local yaw, speed = f.yaw, f.speed
	local last, at = G.yaw, G.at
	G.yaw, G.at = yaw, now
	if yaw == nil or speed == nil or last == nil or now <= at or now - at > U.PAUSE then
		G.turn = nil
		return
	end
	local step = math.abs(U.angle(yaw, last))
	local rate = step / (now - at)
	local slip = speed >= 1 and math.abs(U.angle(math.deg(math.atan(f.vy, f.vx)), yaw)) or 0
	local t = G.turn
	if t == nil then
		if rate >= TURN_FROM and speed >= MOVING then
			G.turn = { start = at, last = now, from = speed, turned = step, fastest = rate, widest = slip, quiet = nil }
		end
		return
	end
	t.turned, t.widest, t.fastest = t.turned + step, math.max(t.widest, slip), math.max(t.fastest, rate)
	if speed < MOVING then return finish(t, speed, say) end
	if rate >= TURN_UNTIL then
		t.quiet, t.last = nil, now
	elseif t.quiet == nil then
		t.quiet = now
	elseif now - t.quiet >= SETTLE then
		finish(t, speed, say)
	end
end

-- on: Realism asks for the grip. Held on the ground only: in the air or a special move the game's value is back.
function M.frame(cmc, mode, on, now, say, f)
	if cmc == nil then return end
	on = on and mode == WALKING and not G.broken
	if on and not Held.hold(G.held, cmc, FIELD, GRIP) then
		G.broken, on = true, false
		say("the ground grip cannot be changed: turns keep the game's grip")
	end
	if not on then return M.release(cmc) end
	measure(f, now, say)
end

return M
