-- Turn off sprint (Kevin, 7 November 2026), one row with three choices: Sprint turns off the sprint, and the high-speed
-- sprint with it; HighSpeedSprint turns off only the high-speed sprint, the faster sprint that follows 2 s of sprint
-- (skill Thousand-Mile Stride, talent GA_Talent_EnableIntoSuperSprint_C); None leaves both. Verified in game with
-- SprintCutProbe (7 November 2026, docs/mouvement/enquetes/2026-11-07-couper-le-sprint.md): the talent waits its
-- DelayTime of sprint before the high-speed sprint, and an endless wait on the character's instance keeps it from
-- coming; the sprint's keys are turned off by movement_sprint_keys.lua. Everything is put back exactly when the row goes
-- back to None or the mod is turned off; nothing is written to disk.

local U = require("movement_unreal")
local Keys = require("movement_sprint_keys")

local M = {}

local NEVER = 1e9            -- seconds: the talent's wait never ends
local GAME_DELAY = 2         -- the talent's own wait in the game's files, put back when the one before is not known
local TALENT = "EnableIntoSuperSprint"
local MAX_ABILITIES = 512    -- the player has about 135
local CHECK_EVERY = 1        -- seconds between two checks that the talent keeps the endless wait, or, while it is not
                             -- found, that the character's abilities are as many as at the last look
-- Seconds between looks for a talent not found while the abilities cannot be counted, doubled each time: a look walks
-- the 135 abilities (677 calls in the tests' fake game).
local FIRST_LOOK, SLOWEST_LOOK = 1, 8

-- obj, addr: the talent whose wait is endless; delay: its wait before. next: the clock of the next check or look; wait:
-- seconds between looks while the talent is not found and the abilities not counted; seen: their count at a look that
-- found no talent. refind: a new character, looked for at once. broken: the game refuses the change. said: lines said
-- once for each character. again: the waits the game gave back to the talent kept, made endless again since the last
-- status line.
local T = { obj = nil, addr = nil, delay = nil, next = 0, wait = FIRST_LOOK, seen = nil, refind = true, broken = false,
	said = {}, again = 0 }

local function say_once(say, what, fmt, ...)
	if T.said[what] then return end
	T.said[what] = true
	say(fmt, ...)
end

local function wait_of(talent)
	local d = nil
	pcall(function() d = U.num(talent.DelayTime) end)
	return d
end

-- The character's abilities (an array of the game's) and their count, each nil when unreadable.
local function abilities(pawn)
	local items, n = nil, nil
	pcall(function() items = pawn.AbilitySystemComponent.ActivatableAbilities.Items end)
	if items ~= nil then pcall(function() n = items:GetArrayNum() end) end
	return items, U.num(n)
end

-- The first live instance of the high-speed sprint's talent among the abilities, or nil.
local function find(items)
	for _, spec in ipairs(U.items(items, MAX_ABILITIES) or {}) do
		local ability, instances = nil, nil
		pcall(function() ability = spec.Ability end)
		if (U.class_name(ability) or ""):find(TALENT, 1, true) then
			pcall(function() instances = spec.NonReplicatedInstances end)
			for _, inst in ipairs(U.items(instances, MAX_ABILITIES) or {}) do
				if U.is_valid(inst) then return inst end
			end
		end
	end
	return nil
end

local function cut(talent, say)
	local before = wait_of(talent)
	if before == nil then
		T.broken = true
		say_once(say, "unread", "Turn off sprint: the high-speed sprint's wait cannot be read, the high-speed sprint stays on")
		return
	end
	local addr = U.address(talent)
	local again = T.addr ~= nil and addr == T.addr
	-- An endless wait already there is the mod's own, from before a cutscene that gave the same character back.
	if before < NEVER / 2 then T.delay = before end
	pcall(function() talent.DelayTime = NEVER end)
	if (wait_of(talent) or 0) < NEVER / 2 then
		T.broken = true
		say_once(say, "refused", "Turn off sprint: the game refuses to change the high-speed sprint's wait, the high-speed "
			.. "sprint stays on")
		return
	end
	T.obj, T.addr = talent, addr
	if before >= NEVER / 2 then return end
	-- The game giving the wait back as often as it likes would fill the log: said once, then counted.
	if again then
		T.again = T.again + 1
		say_once(say, "again", "the game gave the high-speed sprint its wait back: made endless again (counted in the "
			.. "status line)")
	else
		say("the high-speed sprint turned off: its wait of %.2f s made endless", before)
	end
end

local function restore(say)
	local talent, addr, delay = T.obj, T.addr, T.delay or GAME_DELAY
	T.obj, T.addr, T.delay = nil, nil, nil
	if not U.is_valid(talent) or U.address(talent) ~= addr then return end
	pcall(function() talent.DelayTime = delay end)
	say("the high-speed sprint turned on again: its wait back to %.2f s", wait_of(talent) or delay)
end

-- Keeps the talent's wait endless: looked for once for each character, then checked every CHECK_EVERY seconds. Not
-- found (the skill not learned), it is looked for again when the character's abilities change in number: learning a
-- skill grants its ability (expected from the game's ability system, not verified in game), and a walk of them all
-- every few seconds, about 680 calls in one frame (the tests' fake game), would go on without end.
local function hold(pawn, now, say)
	if T.broken or (now < T.next and not T.refind) then return end
	T.next = now + CHECK_EVERY
	local kept = T.obj ~= nil and U.is_valid(T.obj) and U.address(T.obj) == T.addr
	if kept and not T.refind then
		if (wait_of(T.obj) or 0) < NEVER / 2 then cut(T.obj, say) end   -- the game gave its wait back
		return
	end
	local items, n = abilities(pawn)
	if T.obj == nil and not T.refind and n ~= nil and n == T.seen then return end
	T.refind = false
	local found = find(items)
	if T.obj ~= nil and (found == nil or U.address(found) ~= T.addr) then restore(say) end
	if found == nil then
		T.seen = n
		if n == nil then T.next, T.wait = now + T.wait, math.min(T.wait * 2, SLOWEST_LOOK) end
		say_once(say, "missing", "Turn off sprint: this character has no high-speed sprint's talent (its skill not "
			.. "learned?); looked for again when its abilities change")
		return
	end
	T.seen = nil
	cut(found, say)
end

-- high: the high-speed sprint to be off (Sprint or HighSpeedSprint); sprint: the sprint too (Sprint). ability: the
-- locomotion ability, nil while not found. Called while either is wanted or something is left to put back.
function M.frame(controller, pawn, ability, high, sprint, now, say)
	if high then
		hold(pawn, now, say)
	elseif T.obj ~= nil then
		restore(say)
	end
	if sprint then Keys.off(controller, ability, now, say) else Keys.on(controller, say) end
end

-- Something of the game is still changed: the frames must go on until it is put back.
function M.holding()
	return T.obj ~= nil or Keys.holding()
end

-- A new character: its talent is looked for at once. The one kept is put back when it is not the new one's.
function M.forget()
	T.refind, T.next, T.wait, T.said = true, 0, FIRST_LOOK, {}
end

-- For the status line: what the game gave back and the mod turned off again since the last one.
function M.report()
	local again = T.again
	T.again = 0
	return string.format("turned off again: the sprint's keys %d times, the high-speed sprint's wait %d times",
		Keys.rebuilds(), again)
end

return M
