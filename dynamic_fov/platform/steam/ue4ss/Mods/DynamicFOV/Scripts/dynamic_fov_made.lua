-- Objects of one class as the game makes them: UE4SS's NotifyOnNewObject calls the mod for each new object of the
-- class, or of one that comes from it. Kept here until the mod reads them, a frame or a tick later: a callback is kept
-- short. Its Lua runs under UE4SS's lock, as the controller's tick hook does (dynamic_fov_driver.lua). The engine does
-- not hold an object for the mod: whoever takes the list checks that each one still exists before any use.

local M = {}

-- Objects waiting; past this the list starts over: they come from a time without ticks (a load, a menu), and are over.
local MAX_PENDING = 64

-- class: the engine's path of the class. Returns its watcher, off until set_on(true).
function M.new(class)
	local W = { CLASS = class }
	local P = { list = {}, n = 0, on = false }

	local function made(obj)
		if not P.on then return end
		if P.n >= MAX_PENDING then P.list, P.n = {}, 0 end
		P.n = P.n + 1
		P.list[P.n] = obj
	end

	-- At start: whether the objects are watched, and the error when not.
	function W.watch()
		return pcall(NotifyOnNewObject, class, made)
	end

	-- Off, the objects made are not kept.
	function W.set_on(on)
		P.on = on
		if not on then P.list, P.n = {}, 0 end
	end

	-- Whether objects made wait to be taken: asks nothing of the game.
	function W.waiting()
		return P.n > 0
	end

	-- The objects made since the last call and their number, or nil; the list starts over first, so an object made
	-- while the mod reads the taken one goes to the new list.
	function W.take()
		if P.n == 0 then return nil end
		local list, n = P.list, P.n
		P.list, P.n = {}, 0
		return list, n
	end

	return W
end

return M
