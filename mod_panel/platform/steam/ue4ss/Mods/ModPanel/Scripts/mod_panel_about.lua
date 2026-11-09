-- The descriptions column (taken out of mod_panel_screen.lua with 0.6.3): the chosen row's whole label (the row may
-- cut it), what to set first while it is greyed (D148), why a key or a button was refused, how to stop a wait, its
-- help, then the mod's description and version, or only its folder's name when it has no descriptor. A description
-- with a part borrowed from the neighbour language whose font is not the panel's (an author's Simplified Chinese, the
-- panel in Traditional) is written whole in that language, Mod Panel's own words too, and drawn in its font (D162):
-- neither Chinese font of the game draws both scripts (trials of 0.6.1 and 0.6.2, verified in game).

local Text = require("mod_panel_text")
local KeyNames = require("mod_panel_key_names")
local Values = require("mod_panel_values")
local Words = require("mod_panel_words")
local Settings = require("mod_panel_settings")
local Icons = require("mod_panel_icons")
local PadNames = require("mod_panel_pad_names")
local Pieces = require("mod_panel_pieces")
local Written = require("mod_panel_written")

local M = {}

-- d: { own (Mod Panel's folder name), changes (mod_panel_changes.lua), capture (mod_panel_capture.lua) }.
function M.new(d)
	local A = {}

	-- The text of the value v of row in lang, as its row shows it but a button's icon.
	local function value_text(row, v, lang)
		if row.type == "toggle" then return Words.say(v and "on" or "off", lang) end
		if row.type == "number" then return Values.format_number(v, row) end
		if row.button_row and PadNames.known(v) then return Icons.label(v, lang) end
		local i = Values.option_index(row.options, v)
		return i and Text.pick(row.options[i].label, lang) or row.key_row and KeyNames.label(v, lang)
			or Values.js_string(v)
	end

	-- What shows under row's label about a wait at now: why a key or a button was refused, or that none was pressed.
	local function noted(entry, row, now, lang)
		local n = d.capture.note_of(entry, row, now)
		if n == nil then return nil end
		local key = n.said and (KeyNames.label(n.said, lang) or n.said)
		if n.word == "key_used" then
			return string.format(Words.say("key_used", lang), key, Text.pick(n.used[1].title, lang) or n.used[1].name,
				Text.pick(n.used[2].label, lang) or n.used[2].key)
		end
		if n.word == "key_reserved" then return string.format(Words.say("key_reserved", lang), key) end
		return Words.say(n.word, lang)
	end

	local function build(entry, row, v, now, lang)
		local function say(name) return Words.say(name, lang) end
		local function pick(t) return Text.pick(t, lang) end
		local parts = {}
		local function add(s)
			if s ~= nil and s ~= "" then parts[#parts + 1] = s end
		end
		if row ~= nil then
			add(pick(row.label) or row.key)
			local first, wanted = d.changes.locked(entry, row)
			if first ~= nil then
				add(string.format(say("set_first"), pick(first.label) or first.key, value_text(first, wanted, lang)))
			end
			add(noted(entry, row, now, lang))
			if d.capture.shows(entry, row) then add(say("cancel")) end
			-- After the help, as Mods Menu adds it.
			local help = pick(row.help)
			if row.restart then help = help and Written.join({ help, say("restart") }, " ") or say("restart") end
			add(help)
			if row.key_row and v ~= nil and Values.option_index(row.options, v) == nil then add(say("other_key")) end
			if entry.name == d.own and row.key == Settings.PAD_BUTTON and v ~= PadNames.CREATE and v ~= PadNames.NONE then
				add(say("button_used"))
			end
		end
		if entry.described then
			add(pick(entry.description))
			if entry.version then add(string.format(say("version"), entry.version)) end
		else
			add(string.format(say("folder"), entry.name))
		end
		return Written.join(parts, "\n\n")
	end

	-- The descriptions of entry in lang, with row the chosen row (nil for none), v its value, at now.
	function A.of(entry, row, v, now, lang)
		local s = build(entry, row, v, now, lang)
		local from = Written.from(s)
		if from == nil or Pieces.text_font(from) == Pieces.text_font(lang) then return s end
		s = build(entry, row, v, now, from)
		Written.borrow(s, from)
		return s
	end

	return A
end

return M
