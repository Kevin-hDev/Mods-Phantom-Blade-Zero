-- Toggle sprint (Kevin, 9 November 2026): a press of the button picked in the menu starts the sprint, the next press
-- stops it. The sprint itself is pressed by movement_sprint.lua, as auto sprint's. It also stops when the player stops:
-- a sprint left on would start again at the next push of the stick, unasked. And when the game walks (its walk key).

local U = require("movement_unreal")
local Buttons = require("movement_buttons")

local M = {}

local REST = 0.1       -- the left stick's travel under which the player is stopping
local REST_FOR = 0.3   -- seconds the stick stays there before the sprint stops: a stick swung through its centre to
                       -- turn round keeps the sprint

-- on: the sprint wanted. down: each button's state at the last read, by name; fresh: down not read yet, so a button
-- already held when the row is chosen is no press. rest: since when the stick is at rest. turns: sprints toggled on,
-- for the status line.
local T

function M.forget()
	T = { on = false, down = {}, fresh = true, rest = nil, turns = T and T.turns or 0 }
end
M.forget()

local function names(toggle)
	local list = {}
	if toggle.pad ~= nil then list[#list + 1] = toggle.pad end
	if toggle.key ~= nil then list[#list + 1] = toggle.key end
	return list
end

-- A press that starts now on any of the buttons; the reads are kept for the next frame.
local function pressed(controller, list)
	local any = false
	for _, name in ipairs(list) do
		local key = Buttons.key(name)
		local down = key ~= nil and U.key_down(controller, key)
		if down and not T.down[name] and not T.fresh then any = true end
		T.down[name] = down
	end
	T.fresh = false
	return any
end

-- toggle: { pad, key }, the buttons' names (nil for None), nil when the mode is not Toggle. travel: the left stick's,
-- nil when unread. walking: the game walks. Returns true while the sprint is wanted.
function M.frame(controller, toggle, travel, walking, now)
	if toggle == nil then
		T.on, T.down, T.fresh, T.rest = false, {}, true, nil
		return false
	end
	local list = names(toggle)
	if #list == 0 then return false end
	if pressed(controller, list) then
		T.on, T.rest = not T.on, nil
		if T.on then T.turns = T.turns + 1 end
	end
	if walking then T.on = false end
	if T.on and travel ~= nil then
		if travel >= REST then
			T.rest = nil
		else
			T.rest = T.rest or now
			if now - T.rest >= REST_FOR then T.on = false end
		end
	end
	return T.on
end

function M.report()
	local n = T.turns
	T.turns = 0
	return n
end

return M
