-- The game's timeline tasks, as it makes them: UE4SS's NotifyOnNewObject calls the mod for each ability task the game
-- constructs, the player's and the enemies'. Each timeline task is kept here until movement_speed.lua takes it, a frame
-- later at most. Seen in game (5 November 2026): each of the 347 timeline tasks of the player's seen in the ability
-- system's KnownTasks was announced the frame before. Walking that list each frame instead (about 40 tasks) was most
-- of the mod's cost.

local U = require("movement_unreal")

local M = {}

-- The parent class, whose path is the engine's; the timeline task's own (LGATask_PlayTimeline) is told by its name.
local TASK_CLASS = "/Script/GameplayAbilities.AbilityTask"
local TIMELINE_TASK = "PlayTimeline"
local MAX_PENDING = 64    -- tasks waiting; past this, the waiting ones are dropped: they come from a long time without
                          -- a look (the mod off), and are over
local MAX_CLASSES = 256   -- task classes told apart by address; past this, the memory starts over
local MAX_ERROR_LINES = 3

-- pending: address -> task, n: their number. classes: class address -> true for a timeline task's class. errors: since
-- the last status line.
local A = { pending = {}, n = 0, classes = {}, n_classes = 0, errors = 0, said = 0 }

-- The one place the waiting list grows. newer: a task just announced, which takes its address's place and, the list
-- full, starts it over; else a task put back, which waits only if there is room. Returns whether the task waits.
local function add(addr, task, newer)
	if A.pending[addr] ~= nil then
		if newer then A.pending[addr] = task end
		return newer
	end
	if A.n >= MAX_PENDING then
		if not newer then return false end
		A.pending, A.n = {}, 0
	end
	A.pending[addr], A.n = task, A.n + 1
	return true
end

-- Whether the task is a timeline task, and its class's address; nil when its class cannot be read.
local function is_timeline(task)
	local class = U.class_address(task)
	if class == nil then return nil end
	local timeline = A.classes[class]
	if timeline == nil then
		local name = U.class_name(task)
		if name == nil then return nil end
		timeline = name:find(TIMELINE_TASK, 1, true) ~= nil
		if A.n_classes >= MAX_CLASSES then A.classes, A.n_classes = {}, 0 end
		A.classes[class], A.n_classes = timeline, A.n_classes + 1
	end
	return timeline, class
end

-- Checked again when a task is taken: UE4SS's object stands for an address, and the game makes other ability tasks
-- at a timeline task's address within the frame (6 November 2026: tasks read a frame after
-- a timeline task's announcement were of AbilityTask_WaitGameplayEvent and other classes).
M.is_timeline = is_timeline

-- Called by UE4SS as each ability task is constructed, about one a second: kept short.
local function announced(task)
	if not is_timeline(task) then return end
	local addr = U.address(task)
	if addr == nil then return end
	add(addr, task, true)
end

-- At load: returns whether the game's tasks are watched, and the error when not.
function M.watch(say)
	return pcall(function()
		NotifyOnNewObject(TASK_CLASS, function(task)
			local ok, err = pcall(announced, task)
			if not ok then
				A.errors, A.said = A.errors + 1, A.said + 1
				if A.said <= MAX_ERROR_LINES then say("a new task cannot be read: %s", tostring(err)) end
			end
		end)
	end)
end

-- The timeline tasks announced since the last call (address -> task), or nil. Taken as a whole and the waiting list
-- started over first: a task announced while the mod walks the taken list goes to the new list, never into the one
-- being walked.
function M.take()
	if A.n == 0 then return nil end
	local list = A.pending
	A.pending, A.n = {}, 0
	return list
end

-- A task taken but not readable yet: it waits for the next frame if there is room. Returns whether it waits.
function M.wait(addr, task)
	return add(addr, task, false)
end

-- Errors since the last call, for the status line.
function M.errors()
	local n = A.errors
	A.errors = 0
	return n
end

return M
