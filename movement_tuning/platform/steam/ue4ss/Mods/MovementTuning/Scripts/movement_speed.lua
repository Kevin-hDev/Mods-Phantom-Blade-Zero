-- Faster moves and attacks: each frame, the time of the player's timelines is pushed ahead by (speed - 1) x how far the
-- game itself moved it since the last frame. Verified in game: the game plays dodges, jumps, ladders and wall
-- runs as timelines whose task (LGATask_PlayTimeline) sets where the animation is; neither the montage's play rate nor
-- the player's own clock changed how long they took, while pushing the task's CurrentTime made them 1.5 times as fast
-- over the same ground. A plain dodge keeps its length and goes further instead.
-- The push follows the game's own step, not the frame's length: the player controller still ticks
-- while the game is paused (UE 5.7 PlayerController.cpp, bTickEvenWhenPaused) and its timelines stand still, and a
-- timeline that loops back or that the game slows with its time-stretch curve moves less than the frame.
-- The tasks are those the game announces as it makes them (movement_tasks.lua), kept when they are the player's. A
-- task's end is told by its time: once over, the game no longer moves it (183 tasks out of 183, verified in game, 5
-- November 2026), while it stays valid. A task standing still is looked at less often, then forgotten.

local U = require("movement_unreal")
local Family = require("movement_family")
local Timeline = require("movement_timeline")
local Tasks = require("movement_tasks")

local M = {}

local MAX_PUSH_TIME = 0.1   -- a long step of the game (a hitch, a load) pushes as if it lasted 0.1 s at most
local MAX_GAP = 0.2         -- seconds without a look at the tasks after which their next step is not pushed
local MAX_TRACKED = 64      -- the player's tasks kept; past this, the one standing still the longest is forgotten
local MAX_TRIES = 5         -- frames a new task is waited for when its owner, its class or its ability cannot be read
local IDLE = 0.25           -- seconds a task's time stands still before it is looked at every SLOW_LOOK seconds only
local SLOW_LOOK = 0.1       -- moving again (a pause over), its steps since are pushed at once, within MAX_PUSH_TIME
local FORGET_AFTER = 10     -- seconds standing still before a task is forgotten: over, or the game paused that long
local SAME = 1e-6

-- tasks: task address -> { task, key = move key, class, ability (addresses, to tell another task at the address),
-- last = the task's time when the mod last left it, moved_at = the clock when its time last moved, slow = the clock of
-- its next look while it stands still, fresh = true until its first look, skip = its next step is not pushed (after a
-- time without a look), and for a timeline being pushed: timeline = its timeline's address, times = that timeline's
-- action times }. tries: address -> frames waited. seen: move key -> the clock when a timeline of that move last moved.
-- clock: the last look; dt: the time since the one before.
local C = { tasks = {}, count = 0, tries = {}, seen = {}, clock = nil, dt = nil }
-- failed: what kept a move from being sped up since the start, said once (a game update could break a read or a write).
local R = { failed = nil, said = false, kept = false }

function M.forget()
	C.tasks, C.count, C.tries, C.seen, C.clock, C.dt = {}, 0, {}, {}, nil, nil
end

-- When a timeline of the move last moved, or nil. Read by the jump height, whose jump step can end before the
-- takeoff once Jump recovery shortens it.
function M.seen_at(key)
	return C.seen[key]
end

function M.remembered()
	return C.count
end

-- The task's ability system, given by UE4SS as the object or as a weak pointer to Get it from (seen in game).
local function owner(task)
	local v, got = nil, nil
	pcall(function() v = task.AbilitySystemComponent end)
	if v == nil then return nil end
	if U.is_valid(v) then return U.address(v) end
	pcall(function() got = v:Get() end)
	return U.is_valid(got) and U.address(got) or nil
end

-- What a task is: { key = false } for one left alone, nil when it cannot be read this frame (tried again next frame).
local function identify(task, say)
	local timeline, class = Tasks.is_timeline(task)
	if timeline == nil then return nil end
	if not timeline then return { key = false } end
	local ability = nil
	pcall(function() ability = task.Ability end)
	-- UE4SS gives an unset object property as an object that is not valid.
	if not U.is_valid(ability) then return { key = false } end
	local key = Family.category(ability, say)
	if key == nil then return nil end
	return { task = task, key = key, class = class, ability = U.address(ability), fresh = true }
end

-- Whether a task at a known address is still the one worked out: same class, same ability. The task was just checked
-- valid.
local function same(task, entry)
	if U.class_address(task, true) ~= entry.class then return false end
	local ability = nil
	pcall(function() ability = task.Ability end)
	return U.address(ability) == entry.ability
end

local function drop(addr)
	if C.tasks[addr] ~= nil then C.tasks[addr], C.count = nil, C.count - 1 end
end

local function keep(addr, entry, clock)
	if C.tasks[addr] == nil and C.count >= MAX_TRACKED then
		local oldest, at = nil, math.huge
		for a, e in pairs(C.tasks) do
			if e.moved_at < at then oldest, at = a, e.moved_at end
		end
		drop(oldest)
	end
	if C.tasks[addr] == nil then C.count = C.count + 1 end
	R.kept = true
	entry.moved_at = clock
	C.tasks[addr] = entry
end

-- The tasks announced since the last frame: the player's are kept, the others let go.
local function adopt(asc_addr, clock, say)
	local list = Tasks.take()
	if list == nil then return end
	for addr, task in pairs(list) do
		if U.is_valid(task) then
			-- UE4SS's object stands for an address: the task kept there is gone, and any task made at its address, an
			-- enemy's or one left alone, would be read through it.
			drop(addr)
			local whose = owner(task)
			local entry = whose == asc_addr and identify(task, say) or nil
			if entry ~= nil then
				C.tries[addr] = nil
				if entry.key then keep(addr, entry, clock) end
			elseif whose == nil or whose == asc_addr then
				local tries = (C.tries[addr] or 0) + 1
				C.tries[addr] = nil
				if tries < MAX_TRIES and Tasks.wait(addr, task) then
					C.tries[addr] = tries
				elseif tries >= MAX_TRIES and (whose == asc_addr or not R.kept) then
					-- An unreadable owner can be an enemy's being destroyed: said only while no move has ever been
					-- kept, when the owner reads fail for every task.
					R.failed = R.failed or "a new move's owner, class or ability cannot be read"
				end
			end
		else
			C.tries[addr] = nil
		end
	end
end

local function push(task, entry, now, last, fresh, rate, counts)
	if rate == nil or rate == 1 then return end
	local timeline = nil
	pcall(function() timeline = task.Timeline end)
	local timeline_addr = U.address(timeline)
	if timeline_addr ~= entry.timeline then
		-- An unset timeline comes as an object that is not valid: nothing is read from it.
		if not U.is_valid(timeline) then timeline_addr = nil end
		entry.timeline, entry.times = timeline_addr, timeline_addr and Timeline.times(timeline)
	end
	-- A task new since the last look started within that frame: its time so far is pushed too, at most the frame's
	-- length. Left alone, a 0.27 s jump step at Jump recovery 5 went 3.2 times as fast, not 4.
	if last == nil and fresh and C.dt ~= nil then last = math.max(0, now - C.dt) end
	if last == nil or entry.times == nil then return end
	local step = math.min(now - last, MAX_PUSH_TIME)
	if not (step > 0) then return end
	local target = Timeline.limit(entry.times, now, now + step * (rate - 1))
	if target <= now then return end
	if pcall(function() task.CurrentTime = target end) then
		entry.last = target
		counts[entry.key] = (counts[entry.key] or 0) + 1
	else
		R.failed = R.failed or "a move's time cannot be written"
	end
end

-- One kept task: pushed while its time moves, looked at less often once it stands still, forgotten after a while.
local function look(addr, entry, clock, rates, counts)
	local task = entry.task
	if not U.is_valid(task) then
		drop(addr)
		return
	end
	local now = nil
	pcall(function() now = U.num(task.CurrentTime) end)
	local last, fresh = entry.last, entry.fresh
	entry.fresh = nil
	if now == nil or (not fresh and last ~= nil and math.abs(now - last) <= SAME) then
		local still = clock - entry.moved_at
		if still >= FORGET_AFTER then
			drop(addr)
		elseif still >= IDLE then
			entry.slow = clock + SLOW_LOOK
		end
		return
	end
	local rate = rates[entry.key]
	-- Read only for a task that moves and is pushed: one standing still costs its validity and its time, one at the
	-- game's speed too (ten attacks at once would cost 40 calls a frame).
	if rate ~= 1 and not same(task, entry) then
		drop(addr)
		return
	end
	-- slow is left as it was: a time already past, so the task is looked at each frame.
	entry.moved_at, entry.last = clock, now
	C.seen[entry.key] = clock
	if entry.skip then
		entry.skip = nil
		return
	end
	push(task, entry, now, last, fresh, rate, counts)
end

-- Pushes the time of each of the player's timelines whose move is faster than the game's. asc_addr: the address of the
-- player's ability system. counts: pushes made, by move key. say: the log. Returns the number of tasks looked at.
function M.frame(asc_addr, clock, rates, counts, say)
	-- Not looked at for a while (every speed at the game's, no pawn, a long hitch): the time the tasks moved since is
	-- the game's own. Pushed, it would push up to 0.1 s x (speed - 1) at once. Their last time is kept: a task that
	-- ended meanwhile still reads as standing still.
	local dt = C.clock and clock - C.clock
	if dt == nil or dt > MAX_GAP then
		dt = nil
		for _, entry in pairs(C.tasks) do entry.skip, entry.fresh = true, nil end
	end
	C.clock, C.dt = clock, dt
	adopt(asc_addr, clock, say)
	local looked = 0
	for addr, entry in pairs(C.tasks) do
		if entry.slow == nil or clock >= entry.slow then
			looked = looked + 1
			look(addr, entry, clock, rates, counts)
		end
	end
	if R.failed ~= nil and not R.said then
		R.said = true
		say("%s: such moves keep the game's pace", R.failed)
	end
	return looked
end

return M
