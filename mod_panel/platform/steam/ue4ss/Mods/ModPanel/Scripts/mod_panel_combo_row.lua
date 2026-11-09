-- The row "Controller combination" of Mod Panel's page (D131): made of the two settings PadComboFirst and
-- PadComboSecond, kept one button by key in the file so that Mods Menu shows each as a list of buttons. Here they are
-- chosen together by pressing the two buttons (mod_panel_capture.lua), and Left or Right set both to None
-- (mod_panel_changes.lua). Its key, PadCombo, is in no file: it names the row for a wait.

local Settings = require("mod_panel_settings")
local Words = require("mod_panel_words")
local Values = require("mod_panel_values")
local PadNames = require("mod_panel_pad_names")

local M = {}

M.KEY = "PadCombo"
local made = setmetatable({}, { __mode = "k" })   -- by entry: its row

-- The row made of entry's two settings (Mod Panel's), or nil when its descriptor lacks one of them.
function M.of(entry)
	local row = made[entry]
	if row ~= nil then return row end
	local first, second = nil, nil
	for _, r in ipairs(entry.rows) do
		if r.key == Settings.COMBO_FIRST then first = r elseif r.key == Settings.COMBO_SECOND then second = r end
	end
	if first == nil or second == nil then return nil end
	row = { type = "combo", key = M.KEY, parts = { first, second }, label = Words.text("combo_label"),
		help = Words.text("combo_help") }
	made[entry] = row
	return row
end

-- The two buttons row shows, value(entry, row) giving each setting's value as the panel shows it; nil, nil when they
-- make no combination (Settings.combo). Two values, no table: the page asks it at each frame.
function M.pair(value, entry, row)
	return Settings.combo(value(entry, row.parts[1]), value(entry, row.parts[2]), row.parts[1].options)
end

-- Whether button can be one of the combination: in the first setting's list, and not None.
function M.takes(row, button)
	return button ~= PadNames.NONE and Values.option_index(row.parts[1].options, button) ~= nil
end

return M
