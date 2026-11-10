-- The game's ability tasks as it makes them: UE4SS's NotifyOnNewObject calls the mod for each one, the player's and
-- the enemies', and an ability makes its tasks as it starts. Kept here until the next tick reads them, a tenth of a
-- second later at most: a callback is kept short. Its Lua runs under UE4SS's lock, as the controller's tick hook does
-- (dynamic_fov_driver.lua).

local M = {}

-- The engine's class, the parent of every ability task (Movement Tuning watches the same, seen in game).
M.CLASS = "/Script/GameplayAbilities.AbilityTask"
-- Tasks waiting; past this the list starts over: they come from a time without ticks (a load, a menu), and are over.
local MAX_PENDING = 64

local P = { list = {}, n = 0, on = false }

local function made(task)
	if not P.on then return end
	if P.n >= MAX_PENDING then P.list, P.n = {}, 0 end
	P.n = P.n + 1
	P.list[P.n] = task
end

-- At start: whether the tasks are watched, and the error when not.
function M.watch()
	return pcall(NotifyOnNewObject, M.CLASS, made)
end

-- Off (the mod off), the tasks made are not kept.
function M.set_on(on)
	P.on = on
	if not on then P.list, P.n = {}, 0 end
end

-- The tasks made since the last call and their number, or nil; the list starts over first, so a task made while the
-- mod reads the taken one goes to the new list.
function M.take()
	if P.n == 0 then return nil end
	local list, n = P.list, P.n
	P.list, P.n = {}, 0
	return list, n
end

return M
