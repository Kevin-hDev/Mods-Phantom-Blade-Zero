-- The panel's key (1.0.2): the names Mods Menu offers, the UE4SS binds that read them, and the presses counted for the
-- game thread. UE4SS reads its binds on its own thread (UE4SSProgram::update) and runs their Lua under its lock, as it
-- runs the player controller's tick hook that drives the mod (dynamic_fov_driver.lua): the two never run at the same
-- time (UE4SS 1ceefac, LuaMod.cpp). A bind only counts presses; the next frame handles them. UE4SS cannot drop a bind:
-- one made for a key that is no longer the panel's does nothing. UE4SS binds see the keyboard only (GetAsyncKeyState).
-- UE4SS calls a bind only while exactly its modifier keys are held (Handler.cpp): a bind without any does nothing while
-- Shift is held, the sprint's key. Each key is also bound with each modifier alone (audit of 5 November 2026).

local M = {}

M.NONE, M.DEFAULT = "None", "F8"
-- The key that opens Mods Menu unless changed there (OpenKey in its main.js, 0.5.3): one press would open both. Mods
-- Menu's own setting is not read: a player who moves it is told by the help that F9 is its default only.
M.MODS_MENU = "F9"
local MODIFIERS = { "SHIFT", "CONTROL", "ALT" }
-- Mods Menu's key names (KEYS in its main.js, 0.5.3: the keys the game leaves free in play and in its menus), and
-- UE4SS's name for the same key (its Key table, LuaMod.cpp).
M.NAMES = {
	F1 = "F1", F2 = "F2", F3 = "F3", F4 = "F4", F5 = "F5", F6 = "F6", F7 = "F7", F8 = "F8", F9 = "F9", F12 = "F12",
	PageUp = "PAGE_UP", PageDown = "PAGE_DOWN", Home = "HOME", End = "END", Insert = "INS", Delete = "DEL",
	NumPadZero = "NUM_ZERO", NumPadOne = "NUM_ONE", NumPadTwo = "NUM_TWO", NumPadFour = "NUM_FOUR",
	NumPadFive = "NUM_FIVE", NumPadSix = "NUM_SIX", NumPadSeven = "NUM_SEVEN", NumPadEight = "NUM_EIGHT",
	NumPadNine = "NUM_NINE", Multiply = "MULTIPLY", Add = "ADD", Subtract = "SUBTRACT", Decimal = "DECIMAL",
	Divide = "DIVIDE", G = "G", H = "H", J = "J", L = "L", N = "N", U = "U", Y = "Y", Zero = "ZERO", Nine = "NINE",
}
-- How Mods Menu shows a key where its name is not the one shown (KEY_LABELS in its main.js, 0.5.3).
local LABELS = { PageUp = "Page Up", PageDown = "Page Down", Multiply = "NumPad *", Add = "NumPad +",
	Subtract = "NumPad -", Decimal = "NumPad .", Divide = "NumPad /", Zero = "0", Nine = "9" }
local DIGITS = { Zero = 0, One = 1, Two = 2, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8, Nine = 9 }
local MAX_PENDING = 8             -- presses kept between two frames

local SPELLING = { [M.NONE:lower()] = M.NONE }
for name in pairs(M.NAMES) do SPELLING[name:lower()] = name end

-- bound[name]: whether the key's bind was made; tried once per key, so at most four binds (with the modifiers) per
-- name above.
local P = { current = nil, toggle = 0, escape = 0, bound = {}, escape_tried = false }

-- The menu's spelling of a key name given in any case, None included; nil for a key the menu does not offer.
function M.canonical(text)
	return type(text) == "string" and SPELLING[text:lower()] or nil
end

-- Returns whether the key works, then why not, or what it misses (a modifier this UE4SS refused).
local function bind(name, fn)
	local keys = rawget(_G, "Key")
	local code = keys and keys[name]
	if code == nil then return false, "no such key in this UE4SS" end
	local ok, err = pcall(RegisterKeyBind, code, fn)
	if not ok then return false, err end
	local mods, missed, why = rawget(_G, "ModifierKey"), {}, nil
	for _, m in ipairs(MODIFIERS) do
		local okm, errm = false, "no such modifier in this UE4SS"
		if mods and mods[m] then okm, errm = pcall(RegisterKeyBind, code, { mods[m] }, fn) end
		if not okm then
			missed[#missed + 1] = m
			why = why or tostring(errm)
		end
	end
	if #missed == 0 then return true, nil end
	local names = #missed == 1 and missed[1]
		or table.concat(missed, ", ", 1, #missed - 1) .. " or " .. missed[#missed]
	return true, string.format("not while %s is held (%s)", names, why)
end

-- The panel key is now name (the menu's spelling, or None). Its bind is made the first time; Escape's too. Presses of
-- the key before are dropped.
function M.want(name, log)
	P.current, P.toggle = M.NAMES[name] and name or nil, 0
	if not P.escape_tried then
		P.escape_tried = true
		local ok, err = bind("ESCAPE", function()
			if P.escape < MAX_PENDING then P.escape = P.escape + 1 end
		end)
		if not ok then
			log("Escape cannot close the panel (%s)", tostring(err))
		elseif err ~= nil then
			log("Escape closes the panel, %s", err)
		end
	end
	if P.current == nil or P.bound[name] ~= nil then return end
	local ok, err = bind(M.NAMES[name], function()
		if P.current == name and P.toggle < MAX_PENDING then P.toggle = P.toggle + 1 end
	end)
	P.bound[name] = ok
	if not ok then
		log("the panel key %s cannot be used (%s)", name, tostring(err))
	elseif err ~= nil then
		log("the panel key %s works, %s", name, err)
	end
end

-- The presses since the last call: the panel key's, then Escape's.
function M.take()
	local toggle, escape = P.toggle, P.escape
	if toggle > 0 or escape > 0 then P.toggle, P.escape = 0, 0 end
	return toggle, escape
end

-- The panel key's name as the menu writes it, or nil for None.
function M.current()
	return P.current
end

-- A key as Mods Menu shows it ("Page Up", "NumPad 0"), or nil for None.
function M.label(name)
	if name == nil or M.NAMES[name] == nil then return nil end
	local digit = name:match("^NumPad(%a+)$")
	if digit ~= nil and DIGITS[digit] ~= nil then return "NumPad " .. DIGITS[digit] end
	return LABELS[name] or name
end

return M
