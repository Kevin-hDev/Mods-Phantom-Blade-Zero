-- The controller's commands in the open panel, from the buttons dynamic_fov_panel_pad.lua read: the D-pad and the left
-- stick move the chosen row (up, down) and change its value (left, right); Cross turns a switch over or takes the next
-- choice (enter), Triangle restores the defaults, Circle closes. Up and down held go on: a step at the press, one at
-- HOLD_DELAY, then one every HOLD_EVERY. Left and right are not counted: held, they are the side held of
-- dynamic_fov_panel_changes.lua, which steps a number faster and faster and a switch or a choice once. A direction of
-- the D-pad and the same of the stick held together count once; two opposite ones, none, and the one still held when
-- the other is let go starts again as a new press. What is held when the panel opens does nothing until let go.

local Names = require("dynamic_fov_panel_pad_names")

local M = {}

M.HOLD_DELAY, M.HOLD_EVERY = 0.4, 0.1
M.COUNTS = { "up", "down", "left", "right", "enter", "restore", "close" }

-- The buttons of each command that acts while held.
local HELD = {
	up = { Names.UP, Names.STICK_UP },
	down = { Names.DOWN, Names.STICK_DOWN },
	left = { Names.LEFT, Names.STICK_LEFT },
	right = { Names.RIGHT, Names.STICK_RIGHT },
}
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
local SIDES = { left = -1, right = 1 }
local PRESSED = { [Names.CROSS] = "enter", [Names.TRIANGLE] = "restore", [Names.CIRCLE] = "close" }
local WAIT = math.huge            -- a due time: held at the opening, nothing until let go

-- due[c]: while command c is held, when it steps next (WAIT: never); nil while it is not. out: the counts, a table
-- used again. side: -1 or 1 while left or right is held, else nil.
local S = { due = {}, out = {}, side = nil }

local function held(down, c)
	for _, name in ipairs(HELD[c]) do
		if down[name] then return true end
	end
	return false
end

-- At the panel's opening, down the buttons held then.
function M.start(down)
	S.side = nil
	for c in pairs(HELD) do S.due[c] = held(down, c) and WAIT or nil end
end

-- Whether held command c steps now: at its press, then on its due times.
local function steps(c, now)
	local due = S.due[c]
	if due == nil then
		S.due[c] = now + M.HOLD_DELAY
		return true
	end
	if now < due then return false end
	S.due[c] = now + M.HOLD_EVERY
	return true
end

-- At each frame of the open panel: down, the buttons held; pressed, those pressed since the last read; now, the clock.
-- Returns the counts (left and right always 0: those are the side), or nil when there are none; and whether any
-- button the panel uses acted, the side included.
function M.take(down, pressed, now)
	local out, any = S.out, false
	for _, c in ipairs(M.COUNTS) do out[c] = 0 end
	S.side = nil
	for c in pairs(HELD) do
		if not held(down, c) then
			S.due[c] = nil
		elseif held(down, OPPOSITE[c]) then
			-- Else the one left would go on at once, with no first delay (audit of 1.0.5).
			if S.due[c] ~= WAIT then S.due[c] = nil end
		elseif S.due[c] ~= WAIT then
			local side = SIDES[c]
			if side ~= nil then
				S.side = side
			elseif steps(c, now) then
				out[c], any = out[c] + 1, true
			end
		end
	end
	for _, name in ipairs(pressed) do
		local c = PRESSED[name]
		if c ~= nil then out[c], any = out[c] + 1, true end
	end
	return any and out or nil, any or S.side ~= nil
end

-- -1 or 1 while left or right is held alone, else nil.
function M.side() return S.side end

return M
