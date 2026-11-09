-- Turn off sprint (Kevin, 7 November 2026), one row with three choices: Sprint turns off the sprint, and the high-speed
-- sprint with it; HighSpeedSprint turns off only the high-speed sprint, the faster sprint that follows 2 s of sprint
-- (skill Thousand-Mile Stride, talent GA_Talent_EnableIntoSuperSprint_C); None leaves both. Verified in game with
-- SprintCutProbe (7 November 2026, docs/mouvement/enquetes/2026-11-07-couper-le-sprint.md): the talent waits its
-- DelayTime of sprint before the high-speed sprint, and an endless wait on the character's instance keeps it from
-- coming; the sprint's keys are turned off by movement_sprint_keys.lua. High-speed sprint delay (Kevin, 9 November
-- 2026) sets the same wait to 1 to 8 s instead (not verified in game). Everything is put back exactly when neither row
-- asks for it any more or the mod is turned off; nothing is written to disk.

local U = require("movement_unreal")
local Keys = require("movement_sprint_keys")

local M = {}

local NEVER = 1e9            -- seconds: the talent's wait never ends
local GAME_DELAY = 2         -- the talent's own wait in the game's files, put back when the one before is not known
local SAME = 1e-3            -- seconds: a wait this close to another is the same
local TALENT = "EnableIntoSuperSprint"
local MAX_ABILITIES = 512    -- the player has about 135
local CHECK_EVERY = 1        -- seconds between two checks that the talent keeps the mod's wait, or, while it is not
                             -- found, that the character's abilities are as many as at the last look
-- Seconds between looks for a talent not found while the abilities cannot be counted, doubled each time: a look walks
-- the 135 abilities (677 calls in the tests' fake game).
local FIRST_LOOK, SLOWEST_LOOK = 1, 8

-- obj, addr: the talent holding the mod's wait; delay: its own wait before; written: the wait the mod wrote. target: the
-- wait asked for now (NEVER for none), row: the row asking, for the log. next: the clock of the next check or look;
-- wait: seconds between looks while the talent is not found and the abilities not counted; seen: their count at a look
-- that found no talent. refind: a new character, looked for at once. broken: the game refuses the change. said: lines
-- said once for each character. again: the waits the game gave back to the talent kept, set again since the last
-- status line.
local T = { obj = nil, addr = nil, delay = nil, written = nil, target = nil, row = nil, next = 0, wait = FIRST_LOOK,
	seen = nil, refind = true, broken = false, said = {}, again = 0 }

local function say_once(say, what, fmt, ...)
	if T.said[what] then return end
	T.said[what] = true
	say(fmt, ...)
end

local function close(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) <= SAME
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

-- Gives the talent the wait asked for. changed: the row asks for another wait than the one the mod wrote.
local function set(talent, say, changed)
	local before = wait_of(talent)
	if before == nil then
		T.broken = true
		say_once(say, "unread", "%s: the high-speed sprint's wait cannot be read, it stays as in the game", T.row)
		return
	end
	local addr = U.address(talent)
	-- A wait the mod wrote is not the game's: a cutscene gives the same character back with it, and an endless one is
	-- always the mod's.
	local mine = before >= NEVER / 2 or (addr == T.addr and close(before, T.written))
	-- The game put its own wait back on the talent the mod holds (or on the same character given back).
	local again = not mine and addr == T.addr and T.written ~= nil
	if not mine then T.delay = before end
	if not close(before, T.target) then
		pcall(function() talent.DelayTime = T.target end)
		if not close(wait_of(talent), T.target) then
			T.broken = true
			say_once(say, "refused", "%s: the game refuses to change the high-speed sprint's wait, it stays as in the "
				.. "game", T.row)
			return
		end
	end
	T.obj, T.addr, T.written = talent, addr, T.target
	if again then
		-- The game giving it back as often as it likes would fill the log: said once, then counted.
		T.again = T.again + 1
		say_once(say, "again", "the game gave the high-speed sprint its wait back: %s (counted in the status line)",
			T.target >= NEVER / 2 and "made endless again" or "set again")
		return
	end
	if mine and not changed then return end
	local game = T.delay or before
	if T.target >= NEVER / 2 then
		say("the high-speed sprint turned off: its wait of %.2f s made endless", game)
	else
		say("the high-speed sprint's wait set to %.1f s (the game's %.2f s)", T.target, game)
	end
end

local function restore(say)
	local talent, addr, delay, written = T.obj, T.addr, T.delay or GAME_DELAY, T.written
	T.obj, T.addr, T.delay, T.written = nil, nil, nil, nil
	if not U.is_valid(talent) or U.address(talent) ~= addr then return end
	pcall(function() talent.DelayTime = delay end)
	if (written or 0) >= NEVER / 2 then
		say("the high-speed sprint turned on again: its wait back to %.2f s", wait_of(talent) or delay)
	else
		say("the high-speed sprint's wait back to the game's %.2f s", wait_of(talent) or delay)
	end
end

-- Keeps the talent's wait at the target: looked for once for each character, then checked every CHECK_EVERY seconds.
-- Not found (the skill not learned), it is looked for again when the character's abilities change in number: learning
-- a skill grants its ability (expected from the game's ability system, not verified in game), and a walk of them all
-- every few seconds, about 680 calls in one frame (the tests' fake game), would go on without end.
local function hold(pawn, now, say)
	if T.broken or (now < T.next and not T.refind) then return end
	T.next = now + CHECK_EVERY
	local kept = T.obj ~= nil and U.is_valid(T.obj) and U.address(T.obj) == T.addr
	if kept and not T.refind then
		if not close(wait_of(T.obj), T.written) then
			set(T.obj, say)   -- the game gave its wait back
		elseif not close(T.written, T.target) then
			set(T.obj, say, true)
		end
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
		say_once(say, "missing", "%s: this character has no high-speed sprint's talent (its skill not learned?); looked "
			.. "for again when its abilities change", T.row)
		return
	end
	T.seen = nil
	set(found, say)
end

-- high: the high-speed sprint to be off (Sprint or HighSpeedSprint); delay: its wait in seconds, nil for the game's;
-- sprint: the sprint off too (Sprint). ability: the locomotion ability, nil while not found. Called while one of them
-- is wanted or something is left to put back.
function M.frame(controller, pawn, ability, high, delay, sprint, now, say)
	local target = high and NEVER or delay
	if target ~= nil then
		-- A changed row is taken at once, not at the next check.
		if target ~= T.target then T.next = 0 end
		T.target, T.row = target, high and "Turn off sprint" or "High-speed sprint delay"
		hold(pawn, now, say)
	else
		T.target = nil
		if T.obj ~= nil then restore(say) end
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
