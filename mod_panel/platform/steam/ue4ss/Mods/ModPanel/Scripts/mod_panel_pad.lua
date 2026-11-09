-- The controller, read from the player controller. The panel's button is read as "just pressed"
-- (WasInputKeyJustPressed, D67): a press of Create lasts about 10 ms (PadProbe), less than a frame at 60 frames a
-- second, and the engine keeps a press until the end of the frame it came in (Unreal 5.7, PlayerInput.cpp,
-- WasJustPressed). While the panel is open with its input context on (D66), every button is read held (IsInputKeyDown),
-- a press being held now and not at the last read, but Create, read "just pressed" there too (D85), and the left
-- stick's directions, read from its axes (mod_panel_stick.lua, D86). A key name becomes an FName once, and each button
-- is read once a frame at most.

local Calls = require("mod_panel_calls")
local Names = require("mod_panel_pad_names")
local Stick = require("mod_panel_stick")
local Flush = require("mod_panel_flush")

local M = {}

local fnames = {}
-- down[name]: held at the last read. kept[name]: held when the panel last let go of the keys, and not read held
-- since (D142); flushes: the lettings go seen (mod_panel_flush.lua).
local S = { down = {}, kept = {}, flushes = 0 }

local function key(name)
	if fnames[name] == nil then
		local ok, v = pcall(FName, name)
		if ok then fnames[name] = { KeyName = v } end
	end
	return fnames[name]
end

local function just_pressed(pc, k) return pc:WasInputKeyJustPressed(k) end
local function held(pc, k) return pc:IsInputKeyDown(k) end

-- Whether the panel's button can be read at all; asked of the game once (mod_panel_calls.lua).
function M.usable()
	return Calls.ok(Calls.JUST_PRESSED)
end

-- Whether the button called name was pressed during this frame.
function M.pressed(pc, name)
	local k = key(name)
	if k == nil then return false end
	local ok, yes = pcall(just_pressed, pc, k)
	return ok and yes == true
end

-- Whether buttons can be read held, as the combination is (mod_panel_combo.lua); asked of the game once.
function M.usable_down()
	return Calls.ok(Calls.KEY_DOWN)
end

-- Whether the button called name is held now: the combination, the panel closed.
function M.down(pc, name)
	local k = key(name)
	if k == nil or not Calls.ok(Calls.KEY_DOWN) then return false end
	local ok, yes = pcall(held, pc, k)
	return ok and yes == true
end

-- At the panel's opening: the buttons held then are no presses.
function M.start(pc)
	S.down = {}
	Stick.start()
	if not Calls.ok(Calls.KEY_DOWN) then return end
	local stick = Stick.read(pc, key)
	for _, b in ipairs(Names.BUTTONS) do
		local name = b[1]
		local k = key(name)
		local ok, yes = false, false
		if Stick.DIRECTIONS[name] then
			ok, yes = true, stick[name]
		elseif k ~= nil then
			ok, yes = pcall(held, pc, k)
		end
		S.down[name] = ok and yes == true
	end
end

-- At each frame of the open panel: the buttons pressed since the last read, in the table's order. known: a button
-- this frame already read "just pressed" (the panel's, M.pressed), read the value it gave (nil: none read): a button
-- read that way is not asked again. Just after the panel let go of the keys, a button held then and read let go is
-- taken as still held, until it reads held again (D142).
function M.read(pc, known, read)
	local pressed = {}
	if not Calls.ok(Calls.KEY_DOWN) then return pressed end
	local just = Calls.ok(Calls.JUST_PRESSED)
	local stick = Stick.read(pc, key)
	local quiet = Flush.quiet(os.clock())
	if Flush.count() ~= S.flushes then
		S.flushes, S.kept = Flush.count(), {}
		for name, on in pairs(S.down) do S.kept[name] = on or nil end
	end
	for _, b in ipairs(Names.BUTTONS) do
		local name = b[1]
		local short = just and Names.SHORT[name] == true
		local k = key(name)
		local ok, yes = false, false
		if short and name == known and read ~= nil then
			ok, yes = true, read
		elseif Stick.DIRECTIONS[name] then
			ok, yes = true, stick[name]
		elseif k ~= nil then
			ok, yes = pcall(short and just_pressed or held, pc, k)
		end
		local now = ok and yes == true
		if now then
			S.kept[name] = nil
		elseif quiet and S.kept[name] then
			now = true
		end
		if now and (short or not S.down[name]) then pressed[#pressed + 1] = name end
		S.down[name] = now and not short
	end
	return pressed
end

-- The buttons held at the last read, by engine name; read only.
function M.held() return S.down end

return M
