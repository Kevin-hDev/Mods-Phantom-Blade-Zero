-- The controller in the open panel, read from the player controller while the panel's input context is on
-- (dynamic_fov_panel_context.lua): the D-pad, Cross, Triangle and Circle read held (IsInputKeyDown), a press being held
-- now and not at the last read; the left stick's four directions read from its two axes (GetInputAnalogKeyState). As
-- buttons, the stick's directions never reach the player controller: the game's interface (CommonUI's analog cursor)
-- takes their presses first (verified in game; Unreal 5.7, AnalogCursor.cpp). A direction is
-- held from PRESS on and let go under RELEASE, so a stick resting near the line does not press again and again; of the
-- two axes only the one pushed further counts, so a diagonal moves the row or changes the value, never both. Only the
-- buttons the panel uses are read: nine calls a frame.

local PanelCalls = require("dynamic_fov_panel_calls")
local Names = require("dynamic_fov_panel_pad_names")

local M = {}

-- Of a full push. Slate's own navigation by the stick starts at 0.5 (NavigationConfig.cpp, lines 13 and 134).
local PRESS, RELEASE = 0.5, 0.3
local X, Y = "Gamepad_LeftX", "Gamepad_LeftY"
local READ = { Names.UP, Names.DOWN, Names.LEFT, Names.RIGHT, Names.CROSS, Names.TRIANGLE, Names.CIRCLE }
-- Each stick direction: its axis, and the sign of a push that way (the engine's: up and right positive).
local DIRECTIONS = { [Names.STICK_UP] = { Y, 1 }, [Names.STICK_DOWN] = { Y, -1 }, [Names.STICK_LEFT] = { X, -1 },
	[Names.STICK_RIGHT] = { X, 1 } }

local fnames = {}
-- down[name]: held at the last read. pressed: the presses of the last read. Both used again, read only outside.
local S = { down = {}, pressed = {} }

local function key(name)
	if fnames[name] == nil then
		local ok, v = pcall(FName, name)
		if ok then fnames[name] = { KeyName = v } end
	end
	return fnames[name]
end

local function held(pc, k) return pc:IsInputKeyDown(k) end
local function analog(pc, k) return pc:GetInputAnalogKeyState(k) end

local function axis(pc, name)
	local k = key(name)
	if k == nil then return 0 end
	local ok, v = pcall(analog, pc, k)
	return ok and type(v) == "number" and v or 0
end

-- Whether the buttons can be read at all; asked of the game once (dynamic_fov_panel_calls.lua).
function M.usable()
	return PanelCalls.ok(PanelCalls.KEY_DOWN)
end

-- Reads every button and direction into S.down; returns the presses since the last read.
local function read(pc)
	for i = #S.pressed, 1, -1 do S.pressed[i] = nil end
	for _, name in ipairs(READ) do
		local k = key(name)
		local ok, yes = false, false
		if k ~= nil then ok, yes = pcall(held, pc, k) end
		local now = ok and yes == true
		if now and not S.down[name] then S.pressed[#S.pressed + 1] = name end
		S.down[name] = now
	end
	-- Without the axes' function, the stick does nothing in the panel; the D-pad still does.
	local x, y = 0, 0
	if PanelCalls.ok(PanelCalls.ANALOG) then x, y = axis(pc, X), axis(pc, Y) end
	local ax, ay = math.abs(x), math.abs(y)
	for name, d in pairs(DIRECTIONS) do
		local own = (d[1] == X and x or y) * d[2]
		local first = d[1] == Y and ay >= ax or d[1] == X and ax > ay
		S.down[name] = first and own >= (S.down[name] and RELEASE or PRESS)
	end
	return S.pressed
end

-- At the panel's opening: what is held then is noted, so it makes no press. Returns the buttons held.
function M.start(pc)
	for name in pairs(S.down) do S.down[name] = false end
	read(pc)
	return S.down
end

-- At each frame of the open panel: the buttons held (by engine name) and those pressed since the last read.
function M.read(pc)
	local pressed = read(pc)
	return S.down, pressed
end

return M
