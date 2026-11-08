-- Hands our plan (vault_plan.lua) to the game: writes it into the component's TraversalResult, then calls the
-- component's PerformTraversalAction. Read in the game's blueprint code (BP_MotionReactorComponent):
-- PerformTraversalAction picks the animation from the result (SearchAnimMontage), sets the warp targets from
-- FrontTarget, BackTarget and FloorTarget (UpdateWarpTargets), plays it, sets DoingTraversalAction and the flying
-- movement mode, and back to walking when it ends or is interrupted. A safety net puts the walking mode back if the
-- action still runs STUCK_AFTER s later, so that a failed traversal cannot leave the character stuck. Its clock stops
-- while the game is paused (vault_pause.lua), and it keeps watching our traversal after the mod is switched off.

local R = require("vault_reading")

local M = {}

local STUCK_AFTER = 4             -- s: 93 traversals measured in game lasted 0.34 to 0.86 s
local WALKING = 1                 -- EMovementMode::MOVE_Walking

-- ours: the action we started, { t }, while it runs.
local S = { ours = nil }

local function same(now, want)
	if type(want) == "table" then
		for k, v in pairs(want) do
			if not same(R.read(function() return now[k] end), v) then return false end
		end
		return true
	end
	if type(want) == "number" then
		local n = R.num(now, nil)
		return n ~= nil and math.abs(n - want) < 0.01
	end
	return now == want
end

local function assign(holder, k, v) holder[k] = v end

-- Writes one field; a structure the engine does not take whole is written member by member.
local function set(holder, k, v)
	pcall(assign, holder, k, v)
	if type(v) ~= "table" then return end
	local now = R.field(holder, k)
	if now == nil or same(now, v) then return end
	for kk, vv in pairs(v) do set(now, kk, vv) end
end

local function transform(p, quat)
	return { Rotation = quat, Translation = { X = p.x, Y = p.y, Z = p.z }, Scale3D = { X = 1, Y = 1, Z = 1 } }
end

local function fields(plan)
	local d = plan.dir
	local half = math.atan(d.y, d.x) / 2
	local quat = { X = 0, Y = 0, Z = math.sin(half), W = math.cos(half) } -- the yaw into the wall
	return {
		{ "ActionType", plan.kind }, { "bHasFrontTarget", true }, { "FrontTarget", transform(plan.front, quat) },
		{ "FrontNormal", { X = -d.x, Y = -d.y, Z = 0 } }, { "bHasBackTarget", plan.back ~= nil },
		{ "BackTarget", transform(plan.back or plan.front, quat) }, { "BackNormal", { X = d.x, Y = d.y, Z = 0 } },
		{ "bHasFloorTarget", plan.floor ~= nil }, { "FloorTarget", transform(plan.floor or plan.front, quat) },
		{ "ObstacleHeight", plan.height }, { "ObstacleDepth", plan.depth }, { "BackHeight", plan.back_height },
	}
end

local function holds(comp, list)
	local r = R.field(comp, "TraversalResult")
	if r == nil then return false end
	for _, kv in ipairs(list) do
		if not same(R.field(r, kv[1]), kv[2]) then return false end
	end
	return true
end

-- Writes the plan field by field, else the whole result at once; says which way held, or nil.
local function write(comp, list)
	local r = R.read(function() return comp.TraversalResult end)
	if r == nil then return nil end
	for _, kv in ipairs(list) do set(r, kv[1], kv[2]) end
	if holds(comp, list) then return "field by field" end
	local whole = {}
	for _, kv in ipairs(list) do whole[kv[1]] = kv[2] end
	pcall(function() comp.TraversalResult = whole end)
	if holds(comp, list) then return "whole result" end
	return nil
end

-- Writes the plan and asks the game to play it; the outcome as one text, built in full for a trial's line (with_text)
-- or when the traversal did not start, which is then an event.
function M.perform(comp, plan, now, with_text)
	local how = write(comp, fields(plan))
	if how == nil then return "result refused, nothing played" end
	if not pcall(function() comp:PerformTraversalAction() end) then
		return "written " .. how .. ", PerformTraversalAction call failed"
	end
	local doing = R.field(comp, "DoingTraversalAction")
	if doing == true then S.ours = { t = now } end
	if doing == true and not with_text then return "performed" end
	return string.format("written %s, performed: doing=%s action=%s montage=%s start=%s", how, R.text(doing),
		R.text(R.read(function() return comp.TraversalResult.ActionType end)),
		R.short(R.path(R.read(function() return comp.TraversalResult.ChosenMontage end))),
		R.text(R.read(function() return comp.TraversalResult.StartTime end)))
end

-- Each frame while our action runs: past STUCK_AFTER, puts the walking mode back and says so (say, an event); detail,
-- a trial build's writer or nil, says when the action ends. doing: DoingTraversalAction, read
-- once this frame.
function M.keep(say, detail, comp, pawn, doing, now)
	if S.ours == nil then return end
	if doing ~= true then
		if detail then detail("ours ended after %.1f s, %s", now - S.ours.t, R.where(pawn)) end
		S.ours = nil
		return
	end
	if now - S.ours.t < STUCK_AFTER then return end
	S.ours = nil
	local moved = pcall(function() pawn.CharacterMovement:SetMovementMode(WALKING, 0) end)
	pcall(function() comp.DoingTraversalAction = false end)
	say("ours still running after %d s: walking mode set back (%s), %s", STUCK_AFTER, moved and "done" or "failed",
		R.where(pawn))
end

function M.reset()
	S.ours = nil
end

-- Whether our action runs, for the status line's cost while busy.
function M.running()
	return S.ours ~= nil
end

return M
