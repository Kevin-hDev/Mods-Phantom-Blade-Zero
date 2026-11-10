-- The controller's commands in the open panel, made from the buttons mod_panel_pad.lua read: the same counts as the
-- keyboard's (mod_panel_keys.lua), so a button does in the panel what its key does. The D-pad and the left stick move
-- the chosen row (up, down) and change its value (left, right); L1 and R1 go to the mod before or after; L2 and R2 go
-- to the first and the last row of the page (D99); Cross chooses (enter), Triangle restores the defaults, Square hides
-- or shows the descriptions (D91), R3 makes the chosen mod a favourite or undoes it (D178), Circle is escape: it
-- closes, or comes back to the list in a mod's page of the Classic navigation (D130). Up, down, L1 and R1 held go on:
-- a step at the press, one at HOLD_DELAY, then one every HOLD_EVERY (D59's delays). Left and right are not counted:
-- held, they are the arrow held of mod_panel_changes.lua, which steps a number faster and faster and a switch or a
-- choice once, as the mouse's arrow does. A direction of the D-pad and the same of the stick held together count once;
-- two opposite ones, none. What is held when the panel opens does nothing until let go.

local L = require("mod_panel_layout")
local Keys = require("mod_panel_keys")

local M = {}

-- The buttons of each command that acts while held.
local HELD = {
	up = { "Gamepad_DPad_Up", "Gamepad_LeftStick_Up" },
	down = { "Gamepad_DPad_Down", "Gamepad_LeftStick_Down" },
	left = { "Gamepad_DPad_Left", "Gamepad_LeftStick_Left" },
	right = { "Gamepad_DPad_Right", "Gamepad_LeftStick_Right" },
	prev = { "Gamepad_LeftShoulder" },
	next = { "Gamepad_RightShoulder" },
}
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left", prev = "next", next = "prev" }
local SIDES = { left = -1, right = 1 }
-- The command a press makes, by button.
local PRESSED = { Gamepad_FaceButton_Bottom = "enter", Gamepad_FaceButton_Top = "restore",
	Gamepad_FaceButton_Right = "escape", Gamepad_FaceButton_Left = "descriptions", Gamepad_LeftTrigger = "top",
	Gamepad_RightTrigger = "bottom", Gamepad_RightThumbstick = "favorite" }
-- The buttons whose command gives way to the panel's button and combination (D178): R3 chosen to open the panel, alone
-- or with another button, still closes it, as before 1.0.2, and makes no favourite.
local YIELDS = { Gamepad_RightThumbstick = true }
local WAIT = math.huge            -- a due time: held at the opening, nothing until let go

-- due[c]: while command c is held, when it steps next (WAIT: never); nil while it is not. out: the counts, a table
-- used again. side: -1 or 1 while left or right is held, else nil. yielded[name]: the button of YIELDS called name
-- gives way now.
local S = { due = {}, out = {}, side = nil, yielded = {} }

local function held(down, c)
	for _, name in ipairs(HELD[c]) do
		if down[name] then return true end
	end
	return false
end

-- At the panel's opening, down the buttons held then (mod_panel_pad.lua).
function M.start(down)
	S.side = nil
	for c in pairs(HELD) do S.due[c] = held(down, c) and WAIT or nil end
end

-- Whether held command c steps now: at its press, then on its due times.
local function steps(c, now)
	local due = S.due[c]
	if due == nil then
		S.due[c] = now + L.HOLD_DELAY
		return true
	end
	if now < due then return false end
	S.due[c] = now + L.HOLD_EVERY
	return true
end

-- At each frame of the open panel: down, the buttons held; pressed, those pressed since the last read, by their
-- engine names; now, the clock; button and pair, the panel's button and combination (nil for none). Returns the counts
-- as Keys.take() gives them, or nil when there are none.
function M.take(down, pressed, now, button, pair)
	local out, any = S.out, false
	M.give_way(button, pair)
	for _, c in ipairs(Keys.COUNTS) do out[c] = 0 end
	S.side = nil
	for c in pairs(HELD) do
		if not held(down, c) then
			S.due[c] = nil
		elseif not held(down, OPPOSITE[c]) then
			local side = SIDES[c]
			if side ~= nil then
				if S.due[c] ~= WAIT then S.side, S.due[c] = side, now end
			elseif steps(c, now) then
				out[c], any = out[c] + 1, true
			end
		end
	end
	for _, name in ipairs(pressed) do
		local c = not S.yielded[name] and PRESSED[name] or nil
		if c ~= nil then out[c], any = out[c] + 1, true end
	end
	return any and out or nil
end

-- -1 or 1 while left or right is held alone, else nil.
function M.side() return S.side end

-- Which buttons of YIELDS give way to the panel's button and combination (nil for none): at each opening, before the
-- first paint, and at each frame, as they may change in Mod Panel's own page.
function M.give_way(button, pair)
	for name in pairs(YIELDS) do
		S.yielded[name] = name == button or pair ~= nil and (name == pair[1] or name == pair[2])
	end
end

local COMMANDS = {}
for _, names in pairs(HELD) do
	for _, name in ipairs(names) do COMMANDS[name] = true end
end
for name in pairs(PRESSED) do COMMANDS[name] = not YIELDS[name] end

-- Whether the button called name makes a command of the panel that never gives way to the panel's button.
function M.commands(name)
	return COMMANDS[name] == true
end

-- Whether the button called name makes its command now: not when it gives way to the panel's button (YIELDS).
function M.acts(name)
	return S.yielded[name] ~= true
end

return M
