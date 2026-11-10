-- Faster walking, running and sprinting: each frame, the speed the game just set (CharacterMovement.MaxWalkSpeed) is
-- multiplied by the setting of the gait it belongs to. The game eases MaxWalkSpeed from one gait to the next (600, 585,
-- 570..., verified in game), so between two gaits the factor slides from one setting to the other.
-- The gaits' own speeds are the player's attributes WalkSpeed, JogSpeed and SprintSpeed (BasicAttributeSet, game's type
-- map); anything above the sprint, such as the long sprint at 950, follows Sprint. With the left stick's curve on, the
-- game's speed is first lowered for a light push (movement_curve.lua), then multiplied.
-- The game rewrites MaxWalkSpeed every frame before the movement uses it, and the controller's tick, where the mod
-- writes, runs in between: the status lines count the game's rewrites, 62,628 for 62,628 writes in one session
-- (verified in game). Should the game leave the mod's speed in place, the mod builds on the game's last own speed,
-- never on its own. With Realism on, a drop of that speed is eased (movement_downshift.lua), even at the game's speeds,
-- and HyperRealistic lowers it in sharp turns (movement_hyper.lua): this module is the one writer of MaxWalkSpeed.
-- Under the game's speed, the legs' cadence follows (movement_legs.lua).

local U = require("movement_unreal")
local Curve = require("movement_curve")
local Downshift = require("movement_downshift")
local Legs = require("movement_legs")

local M = {}

-- CharacterMovement.MovementMode on the ground, and in a jump or a fall. The speed is kept in the air: the game caps the
-- speed in the air at MaxWalkSpeed too (verified in game): given the game's speed back at takeoff, a run at 2x
-- would lose half its speed in every jump.
-- Special moves (other modes) get the game's speed.
local WALKING, FALLING = U.WALKING, U.FALLING
local READ_EVERY = 1           -- seconds between two reads of the gait speeds
local SAME = 0.5               -- a speed this close to the one written is still the mod's
local MAX_GAIT_LINES = 12      -- walk and run reached with the stick's curve on, said with the push: enough to check
                               -- that the cuts fall where the curve expects them

local G
local gait_lines = 0

-- ratio: the curve's share of the game's speed at the last frame on the ground, kept in the air. gait: the last plateau
-- reached ("walk", "run"), for the log.
function M.forget()
	G = { gaits = nil, next_read = 0, said = false, written = nil, game = nil, writes = 0, rewrites = 0, top = 0,
		ratio = nil, gait = nil, slowed = 0, lifted = false, factor = nil }
	Downshift.forget()
	Legs.forget()
end
M.forget()

local function attribute(set, name)
	local v = nil
	pcall(function() v = U.num(set[name].CurrentValue) end)
	return v
end

-- { walk, run, sprint } from the player's attributes, or nil when they cannot be read or are not in that order.
local function read_gaits(pawn)
	local set = nil
	pcall(function() set = pawn.AttributeSetBase end)
	if not U.is_valid(set) then return nil end
	local g = { walk = attribute(set, "WalkSpeed"), run = attribute(set, "JogSpeed"),
		sprint = attribute(set, "SprintSpeed") }
	if g.walk == nil or g.run == nil or g.sprint == nil or not (0 < g.walk and g.walk < g.run and g.run < g.sprint) then
		return nil
	end
	return g
end

local function lerp(a, b, t) return a + (b - a) * t end

-- The factor for a game speed: a gait's own setting at its speed, sliding between two gaits.
function M.factor(speed, gaits, rates)
	if speed <= gaits.walk then return rates.walk end
	if speed <= gaits.run then return lerp(rates.walk, rates.run, (speed - gaits.walk) / (gaits.run - gaits.walk)) end
	if speed <= gaits.sprint then
		return lerp(rates.run, rates.sprint, (speed - gaits.run) / (gaits.sprint - gaits.run))
	end
	return rates.sprint
end

function M.holding()
	return G.written ~= nil or Legs.holding()
end

-- Gives the game its own speed back, when the speed in place is still the one the mod wrote. cmc: the movement
-- component, nil when not read. Does nothing when the mod has written nothing.
function M.release(cmc)
	if G.written == nil then return end
	if cmc ~= nil then
		local cur = nil
		pcall(function() cur = U.num(cmc.MaxWalkSpeed) end)
		if cur ~= nil and math.abs(cur - G.written) <= SAME then
			pcall(function() cmc.MaxWalkSpeed = G.game end)
		end
	end
	G.written, G.game, G.ratio, G.lifted, G.factor = nil, nil, nil, false, nil
	Downshift.forget()
	Legs.release()
end

-- The stick curve's part of the speed (movement_curve.lua): on the ground from the push; in the air the share of the
-- last frame on the ground, as a change of the speed allowed mid-jump would change the jump's length.
local function curved(base, mode, push, left, say)
	if left == nil then
		G.ratio = nil
		return base
	end
	if mode ~= WALKING then return G.ratio and base * G.ratio or base end
	local speed = Curve.speed(base, push, G.gaits, left)
	G.ratio = base > 0 and speed / base or nil
	if speed < base - SAME then G.slowed = G.slowed + 1 end
	local gait = (base <= G.gaits.walk + SAME and "walk") or (math.abs(base - G.gaits.run) <= SAME and "run") or nil
	if gait ~= nil and gait ~= G.gait then
		G.gait = gait
		if push ~= nil and push >= Curve.MIN_STICK and gait_lines < MAX_GAIT_LINES then
			gait_lines = gait_lines + 1
			say("stick: %s at a push of %.2f, speed %.0f of the game's %.0f", gait, push, speed, base)
		end
	end
	return speed
end

-- The game's own speed at the last frame (before the long sprint's hold), nil when the mod left the speed to the game.
function M.game_speed()
	return G.game
end

-- How many times the game's speed the gait settings give at the last frame (the stick's curve aside), nil when the
-- mod leaves the speed to the game: the braking's factor (movement_brake.lua).
function M.factor_now()
	return G.factor
end

-- { walk, run, sprint }: the gait speeds, nil when unread.
function M.gaits()
	return G.gaits
end

-- cmc, mode: the movement component and its MovementMode, read by main.lua. push, left: the left stick's push and its
-- curve (movement_stick.lua, movement_curve.lua), nil when off. floor: a game speed to lift the game's to, the long
-- sprint held after a special move (movement_resume.lua), nil when none. realism: the Realism row's part
-- (movement_realism.lua), nil when off: the speed's drops eased, and keep, the share of the speed kept in a turn.
function M.frame(pawn, cmc, mode, now, rates, say, push, left, floor, realism)
	if now >= G.next_read then
		G.next_read = now + READ_EVERY
		G.gaits = read_gaits(pawn)
		if not G.said then
			G.said = true
			if G.gaits == nil then
				say("the gait speeds cannot be read; walking, running and sprinting keep the game's speed")
			else
				say("gait speeds: walk %.0f, run %.0f, sprint %.0f", G.gaits.walk, G.gaits.run, G.gaits.sprint)
			end
		end
	end
	if cmc == nil or G.gaits == nil then return M.release(cmc) end
	local cur = nil
	if mode == WALKING or mode == FALLING then pcall(function() cur = U.num(cmc.MaxWalkSpeed) end) end
	if cur == nil then return M.release(cmc) end

	local base = cur
	if G.written ~= nil then
		-- Lifted to the long sprint at the last frame, the same speed is the game's own long sprint back: the game
		-- rewrites its speed every frame (verified), and taking the old game speed would hold the floor forever.
		if math.abs(cur - G.written) <= SAME and not G.lifted then
			base = G.game
		else
			G.rewrites = G.rewrites + 1
		end
	end
	G.top = math.max(G.top, base)
	local game = base
	G.lifted = floor ~= nil and base < floor
	if G.lifted then base = floor end
	G.factor = M.factor(base, G.gaits, rates)
	local want = curved(base, mode, push, left, say) * G.factor
	if realism ~= nil then
		want = Downshift.soften(want, cmc, mode, now, say) * realism.keep
	else
		Downshift.forget()
	end
	if math.abs(cur - want) > SAME then
		if not pcall(function() cmc.MaxWalkSpeed = want end) then return end
		G.writes = G.writes + 1
	end
	-- The game's own, not the lifted one: built on when the game leaves the mod's speed in place.
	G.written, G.game = want, game
	Legs.frame(pawn, cmc, mode, G.factor, now, say)
end

-- For the status line, then the counts start over.
function M.report()
	local text = string.format("ground speed written %d times, rewritten by the game %d times, top game speed %.0f, "
		.. "slowed by the stick %d times, legs slowed %d frames", G.writes, G.rewrites, G.top, G.slowed, Legs.report())
	G.writes, G.rewrites, G.top, G.slowed = 0, 0, 0, 0
	return text
end

return M
