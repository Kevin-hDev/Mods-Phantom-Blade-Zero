-- The left stick's four directions in the open panel, read from its two axes (D86). As buttons they never reach the
-- player controller while the game uses the controller: the game's interface (CommonUI's analog cursor) takes their
-- presses first, to keep the stick for its cursor (Unreal 5.7, AnalogCursor.cpp line 46, from CommonAnalogCursor.cpp
-- line 368), and the 0.3.0 trial counted none while it counted the D-pad and the right stick. The axes go through:
-- the cursor keeps them only while it moves with the stick, a mode the engine turns on in its test builds alone
-- (CommonAnalogCursor.cpp lines 334 and 428). A direction is held from PRESS on and let go under RELEASE, so a stick
-- resting near the line does not press again and again. Of the two axes, only one counts, so a diagonal moves the row
-- or changes the value, never both: the one pushed further, or while a direction is held, its axis until the other
-- passes it by MARGIN (audit of 0.4.3: a thumb trembling near the diagonal swapped them, each swap a press).

local Calls = require("mod_panel_calls")

local M = {}

-- Of a full push. Slate's own navigation by the stick starts at 0.5 (NavigationConfig.cpp, lines 13 and 134).
local PRESS, RELEASE = 0.5, 0.3
local MARGIN = 0.2
local X, Y = "Gamepad_LeftX", "Gamepad_LeftY"
-- Each direction by its engine name: its axis, and the sign of a push that way (the engine's: up and right positive).
M.DIRECTIONS = { Gamepad_LeftStick_Up = { Y, 1 }, Gamepad_LeftStick_Down = { Y, -1 },
	Gamepad_LeftStick_Left = { X, -1 }, Gamepad_LeftStick_Right = { X, 1 } }

-- held[name]: the direction held at the last read; push: how far the stick was pushed then, nil when not read; lead:
-- the axis of the direction held then, nil when none was.
local S = { held = {}, push = nil, lead = nil }

local function value(pc, k) return pc:GetInputAnalogKeyState(k) end

local function axis(pc, key, name)
	local k = key(name)
	if k == nil then return 0 end
	local ok, v = pcall(value, pc, k)
	return ok and type(v) == "number" and v or 0
end

-- Reads both axes once, key(name) giving the engine's key for a name (mod_panel_pad.lua). Returns whether each
-- direction is held now, by its engine name, in a table used again: read only.
function M.read(pc, key)
	if not Calls.ok(Calls.ANALOG) then
		for name in pairs(M.DIRECTIONS) do S.held[name] = false end
		S.push, S.lead = nil, nil
		return S.held
	end
	local x, y = axis(pc, key, X), axis(pc, key, Y)
	local ax, ay = math.abs(x), math.abs(y)
	S.push = math.max(ax, ay)
	local lead = S.lead
	if lead == nil or (lead == Y and ax > ay + MARGIN) or (lead == X and ay > ax + MARGIN) then
		lead = ay >= ax and Y or X
	end
	S.lead = nil
	for name, d in pairs(M.DIRECTIONS) do
		local own = (d[1] == X and x or y) * d[2]
		S.held[name] = d[1] == lead and own >= (S.held[name] and RELEASE or PRESS)
		if S.held[name] then S.lead = lead end
	end
	return S.held
end

-- At the panel's opening, before its first read: nothing held, so a push then is judged from PRESS.
function M.start()
	for name in pairs(M.DIRECTIONS) do S.held[name] = false end
	S.lead = nil
end

-- How far the stick was pushed at the last read, from 0 to 1, or nil when its axes cannot be read.
function M.push() return S.push end

return M
