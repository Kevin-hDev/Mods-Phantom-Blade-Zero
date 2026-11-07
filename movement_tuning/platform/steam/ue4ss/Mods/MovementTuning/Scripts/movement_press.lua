-- The only presser of the game's actions (the sprint for auto sprint, the walk in movement_walk.lua): Enhanced Input's
-- InjectInputVectorForAction on the player's input subsystem, which the game takes as the action's button pressed for
-- that frame (verified in game, 5 November 2026). Nothing of the game is written.

local U = require("movement_unreal")

local M = {}

local PRESS = { X = 1.0, Y = 0.0, Z = 0.0 }   -- a button's value: Enhanced Input takes X for a boolean action
local NO_MODIFIERS, NO_TRIGGERS = {}, {}
local MAX_SEARCHES = 16   -- looks for the subsystem in a row that find nothing, before looking only every SLOW_SEARCH:
local SLOW_SEARCH = 30    -- seconds. FindFirstOf walks the game's objects until it finds one, a whole walk when absent

-- The player's input subsystem, looked for again whenever it is not valid (a new one after a load). misses: looks in a
-- row that found nothing; last: the clock of the last look.
local G = { subsystem = nil, misses = 0, last = nil }

-- A new character: the subsystem is looked for at once again.
function M.forget()
	G.misses, G.last = 0, nil
end

-- Presses action for this frame. Returns true when pressed; false and nil when the subsystem or the action is not
-- there (yet); false and the error when the press itself fails.
function M.action(action)
	-- Checked each time: UE4SS calls a function on an object by its address, gone or not.
	if not U.is_valid(G.subsystem) then
		local now = os.clock()
		if G.misses >= MAX_SEARCHES and now - G.last < SLOW_SEARCH then return false, nil end
		G.last = now
		pcall(function() G.subsystem = FindFirstOf("EnhancedInputLocalPlayerSubsystem") end)
		if not U.is_valid(G.subsystem) then
			G.misses = G.misses + 1
			return false, nil
		end
		G.misses = 0
	end
	if not U.is_valid(action) then return false, nil end
	local ok, err = pcall(function()
		G.subsystem:InjectInputVectorForAction(action, PRESS, NO_MODIFIERS, NO_TRIGGERS)
	end)
	return ok, not ok and err or nil
end

return M
