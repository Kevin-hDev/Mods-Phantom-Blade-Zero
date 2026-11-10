-- Mod Panel's own words in English, the only place that gives them; the other languages' are in their own files, by
-- the same names (mod_panel_langs.lua, D152), English standing in for a word a language lacks. Where Mods Menu 0.8.3
-- has words for the same thing, they are the same here, so a row reads the same in both menus.
-- Taken from OWN in Dynamic FOV 1.0.4's dynamic_fov_panel_texts.lua.

local Text = require("mod_panel_text")
local Langs = require("mod_panel_langs")

local M = {}

local WORDS = {
	-- The descriptor's title too (ModPanel.modsmenu.json), which a test keeps equal.
	title = "Mod Panel",
	mod_count = "%d mods",
	mod_count_one = "%d mod",
	on = "On",
	off = "Off",
	-- A mod turned off, in the list: Mods Menu's word for a mod in that state, not the switch's.
	mod_off = "Off",
	run = "Run",
	press_again = "Press again",
	sent = "Sent",
	restore = "Restore defaults",
	undo = "Undo",
	-- Mods Menu's "Failed: settings not saved" without its "Failed:".
	not_saved = "Settings not saved",
	close = "Close",
	escape = "Esc",
	-- Circle and Escape from a mod's page in Classic (D130).
	back = "Back",
	-- The controller's combination, one row of Mod Panel's page (D131, D132): the descriptor's None for its two lists.
	none = "None",
	combo_label = "Controller combination",
	combo_help = "Two controller buttons pressed together while you play open and close the panel, as the controller "
		.. "button does. Cross, then press the two buttons, together or one after the other. Left or Right: None. The "
		.. "game also uses these buttons.",
	press_two = "Press two buttons",
	no_second = "Only one button pressed.",
	-- The help at the foot of the panel (mod_panel_hints.lua); the buttons' names are in mod_panel_pad_names.lua.
	move = "Move",
	change = "Change",
	select = "Select",
	mod = "Mod",
	favorite = "Favorite",
	restart = "Applies after a restart.",
	other_key = "The game may also use this key.",
	-- Mod Panel's button other than Create (D72): every other button already does something in play.
	button_used = "The game also uses this button.",
	-- A wait for a key or a button (mod_panel_capture.lua): Mods Menu's words for the same where it has them.
	press_key = "Press a key",
	press_button = "Press a button",
	cancel = "Escape cancels.",
	key_moves = "This key moves in the panel.",
	key_list = "This mod only takes the keys of the list.",
	key_reserved = "%s opens Mods Menu.",
	-- The key, then the mod and the row that use it.
	key_used = "%s is used by %s: %s.",
	button_list = "Not in this row's list.",
	no_key = "No key pressed.",
	no_button = "No button pressed.",
	-- A greyed row (D148): the label of the row to set first, then the value it asks, as Dynamic FOV's panel says it.
	set_first = "Set %s to %s to change this row.",
	version = "Version %s",
	folder = "Folder: %s",
	-- The head of the list (mod_panel_head.lua): the filter's boxes, "Mod" before the state so that they are not read
	-- as turning Mod Panel on or off (D101), and what each lists; the phrase of an empty list.
	filter_on = "Mod enabled",
	filter_off = "Mod disabled",
	filter_on_help = "Checked: the list shows the mods that are on. A mod without an Enabled setting counts as on.",
	filter_off_help = "Checked: the list shows the mods that are turned off.",
	empty = "Check Mod enabled or Mod disabled to list mods.",
	-- All mods, first in the head (mod_panel_all_mods.lua, D156 to D158, D163): its help says the limit of D157.
	all_mods = "All mods",
	all_mods_help = "Off: turns off every mod that has an Enabled setting, Mod Panel excepted. On: turns back on "
		.. "only the mods it turned off. A mod without an Enabled setting cannot be turned off here and keeps running.",
	-- The descriptions' column (D90, D91): its buttons, and its command in the help; a section's title too, folded
	-- (Show) or open (Hide), D150.
	hide = "Hide",
	show = "Show",
	descriptions = "Descriptions",
}

-- The names of the words, for the tests that check every language has each.
function M.names()
	local list = {}
	for name in pairs(WORDS) do list[#list + 1] = name end
	table.sort(list)
	return list
end

-- The word name in lang (one of mod_panel_text.lua's LANGS); English where that language has none.
function M.say(name, lang)
	return Langs.get("words", name, lang) or WORDS[name]
end

-- The word name in all its languages, as a row's label or help is held (mod_panel_combo_row.lua).
local texts = {}
function M.text(name)
	local t = texts[name]
	if t == nil then
		t = {}
		for _, lang in ipairs(Text.LANGS) do t[lang] = M.say(name, lang) end
		texts[name] = t
	end
	return t
end

return M
