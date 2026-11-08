-- One jump followed, from a press of one of the game's jump keys (vault_jump_keys.lua) until JUMP_WAIT s later: what
-- stands ahead is measured at the press (vault_measure.lua) and read (vault_plan.lua); OURS_AFTER s later, when the
-- game is not traversing, our plan is handed to the game (vault_perform.lua). An obstacle too far at the press is
-- measured again every MEASURE_EVERY s until REACH_UNTIL s after it, while the run carries the character nearer, its
-- heights still counted from the feet at the press.
-- Before a plan is played or a measure taken again, the character must be falling; else the jump is let go. Without
-- it, the jump's button pressed in a menu, or as the game starts a special move of its own (flying mode), would climb.
-- A press made while the character already falls passes it: he catches the obstacle in the air.
-- A press during a traversal already under way, ours or the game's, is not measured: nothing would be played. Under
-- way means seen on the frame before the press and still on its frame: the game's own traversal for this press
-- already plays on the press's frame, and a press on the frame a traversal ends stays the mod's. A press while the
-- game is paused is not followed.
-- The measure and its plan are spread over frames, BUDGET traces a frame (vault_spread.lua): the verdict waits for
-- the plan, which is ready within the 0.1 s for all but the largest measures.

local R = require("vault_reading")
local Measure = require("vault_measure")
local Plan = require("vault_plan")
local Perform = require("vault_perform")
local Keys = require("vault_keys")
local Trial = require("vault_trial")
local Result = require("vault_result")
local Status = require("vault_status")
local Spread = require("vault_spread")

local M = {}

-- s: the game's own traversal starts on the press's frame, or up to 0.29 s later while the character rises (6 of
-- 43 measured in game); ours acts sooner, and takes the place of the game's late ones.
local OURS_AFTER = 0.1
-- s: measured once 0.1 s after the press, obstacles were still 2.15 and 2.27 m away in jumps made running; the
-- character stays about 0.8 s in the air.
local REACH_UNTIL = 0.5
local MEASURE_EVERY = 0.05
local JUMP_WAIT = 0.6             -- s: when the jump's line is written, after REACH_UNTIL
local PASSED = 0                  -- cm: the character's centre past the front, ours is too late
local MANTLE_TRACE = 7            -- the vaulting's trace channel read in game, if unreadable
local FALLING = 3                 -- EMovementMode::MOVE_Falling
local NOT_IN_AIR = "none (not in the air: the press did not make the character jump)"
local DURING = "not measured: pressed during a traversal"
local UNFINISHED = "measure not finished"

-- jump: the press being followed, { t, done, during, plan, why, channel, feet, text, where, measure, detail, game,
-- ours, late, again, next, work, stepped, fresh, loc, frames }; down: the jump's keys held at the last read; jumps:
-- presses followed; was: DoingTraversalAction on the frame before, which only a trial build reads on every frame
-- (main.lua); frame: the frames counted, so that a measure goes on at most once a frame.
local S = { jump = nil, down = {}, jumps = 0, was = nil, frame = 0 }

local function too_far(j)
	return j.plan == nil and j.why:find(Plan.TOO_FAR, 1, true) == 1
end

local function falling(pawn)
	return R.num(R.read(function() return pawn.CharacterMovement.MovementMode end), -1) == FALLING
end

-- The measure at the press, and the plan from it.
local function measured(j)
	return function(work)
		local measure, scene = Measure.measure(work.pawn, j.channel, j.text)
		local plan, why = Plan.plan(scene)
		return measure, scene, plan, why
	end
end

-- The measure taken again from where the character is, its heights from his feet at the press.
local function measured_again(j)
	return function(work)
		local _, scene = Measure.measure(work.pawn, j.channel, j.text, j.feet)
		local plan, why = Plan.plan(scene)
		return nil, scene, plan, why
	end
end

-- The jump's measure on to its end, or on by BUDGET traces in this frame; once ended, its plan is the jump's. A
-- measure taken again leaves its position for ours when it ended in its first frame, else nil: he has moved since.
local function advance(j, pawn)
	if j.work == nil or j.stepped == S.frame then return end
	if j.work.frames > 0 then Status.note("the measure carried on") end
	j.stepped = S.frame
	local work = j.work
	local ok, ended = pcall(Spread.step, work, pawn)
	if not ok then
		j.work, j.plan, j.why, j.measure = nil, nil, "the measure failed", j.measure or "measure failed"
		error(ended, 0)
	end
	if not ended then return end
	j.work, j.frames = nil, (j.frames or 0) + work.frames
	local measure, scene, plan, why = table.unpack(work.result, 1, 4)
	j.plan, j.why = plan, why
	if j.text then j.detail = Plan.detail(scene) end
	if not work.again then
		j.measure, j.feet = measure, scene and scene.feet
		return
	end
	j.again, j.fresh = work.t - j.t, true
	j.loc = work.frames == 1 and scene and scene.loc or nil
end

-- Our traversal for a jump the game did not take, as one text (empty without a trial build): the plan made at the
-- press, or, when the obstacle was too far then, one from where the character is now, measured again until it is near
-- enough or REACH_UNTIL s have passed. nil while it is still too far and there is time left, or measured again.
local function ours(say, j, comp, pawn, now)
	if too_far(j) and not j.fresh then
		Status.note("a new measure")
		j.work = Spread.new(measured_again(j), now)
		j.work.again = true
		advance(j, pawn)
		if j.work ~= nil then return nil end
	end
	local loc = j.fresh and j.loc or nil
	if j.fresh then
		j.fresh = false
		if too_far(j) and j.again + MEASURE_EVERY <= REACH_UNTIL then
			j.next = j.t + j.again + MEASURE_EVERY
			return nil
		end
	end
	local again = j.text and j.again and string.format("measured again %.2f s after the press: ", j.again) or ""
	if j.plan == nil then return j.text and again .. "none (" .. j.why .. ")" .. j.detail or "" end
	loc = loc or R.vec(R.read(function() return pawn:K2_GetActorLocation() end))
	if loc == nil or Plan.ahead(j.plan, loc) < PASSED then
		return j.text and again .. Plan.text(j.plan) .. ", not played: the character is already past the front" or ""
	end
	Status.note("our traversal's start")
	local said = Perform.perform(comp, j.plan, now, j.text)
	if Perform.running() then
		Status.played()
	elseif not j.text then
		say("our traversal was not played: %s", said)
	end
	return j.text and again .. Plan.text(j.plan) .. ", " .. said or ""
end

local function decide(say, j, comp, pawn, now)
	local game = j.text and Result.text(comp) or nil -- read before ours writes its own
	local said
	if falling(pawn) then
		said = ours(say, j, comp, pawn, now)
	else
		said = j.text and NOT_IN_AIR or ""
	end
	if said ~= nil then j.game, j.ours = game, said end
end

-- A press: the jump to follow, measured unless a traversal is under way, ours or the game's. doing: as in M.frame.
local function start(comp, pawn, doing, now)
	local text = Trial.open()
	local j = { t = now, done = false, text = text, where = text and R.where(pawn) or nil, detail = "", why = "",
		during = Perform.running() and "our" or text and S.was == true and doing == true and "the game's" or nil }
	if j.during then
		j.measure = text and DURING or nil
		return j
	end
	-- A published build, which writes no line, does not measure a press the game is traversing: nothing is played.
	if doing == true and not text then
		j.done = true
		return j
	end
	j.channel = R.num(R.read(function() return comp.TraversalConfig.MantleTrace end), MANTLE_TRACE)
	j.work = Spread.new(measured(j), now)
	advance(j, pawn)
	return j
end

-- The jump's line, JUMP_WAIT s after the press or sooner; cut: why it ends sooner, for a jump without its verdict yet.
local function finish(j, cut)
	S.jump = nil
	S.jumps = S.jumps + 1
	if not j.text then return end
	Status.note("a jump's line")
	if j.during then
		return Trial.say("jump %d pressed during %s traversal, pressed %s | %s", S.jumps, j.during, j.where, j.measure)
	end
	if j.done then return Trial.say("jump %d vaulted, pressed %s | %s", S.jumps, j.where, j.measure or UNFINISHED) end
	if j.ours == nil then
		return Trial.say("jump %d let go: %s, before its verdict | pressed %s | %s", S.jumps, cut, j.where,
			j.measure or UNFINISHED)
	end
	Trial.say("jump %d without the game's traversal: %s | ours: %s%s | pressed %s | %s", S.jumps, j.game, j.ours,
		j.late and " | the game traversed after our verdict" or "", j.where, j.measure)
end

-- Whether one of the jump's keys is pressed now (the last reads updated): before main.lua reads the component, which a
-- frame without a press, a jump followed or our traversal goes without.
function M.pressed(controller, keys)
	return Keys.pressed(controller, keys, S.down)
end

-- A press while the game is paused (one of its menus open): not followed, only counted, and in a trial build written.
-- A jump followed goes on after the pause.
function M.paused_press(pawn)
	S.jumps = S.jumps + 1
	Status.jump()
	if Trial.open() then
		Status.note("a jump's line")
		Trial.say("jump %d pressed while the game is paused, pressed %s | not measured", S.jumps, R.where(pawn))
	end
end

-- Each frame while the mod is on. doing: DoingTraversalAction, read once this frame, or nil; now: the clock that stops
-- during a pause (vault_pause.lua); pressed: M.pressed said so this frame.
function M.frame(say, comp, pawn, doing, now, pressed)
	S.frame = S.frame + 1
	if pressed then
		Status.note("a press")
		local j = S.jump
		if j ~= nil then finish(j, j.text and string.format("the next press came %.2f s after it", now - j.t)) end
		S.jump = start(comp, pawn, doing, now)
		Status.jump()
	end
	S.was = doing
	local j = S.jump
	if j == nil then return end
	-- A press during a traversal is marked done on its own frame, so never played; its line says which. One that the
	-- game traverses after our verdict, not ours, is noted.
	if doing == true then
		if j.ours == nil then
			j.done = true
		elseif not Perform.running() then
			j.late = true
		end
	end
	-- A published build drops the measure of a press the game traverses; a trial's goes on, for the jump's line.
	if j.done and not j.text then j.work = nil end
	advance(j, pawn)
	if not j.done and j.ours == nil and j.work == nil and now - j.t >= OURS_AFTER and now >= (j.next or 0) then
		decide(say, j, comp, pawn, now)
	end
	if now - j.t >= JUMP_WAIT then finish(j) end
end

-- Whether a press is being followed, for the status line's cost while busy.
function M.busy()
	return S.jump ~= nil
end

-- A new character or the mod switched off (why): the press under way is let go, its line written. was needs no reset:
-- a trial build sets it on the frame that resyncs the keys, where no press can start, and only a trial build reads it.
function M.reset(why)
	if S.jump ~= nil then finish(S.jump, why) end
end

-- The jump's keys held now are not new presses: a character ready, or the game's jump keys changed.
function M.resync(controller, keys)
	S.down = {}
	Keys.hold(controller, keys, S.down)
end

return M
