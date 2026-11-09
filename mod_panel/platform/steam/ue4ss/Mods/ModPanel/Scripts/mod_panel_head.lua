-- The head of the list (D27, D92 to D95): All mods (mod_panel_all_mods.lua, D156), Freeze game and Background, two of
-- Mod Panel's own settings, then the filter's two boxes, Enabled and Disabled (mod_panel_listing.lua). The selection
-- reaches them above the chosen mod's first row (mod_panel_nav.lua). Left, Right, Enter, Cross or a click: the freeze
-- switches and the background steps as their rows do, written by mod_panel_changes.lua half a second after the last
-- change; a box turns over, All mods too. Held, an arrow of the background steps faster and faster as on a row; of a
-- box or of All mods, it turns it once. What shows acts at once (D93): the backdrop and the freeze follow the value
-- waiting to be written. Freeze game shows only while the game's pause is the one Mod Panel knows (D95).

local Calls = require("mod_panel_calls")
local Settings = require("mod_panel_settings")
local Values = require("mod_panel_values")
local Words = require("mod_panel_words")
local Text = require("mod_panel_text")
local FrameHead = require("mod_panel_frame_head")

local M = {}

local KEYS = { freeze = Settings.FREEZE, background = Settings.OPACITY }
-- A box's name in the list and what it lists.
local BOX_WORDS = { enabled = { "filter_on", "filter_on_help" }, disabled = { "filter_off", "filter_off_help" } }

-- d: { catalog, changes (mod_panel_changes.lua), state (mod_panel_state.lua), own (Mod Panel's folder name), all
-- (mod_panel_all_mods.lua) }.
function M.new(d)
	-- items: the names shown, in the frame's order; held: { i, dir } of the box whose arrow is held.
	local H = { items = {}, held = nil }
	-- Mod Panel's rows from its descriptor alone, for the names, the helps and the defaults while its file is not read.
	local described = {}
	for _, row in ipairs(d.catalog.rows(d.own) or {}) do
		if row.key ~= nil then described[row.key] = row end
	end

	-- Mod Panel's entry and its row of setting item name, or nil while Mod Panel is not read.
	local function setting(name)
		local entry = d.catalog.get(d.own)
		if entry == nil then return nil end
		for _, row in ipairs(entry.rows) do
			if row.key == KEYS[name] then return entry, row end
		end
		return nil
	end

	-- At each opening: the items that show.
	function H.start()
		H.items, H.held = {}, nil
		for _, name in ipairs(FrameHead.ITEMS) do
			if name ~= "freeze" or Calls.ok(Calls.PAUSE) then H.items[#H.items + 1] = name end
		end
	end

	function H.count() return #H.items end
	function H.name(i) return H.items[i] end

	-- The place among the items shown of the item called name, or nil.
	function H.place(name)
		for i, n in ipairs(H.items) do
			if n == name then return i end
		end
		return nil
	end

	-- A setting item's value: the change waiting, else the file's, else the default.
	local function value(name)
		local entry, row = setting(name)
		local v = entry and d.changes.value(entry, row)
		if v == nil then
			local r = row or described[KEYS[name]]
			v = r and r.default
		end
		return v
	end

	-- Whether the game shall be frozen: Freeze game shows and is on.
	function H.freeze() return H.place("freeze") ~= nil and value("freeze") == true end

	-- The backdrop's % dark; fallback when there is none.
	function H.opacity(fallback)
		local v = value("background")
		return type(v) == "number" and v or fallback
	end

	-- A box or All mods turned over; whether the filter changed.
	local function turn(name, now)
		if name == "all" then
			d.all.turn(now)
			return false
		end
		d.state.set(name, not d.state.get(name))
		return true
	end

	local function turns(name) return FrameHead.BOXES[name] or name == "all" end

	-- n steps of dir (-1 or 1) on item i, at now. Returns whether the filter changed.
	function H.step(i, dir, n, now)
		local name = H.items[i]
		if turns(name) then return n % 2 == 1 and turn(name, now) end
		local entry, row = setting(name)
		if entry ~= nil then d.changes.step(entry, row, dir, n, now) end
		return false
	end

	-- n presses of Enter or Cross, or clicks, on item i: a switch or a box turns over, the background takes none.
	function H.enter(i, n, now)
		if H.items[i] == "background" then return false end
		return H.step(i, 1, n, now)
	end

	-- A frame where an arrow of item i is held, dir -1 or 1. Returns whether the filter changed.
	function H.hold(i, dir, now)
		local name = H.items[i]
		if not turns(name) then
			H.held = nil
			local entry, row = setting(name)
			d.changes.hold(entry, row, "head " .. i, entry and dir, now)
			return false
		end
		d.changes.hold(nil, nil, nil, nil, now)
		if H.held ~= nil and H.held.i == i and H.held.dir == dir then return false end
		H.held = { i = i, dir = dir }
		return turn(name, now)
	end

	function H.release() H.held = nil end

	-- What item name shows in lang, into k (a table used again): shown, label, box, checked, value (nil for a box).
	function H.look(k, name, lang)
		k.shown, k.box = H.place(name) ~= nil, FrameHead.BOXES[name] == true
		if name == "all" then
			k.label, k.checked = Words.say("all_mods", lang), false
			k.value = Words.say(d.all.off() and "off" or "on", lang)
			return k
		end
		if k.box then
			k.label, k.checked, k.value = Words.say(BOX_WORDS[name][1], lang), d.state.get(name) == true, nil
			return k
		end
		local row, v = described[KEYS[name]], value(name)
		k.label, k.checked = row and Text.pick(row.label, lang) or KEYS[name], false
		if name == "freeze" then
			k.value = Words.say(v == true and "on" or "off", lang)
		else
			k.value = (row and type(v) == "number") and Values.format_number(v, row) .. " %" or ""
		end
		return k
	end

	-- The descriptions of item i in lang: its name, then what it does.
	function H.describe(i, lang)
		local name = H.items[i]
		if name == "all" then return Words.say("all_mods", lang) .. "\n\n" .. Words.say("all_mods_help", lang) end
		if FrameHead.BOXES[name] then
			local w = BOX_WORDS[name]
			return Words.say(w[1], lang) .. "\n\n" .. Words.say(w[2], lang)
		end
		local row = described[KEYS[name]]
		if row == nil then return KEYS[name] end
		local help = Text.pick(row.help, lang)
		return (Text.pick(row.label, lang) or row.key) .. (help and "\n\n" .. help or "")
	end

	return H
end

return M
