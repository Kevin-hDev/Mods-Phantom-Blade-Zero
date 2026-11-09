-- The help at the foot of the open panel (D76): the keyboard's commands, and the controller's, in icons when the game
-- has every one in memory, else in text (mod_panel_icons.lua); only the help of the last device that gave Mod Panel a
-- command shows. A button makes it the controller; a key, or the mouse moving (D100), clicking, holding an arrow or
-- moving a bar, the keyboard. At each opening, the device of the press that opened it (D80). A command the page
-- lacks (no Restore defaults) is left out; Escape and Circle say Back in a mod's page of the Classic navigation, where
-- they come back to the list (D130). The lines are made again only when the language, the controller's icons, the
-- word of the button under the rows or that of Escape and Circle changes.

local L = require("mod_panel_layout")
local Words = require("mod_panel_words")
local Icons = require("mod_panel_icons")
local Pieces = require("mod_panel_pieces")

local M = {}

-- { label, command's word, whether label is a word's name }: the keys of mod_panel_keys.lua. "restore" stands for the
-- word of the button under the rows: Restore defaults, or Undo.
local KEYS = { { "↑↓", "move" }, { "←→", "change" }, { "Enter", "select" }, { "R", "restore" }, { "Z C", "mod" },
	{ "X", "descriptions" }, { "escape", "close", true } }
-- { the buttons, by their engine names, command's word }: the buttons of mod_panel_pad_commands.lua, in the order of
-- the icons the frame makes for them (mod_panel_frame_hints.lua).
M.PAD = { { { "Gamepad_FaceButton_Bottom" }, "select" }, { { "Gamepad_FaceButton_Top" }, "restore" },
	{ { "Gamepad_LeftShoulder", "Gamepad_RightShoulder" }, "mod" }, { { "Gamepad_FaceButton_Left" }, "descriptions" },
	{ { "Gamepad_FaceButton_Right" }, "close" } }

-- device: "keys" or "pad". lang, brand, restore, back: what the lines were made for; keys, pad: the lines; words: the
-- word of each part of PAD, false for one left out.
local S = { device = "keys", lang = nil, brand = nil, restore = false, back = false, keys = "", pad = "", words = {} }

local function word(name, lang, restore, back)
	if name == "restore" then name = restore end
	if name == "close" and back then name = "back" end
	return name ~= nil and Words.say(name, lang) or nil
end

-- A command's keys and its word, kept on one line by join: their own spaces too.
local function joined(keys, w, join)
	return (keys:gsub(" ", join)) .. join .. w
end

local function make(lang, restore, back)
	-- Plain spaces where the font would draw the no-break ones as nothing: a key may then end a line (D162).
	local parts, join = {}, Pieces.no_break_space(lang) and L.HINT_JOIN or " "
	for _, s in ipairs(KEYS) do
		local w = word(s[2], lang, restore, back)
		if w ~= nil then parts[#parts + 1] = joined(s[3] and Words.say(s[1], lang) or s[1], w, join) end
	end
	S.keys, parts = table.concat(parts, L.HINT_GAP), {}
	for i, s in ipairs(M.PAD) do
		local w = word(s[2], lang, restore, back)
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
-- back: whether Escape and Circle come back to the list.
function M.lines(lang, restore, back)
	local brand = Icons.brand()
	back = back == true
	if lang ~= S.lang or brand ~= S.brand or restore ~= S.restore or back ~= S.back then
		S.lang, S.brand, S.restore, S.back = lang, brand, restore, back
		make(lang, restore, back)
	end
	return S.keys, S.pad, S.words
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
	if k ~= nil or R.mouse_moved or R.pick ~= nil or R.value or R.arrow ~= nil or R.moved ~= nil or R.close or R.restore
		or R.head_arrow ~= nil or R.head_click or R.hide or R.show then
		S.device = "keys"
	end
end

-- "keys" or "pad": whose help shows.
function M.device() return S.device end

return M
