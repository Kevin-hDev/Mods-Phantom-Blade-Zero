-- Faster moves and attacks: each frame, the time of the player's timelines is pushed ahead by (speed - 1) x how far the
-- game itself moved it since the last frame. Verified in game: the game plays dodges, jumps, ladders and wall
-- runs as timelines whose task (LGATask_PlayTimeline) sets where the animation is; neither the montage's play rate nor
-- the player's own clock changed how long they took, while pushing the task's CurrentTime made them 1.5 times as fast
-- over the same ground. A plain dodge keeps its length and goes further instead. A slower move (0.5 to 1, Kevin, 10
-- November 2026) has its time pulled back by (1 - speed) x that step instead (tried in game the same day).
-- The push follows the game's own step, not the frame's length: the player controller still ticks
-- while the game is paused (UE 5.7 PlayerController.cpp, bTickEvenWhenPaused) and its timelines stand still, and a
-- timeline that loops back or that the game slows with its time-stretch curve moves less than the frame.
-- The tasks are those the game announces as it makes them (movement_tasks.lua), kept when they are the player's, or an
-- enemy's attack or move when the enemies' part takes it (movement_enemies.lua): the enemies play theirs the same way,
-- pushed by this same code (EnemyProbe, 12 November 2026, Kevin: « ca fonctionne très bien en jeu »). A task's end is
-- told by its time: once over, the game no longer moves it (183 tasks out of 183, verified in game, 5 November 2026),
-- while it stays valid. A task standing still is looked at less often, then forgotten.

local U = require("movement_unreal")
local Family = require("movement_family")
local Timeline = require("movement_timeline")
local Tasks = require("movement_tasks")

local M = {}

local MAX_PUSH_TIME = 0.1   -- a long step of the game (a hitch, a load) pushes as if it lasted 0.1 s at most
local MAX_GAP = 0.2         -- seconds without a look at the tasks after which their next step is not pushed
local MAX_TRACKED = 128     -- tasks kept; past this, the one standing still the longest is forgotten. The player's
                            -- and the enemies' share it: a fight with ten enemies keeps some sixty at once
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

-- The tasks announced since the last frame: the player's kept when mine, the others offered to the enemies' part when
-- it is on (foes: movement_enemies.lua, nil while off), the rest let go.
local function adopt(asc_addr, clock, say, mine, foes)
	local list = Tasks.take()
	if list == nil then return end
	for addr, task in pairs(list) do
		if U.is_valid(task) then
			-- UE4SS's object stands for an address: the task kept there is gone, and any task made at its address, an
			-- enemy's or one left alone, would be read through it.
			drop(addr)
			local whose, asc = Tasks.owner(task)
			-- What to keep; false to let the task go, nil while it cannot be read (waited for).
			local entry = false
			if whose == nil then
				entry = nil
			elseif whose == asc_addr then
				if mine then entry = Family.entry(task, say) end
			elseif foes ~= nil then
				entry = foes.offer(task, whose, asc)
			end
			if entry ~= nil then
				C.tries[addr] = nil
				if entry and entry.key then keep(addr, entry, clock) end
			else
				local tries = (C.tries[addr] or 0) + 1
				C.tries[addr] = nil
				if tries < MAX_TRIES and Tasks.wait(addr, task) then
					C.tries[addr] = tries
				elseif tries >= MAX_TRIES and (whose == asc_addr or (whose == nil and not R.kept)) then
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
	local target = Timeline.target(entry.times, last, now, step, rate)
	if target == nil then return end
	if pcall(function() task.CurrentTime = target end) then
		entry.last = target
		counts[entry.key] = (counts[entry.key] or 0) + 1
	else
		R.failed = R.failed or "a move's time cannot be written"
	end
end

-- One kept task: pushed while its time moves, looked at less often once it stands still, forgotten after a while.
local function look(addr, entry, clock, rate, counts)
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
	-- Read only for a task that moves and is pushed: one standing still costs its validity and its time, one at the
	-- game's speed too (ten attacks at once would cost 40 calls a frame).
	if rate ~= 1 and not Tasks.same(task, entry) then
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

-- The speed a kept task follows this frame; nil while its part is off, and for an enemy's move back at the game's
-- speed: such a task is let go, it has nothing to give back.
local function rate_of(entry, rates, foes)
	if entry.foe then
		local rate = foes and foes.rates[entry.key]
		return rate ~= 1 and rate or nil
	end
	return rates and rates[entry.key]
end

-- Pushes the time of each timeline kept whose move is faster or slower than the game's. asc_addr: the address of the
-- player's ability system. rates: the player's speeds by move key, nil while they are all the game's. foes: the
-- enemies' part (movement_enemies.lua: offer, and rates by key), nil while off. counts: pushes made, by move key. say:
-- the log. Returns the number of tasks looked at.
function M.frame(asc_addr, clock, rates, counts, say, foes)
	-- Not looked at for a while (every speed at the game's, no pawn, a long hitch): the time the tasks moved since is
	-- the game's own. Pushed, it would push up to 0.1 s x (speed - 1) at once. Their last time is kept: a task that
	-- ended meanwhile still reads as standing still.
	local dt = C.clock and clock - C.clock
	if dt == nil or dt > MAX_GAP then
		dt = nil
		for _, entry in pairs(C.tasks) do entry.skip, entry.fresh = true, nil end
	end
	C.clock, C.dt = clock, dt
	adopt(asc_addr, clock, say, rates ~= nil, foes)
	local looked = 0
	for addr, entry in pairs(C.tasks) do
		local rate = rate_of(entry, rates, foes)
		if rate == nil then
			-- The enemies' part off: their tasks are let go. The player's moves all at the game's: their tasks wait,
			-- unread, and the step after is the game's own, as after a time without a look.
			if entry.foe then drop(addr) else entry.skip, entry.fresh = true, nil end
		elseif entry.slow == nil or clock >= entry.slow then
			looked = looked + 1
			look(addr, entry, clock, rate, counts)
		end
	end
	if R.failed ~= nil and not R.said then
		R.said = true
		say("%s: such moves keep the game's pace", R.failed)
	end
	return looked
end

return M
