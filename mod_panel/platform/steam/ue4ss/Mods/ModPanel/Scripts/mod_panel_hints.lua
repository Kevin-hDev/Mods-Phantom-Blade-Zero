-- The help at the foot of the open panel (D76): the keyboard's commands, and the controller's, in icons when the game
-- has every one in memory, else in text (mod_panel_icons.lua); only the help of the last device that gave Mod Panel a
-- command shows. A button makes it the controller; a key, or the mouse moving (D100), clicking, holding an arrow or
-- moving a bar, the keyboard. At each opening, the device of the press that opened it (D80). A command the page
-- lacks (no Restore defaults) is left out, and so is R3's Favorite while R3 opens the panel (D178); Escape and Circle
-- say Back in a mod's page of the Classic navigation, where they come back to the list (D130). The lines are made
-- again only when the language, the controller's icons, the word of the button under the rows, that of Escape and
-- Circle, or whether R3 makes favourites changes. While the search field types (D186), the keyboard's line says what
-- its keys do there.

local L = require("mod_panel_layout")
local Words = require("mod_panel_words")
local Icons = require("mod_panel_icons")
local Pieces = require("mod_panel_pieces")
local PadCommands = require("mod_panel_pad_commands")

local M = {}

-- { label, command's word, whether label is a word's name }: the keys of mod_panel_keys.lua. "restore" stands for the
-- word of the button under the rows: Restore defaults, or Undo.
local KEYS = { { "↑↓", "move" }, { "←→", "change" }, { "Enter", "select" }, { "R", "restore" }, { "Z C", "mod" },
	{ "F", "favorite" }, { "X", "descriptions" }, { "escape", "close", true } }
local TYPING = { { "↑↓", "mod" }, { "Enter", "done" }, { "escape", "erase", true } }
local FAVORITE = "Gamepad_RightThumbstick"
-- { the buttons, by their engine names, command's word }: the buttons of mod_panel_pad_commands.lua, in the order of
-- the icons the frame makes for them (mod_panel_frame_hints.lua).
M.PAD = { { { "Gamepad_FaceButton_Bottom" }, "select" }, { { "Gamepad_FaceButton_Top" }, "restore" },
	{ { "Gamepad_LeftShoulder", "Gamepad_RightShoulder" }, "mod" }, { { FAVORITE }, "favorite" },
	{ { "Gamepad_FaceButton_Left" }, "descriptions" }, { { "Gamepad_FaceButton_Right" }, "close" } }

-- device: "keys" or "pad". lang, brand, restore, back, fav: what the lines were made for; keys, typing, pad: the
-- lines; words: the word of each part of PAD, false for one left out.
local S = { device = "keys", lang = nil, brand = nil, restore = false, back = false, fav = true, keys = "",
	typing = "", pad = "", words = {} }

local function word(name, lang, restore, back)
	if name == "restore" then name = restore end
	if name == "close" and back then name = "back" end
	return name ~= nil and Words.say(name, lang) or nil
end

-- A command's keys and its word, kept on one line by join: their own spaces too.
local function joined(keys, w, join)
	return (keys:gsub(" ", join)) .. join .. w
end

-- The keyboard's line of the commands list, each part by join.
local function keys_line(list, lang, restore, back, join)
	local parts = {}
	for _, s in ipairs(list) do
		local w = word(s[2], lang, restore, back)
		if w ~= nil then parts[#parts + 1] = joined(s[3] and Words.say(s[1], lang) or s[1], w, join) end
	end
	return table.concat(parts, L.HINT_GAP)
end

-- fav: whether R3 makes favourites now (mod_panel_pad_commands.lua); when not, its part is left out.
local function make(lang, restore, back, fav)
	-- Plain spaces where the font would draw the no-break ones as nothing: a key may then end a line (D162).
	local parts, join = {}, Pieces.no_break_space(lang) and L.HINT_JOIN or " "
	S.keys, S.typing = keys_line(KEYS, lang, restore, back, join), keys_line(TYPING, lang, nil, false, join)
	for i, s in ipairs(M.PAD) do
		local w = (fav or s[2] ~= "favorite") and word(s[2], lang, restore, back) or nil
		-- After its icons, with the gap to the next part, as the text line has.
		S.words[i] = w ~= nil and " " .. w .. (i < #M.PAD and L.HINT_GAP or "") or false
		if w ~= nil then
			local names = {}
			for j, b in ipairs(s[1]) do names[j] = Icons.label(b, lang) end
			parts[#parts + 1] = joined(table.concat(names, " "), w, join)
		end
	end
	S.pad = table.concat(parts, L.HINT_GAP)
end

-- The keyboard's line, the controller's in text, and the word of each part of PAD (false: left out), in lang ("en",
-- "zh-Hans"...); restore: the word of the button under the rows ("restore" or "undo"), nil when the page has none;
-- back: whether Escape and Circle come back to the list; typing: whether the search field types.
function M.lines(lang, restore, back, typing)
	local brand, fav = Icons.brand(), PadCommands.acts(FAVORITE)
	back = back == true
	if lang ~= S.lang or brand ~= S.brand or restore ~= S.restore or back ~= S.back or fav ~= S.fav then
		S.lang, S.brand, S.restore, S.back, S.fav = lang, brand, restore, back, fav
		make(lang, restore, back, fav)
	end
	return typing and S.typing or S.keys, S.pad, S.words
end

-- At each opening: device, the one whose press opened the panel.
function M.start(device)
	S.device = device
end

-- A press of a button in the open panel.
function M.pad() S.device = "pad" end

-- At each frame of the open panel: k, the keys' presses (or nil); R, what the pointer did (mod_panel_pointer.lua). A
-- still pointer is no gesture, even when a row scrolls under it.
function M.frame(k, R)
	if k ~= nil or R.mouse_moved or R.pick ~= nil or R.fav ~= nil or R.switch ~= nil or R.value or R.arrow ~= nil
		or R.moved ~= nil or R.close or R.restore or R.head_arrow ~= nil or R.head_click or R.hide or R.show then
		S.device = "keys"
	end
end

-- "keys" or "pad": whose help shows.
function M.device() return S.device end

return M
