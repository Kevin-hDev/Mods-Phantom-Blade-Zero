-- The keyboard's keys Mod Panel can name. First those a key row offers, as Mods Menu 0.8.3 lists them: the keys the
-- game leaves free in play and in its menus, in the order of a key row's options. Then the others its own panel key can
-- be (D69): the letters, the top row's other digits, the number pad's 3, Space Bar, Tab, Backspace and Caps Lock.
-- Neither F10 nor F11 (the console, full screen), nor F13 to F24, which the engine lacks (Unreal 5.7, InputCoreTypes.h,
-- D82), nor punctuation, whose engine name follows the keyboard's layout. Each key by the engine's name
-- (InputCoreTypes.cpp), the spelling Mods Menu writes, and by UE4SS's (its Types.lua, source unique). Taken from the
-- tables of Dynamic FOV 1.0.4's dynamic_fov_hotkey.lua.

local Langs = require("mod_panel_langs")
local Text = require("mod_panel_text")

local M = {}

M.NONE = "None"
-- Keys no key row takes, on top of those other key rows use (D64). F9 opens Mods Menu unless changed in it, a setting
-- Mod Panel does not read: one press would open both, and Dynamic FOV refuses it for its own panel key.
M.RESERVED = { F9 = true }
-- The keys that move in the open panel, by UE4SS's name, and the count each one adds to (mod_panel_keys.lua). None of
-- them is a key to choose: one press would do two things. X hides or shows the descriptions (D91), F makes the chosen
-- mod a favourite or undoes it (D178): from 1.0.2 on, neither a key row nor the panel key can take F in the panel, and
-- a panel key F written before gives its default.
M.MOVES = { UP_ARROW = "up", DOWN_ARROW = "down", LEFT_ARROW = "left", RIGHT_ARROW = "right", RETURN = "enter",
	Z = "prev", C = "next", R = "restore", X = "descriptions", F = "favorite" }
M.LIST = { "None", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F12", "PageUp", "PageDown", "Home", "End",
	"Insert", "Delete", "NumPadZero", "NumPadOne", "NumPadTwo", "NumPadFour", "NumPadFive", "NumPadSix", "NumPadSeven",
	"NumPadEight", "NumPadNine", "Multiply", "Add", "Subtract", "Decimal", "Divide", "G", "H", "J", "L", "N", "U", "Y",
	"Zero", "Nine" }
local DIGITS = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
local MORE = { "NumPadThree", "SpaceBar", "Tab", "BackSpace", "CapsLock" }
-- UE4SS's names that are not the engine's in capitals (Types.lua).
local SPECIAL = { PageUp = "PAGE_UP", PageDown = "PAGE_DOWN", Insert = "INS", Delete = "DEL", SpaceBar = "SPACE",
	BackSpace = "BACKSPACE", CapsLock = "CAPS_LOCK" }
-- How Mods Menu shows a key whose name is not the one shown; the engine, the others (InputCoreTypes.cpp, from line
-- 549).
local LABELS = { PageUp = "Page Up", PageDown = "Page Down", Multiply = "NumPad *", Add = "NumPad +",
	Subtract = "NumPad -", Decimal = "NumPad .", Divide = "NumPad /", SpaceBar = "Space Bar", BackSpace = "Backspace",
	CapsLock = "Caps Lock" }

local function ue4ss_name(name)
	local digit = name:match("^NumPad(%a+)$")
	if digit ~= nil then return "NUM_" .. digit:upper() end
	return SPECIAL[name] or name:upper()
end

-- UE4SS's name of each key Mod Panel can name, by the engine's (None has none); KEYS: those keys, Mods Menu's first,
-- the keys a wait reads (mod_panel_keys.lua).
M.UE4SS, M.KEYS = {}, {}
local NUMBER = {}
local function add(name)
	local ue4ss = ue4ss_name(name)
	if name == M.NONE or M.UE4SS[name] ~= nil or M.MOVES[ue4ss] then return end
	M.UE4SS[name] = ue4ss
	M.KEYS[#M.KEYS + 1] = name
end
for _, name in ipairs(M.LIST) do add(name) end
for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do add(c) end
for i, d in ipairs(DIGITS) do
	NUMBER[d] = i - 1
	add(d)
end
for _, name in ipairs(MORE) do add(name) end

-- A key as the player reads it ("Page Up", "NumPad 0", "Space Bar", "None"), or nil for a key Mod Panel cannot name.
-- In another language (lang, one of mod_panel_text.lua's LANGS), the number pad's prefix and None as its file writes
-- them (mod_panel_langs.lua, ids NumPad and None); the other names stay as they are, there too.
function M.label(name, lang)
	if name == nil or (name ~= M.NONE and M.UE4SS[name] == nil) then return nil end
	if name == M.NONE then return Langs.get("keys", "None", lang) or "None" end
	local digit = name:match("^NumPad(%a+)$")
	local label = tostring(digit ~= nil and "NumPad " .. NUMBER[digit] or LABELS[name] or NUMBER[name] or name)
	local pad = label:sub(1, 7) == "NumPad " and Langs.get("keys", "NumPad", lang)
	return pad and pad .. label:sub(7) or label
end

-- A key row's options, as Mods Menu builds them from its key list, with their names in each language that has its own.
function M.options()
	local list = {}
	for i, name in ipairs(M.LIST) do
		local label = { en = M.label(name) }
		for _, lang in ipairs(Text.LANGS) do
			local own = M.label(name, lang)
			if own ~= label.en then label[lang] = own end
		end
		list[i] = { value = name, label = label }
	end
	return list
end

return M
