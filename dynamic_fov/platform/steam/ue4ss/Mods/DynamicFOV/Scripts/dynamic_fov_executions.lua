-- Whether the player is in an execution, given or taken: the camera is then the game's, place and field of view
-- (1.0.7). The player's tasks (dynamic_fov_tasks.lua) whose ability is an execution's
-- (dynamic_fov_execution_family.lua) start one, followed until the ability's bIsActive goes false. For an instanced
-- ability, the engine sets it as the ability starts, before the ability makes its tasks, and clears it as the ability
-- ends (GameplayAbility.cpp, PreActivate and EndAbility, Unreal 5.5); a non-instanced one keeps it false and would not
-- be followed (the 16 executions of the trial of 10 November 2026 were). The abilities followed are kept from tick to
-- tick, each checked valid and of the same class at each use.

local U = require("dynamic_fov_unreal")
local Tasks = require("dynamic_fov_tasks")
local Family = require("dynamic_fov_execution_family")
-- The pause as the panel reads it: one place asks the game.
local Game = require("dynamic_fov_panel_game")

local M = {}

local MAX_FOLLOWED = 8       -- executions followed at once; a second part can start before the first ends
-- Seconds of play, the game not paused, after which an execution still on lets the camera go back, said: the longest
-- seen lasted 8.2 s (one taken, 10 November 2026), and an ability the game would leave on must not keep the game's
-- camera for good. The player controller ticks while the game is paused (PlayerController.cpp, Unreal 5.5): a pause
-- during an execution is not counted.
local MAX_SECONDS = 30

-- followed: ability address -> { ability, class (address), name, on = seconds of play since it started }; n: their
-- number; started: the clock when the first began; asc: the address of the ability system the followed ones belong
-- to; seen: executions since the last count; last: the clock at the last tick. T: the mod's lines
-- (dynamic_fov_status.lua), given at each tick.
local E = { followed = {}, n = 0, started = nil, asc = nil, seen = 0, said = {}, last = nil, T = nil }

-- Named functions for pcall rather than a new closure at each tick.
local function asc_of(pc) return pc.Pawn.AbilitySystemComponent end
local function task_asc(task) return task.AbilitySystemComponent end
local function task_ability(task) return task.Ability end
local function weak_get(v) return v:Get() end
local function is_active(ability) return ability.bIsActive end

local function report(fmt, ...)
	E.T.bounded("execution", fmt, ...)
end

local function problem(fmt, ...)
	E.T.bounded("execution problem", fmt, ...)
end

local function once(key, fmt, ...)
	if E.said[key] then return end
	E.said[key] = true
	problem(fmt, ...)
end

local function player_asc(pc)
	local ok, asc = pcall(asc_of, pc)
	if not ok or not U.is_valid(asc) then return nil end
	return U.address(asc)
end

-- The address of the ability system a task belongs to. UE4SS gives the field as the object or as a weak pointer (both
-- seen by Movement Tuning); a weak pointer's IsValid says true whatever it points to, and it has no address of its own
-- (UE4SS's documentation): then what its Get gives.
local function owner(task)
	local ok, v = pcall(task_asc, task)
	if not ok or v == nil then return nil end
	if U.is_valid(v) then
		local addr = U.address(v)
		if addr ~= nil then return addr end
	end
	local okg, got = pcall(weak_get, v)
	return okg and U.is_valid(got) and U.address(got) or nil
end

-- true or false, nil when it cannot be read.
local function active(ability)
	local ok, v = pcall(is_active, ability)
	if not ok or type(v) ~= "boolean" then return nil end
	return v
end

local function clear()
	E.followed, E.n, E.started = {}, 0, nil
end

-- A task of the player's whose ability is an execution's, still on: followed from now.
local function adopt(task, asc, now)
	if not U.is_valid(task) or owner(task) ~= asc then return end
	local ok, ability = pcall(task_ability, task)
	if not ok or not U.is_valid(ability) then return end
	local addr = U.address(ability)
	if addr == nil or E.followed[addr] ~= nil then return end
	local execution, name, class = Family.of(ability, problem)
	if not execution then return end
	local on = active(ability)
	if on == nil then
		once("active", "execution watch: whether %s is on cannot be read; the camera stays the player's "
			.. "during executions", name)
	end
	if on ~= true then return end
	if E.n >= MAX_FOLLOWED then
		once("full", "execution watch: %d executions at once, %s is not followed", E.n, name)
		return
	end
	E.followed[addr] = { ability = ability, class = class, name = name, on = 0 }
	E.n, E.seen = E.n + 1, E.seen + 1
	if E.n == 1 then
		E.started = now
		report("execution %s: the game's camera, place and field of view", name)
	else
		report("execution %s, during another", name)
	end
end

-- Why a followed execution is over, or nil while it goes on.
local function over(entry)
	if Family.class_address(entry.ability) ~= entry.class then return "its ability is gone" end
	if active(entry.ability) ~= true then return "" end
	if entry.on >= MAX_SECONDS then return string.format("still on after %d s", MAX_SECONDS) end
	return nil
end

-- At each tick. pc: the player controller; now: os.clock(); T: the mod's lines, which hear of each execution's start
-- and end and of what cannot be read. Returns whether the player is in an execution. Off, it asks nothing of the
-- game.
function M.tick(pc, now, T)
	E.T = T
	local step = E.last and math.max(0, now - E.last) or 0
	E.last = now
	local list, count = Tasks.take()
	if list == nil and E.n == 0 then return false end
	if list ~= nil then
		local asc = player_asc(pc)
		-- Another pawn's ability system: the executions followed were the old pawn's. One that cannot be read this tick
		-- changes nothing.
		if asc ~= nil then
			if asc ~= E.asc then clear() end
			E.asc = asc
			for i = 1, count do adopt(list[i], asc, now) end
		end
	end
	local paused = E.n > 0 and Game.paused(pc) == true
	local why = nil
	for addr, entry in pairs(E.followed) do
		if not paused then entry.on = entry.on + step end
		local reason = over(entry)
		if reason ~= nil then
			E.followed[addr], E.n, why = nil, E.n - 1, reason
		end
	end
	if E.n == 0 and E.started ~= nil then
		report("execution over after %.1f s%s: the player's camera back", now - E.started,
			why ~= "" and string.format(" (%s)", why) or "")
		E.started = nil
	end
	return E.n > 0
end

-- At start. What cannot be watched is said in the log.
function M.watch(log)
	local ok, err = Tasks.watch()
	if not ok then
		log("executions cannot be watched (%s): the camera stays the player's during them", tostring(err))
	end
end

-- The mod on or off: off, nothing is watched nor followed.
function M.set_on(on)
	Tasks.set_on(on)
	if not on then clear() end
end

-- A load: nothing followed, the classes read anew.
function M.reset()
	clear()
	E.asc = nil
	Family.forget()
end

-- Executions started since the last call.
function M.seen()
	local n = E.seen
	E.seen = 0
	return n
end

return M
