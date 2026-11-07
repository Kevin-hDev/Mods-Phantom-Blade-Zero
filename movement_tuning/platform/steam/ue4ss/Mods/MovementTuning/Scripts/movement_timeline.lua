-- How far a timeline's time can be pushed without jumping over one of its actions. The game starts and ends a
-- timeline's actions (LGATimeline.Actions: StartTime, duration, trigger offsets) as its own time passes them; a time the
-- mod jumps over is never passed: at Weapon draw 3, the putting away (GAAction_ChangeArmed at 1.24 s of the Unarm
-- timeline) fell in the part jumped over, and the weapon was put away and drawn again (verified in game). So a push
-- stops just before the next action's start or end, and the game's own time goes over it. Also stops: the actions of
-- the scene's other actors (RoleLayers, an execution's victim), and the timeline's end, where a looping timeline starts
-- over with its first actions.

local U = require("movement_unreal")

local M = {}

local MAX_TIMELINES = 128   -- timelines whose action times are remembered; past this, the memory starts over
local MAX_READ = 1024       -- actions read from one timeline at most
local MAX_TIMES = 256       -- action times kept for one timeline, the earliest
local NEAR = 0.001          -- a push stops this far before an action's time

-- cache: timeline address -> { length = SequenceLength, times = sorted action times, or false when unreadable }. The
-- length is checked on each use: another timeline at a freed one's address is read anew.
local T = { cache = {}, count = 0, unreadable = 0, said = false }

-- The timelines are read anew; the unreadable ones stay counted for the status line.
function M.forget()
	T.cache, T.count = {}, 0
end

local function add_actions(actions, times)
	actions:ForEach(function(_, item)
		if #times >= MAX_READ then return end
		local event = U.unwrap(item)
		local start = U.num(event.StartTime)
		if start == nil then error("an action without a start time") end
		local length = U.num(event.duration) or 0
		local trigger = U.num(event.TriggerTimeOffset) or 0
		local end_trigger = U.num(event.EndTriggerTimeOffset) or 0
		times[#times + 1] = start + trigger
		if length > 0 then times[#times + 1] = start + length + end_trigger end
	end)
end

local function read_times(timeline, length)
	local times = {}
	if not pcall(function() add_actions(timeline.Actions, times) end) then return nil end
	-- Most timelines have no other actor: no role layers is no failure, layers read halfway are.
	local layers = nil
	pcall(function() layers = timeline.RoleLayers end)
	if layers ~= nil and not pcall(function()
		layers:ForEach(function(_, item) add_actions(U.unwrap(item).Actions, times) end)
	end) then
		return nil
	end
	if length ~= nil and length > 0 then times[#times + 1] = length end
	table.sort(times)
	for i = #times, MAX_TIMES + 1, -1 do times[i] = nil end
	return times
end

-- The sorted action times of a timeline, or nil when they cannot be read: that timeline then keeps the game's pace.
function M.times(timeline)
	local addr = U.address(timeline)
	if addr == nil then return nil end
	local length = nil
	pcall(function() length = U.num(timeline.SequenceLength) end)
	local known = T.cache[addr]
	if known ~= nil and known.length == length then return known.times or nil end
	if known == nil then
		if T.count >= MAX_TIMELINES then T.cache, T.count = {}, 0 end
		T.count = T.count + 1
	end
	local times = read_times(timeline, length)
	if times == nil then T.unreadable = T.unreadable + 1 end
	T.cache[addr] = { length = length, times = times or false }
	return times
end

-- The time to push to, from now toward wanted, stopping just before the next action time.
function M.limit(times, now, wanted)
	for _, t in ipairs(times) do
		if t > now - NEAR then
			if t <= wanted then return math.max(now, t - NEAR) end
			return wanted
		end
	end
	return wanted
end

-- True once, the first time a timeline's actions cannot be read: said in the log at once, not 10 minutes later.
function M.first_unreadable()
	if T.said or T.unreadable == 0 then return false end
	T.said = true
	return true
end

-- For the status line: timelines whose actions could not be read since the last one.
function M.report()
	local n = T.unreadable
	T.unreadable = 0
	return n
end

return M
