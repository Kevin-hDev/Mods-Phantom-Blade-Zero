-- A UE4SS mod's rows, checked as Mods Menu 0.8.3 checks them: the rows of its <ModName>.modsmenu.json, then a row for
-- each key of its <ModName>.config.json that no row names. A row Mods Menu would leave out is left out, for the same
-- reason. Four choices of our own: a key row stays at its place in the file (D33), "Applies after a restart." is added
-- to the help when shown, in the player's language (row.restart), a choice whose every value is a controller's button
-- or None is a button row, shown as the button's icon (row.button_row), and a mod without an English title it can use
-- shows its folder's name where Mods Menu shows "UE4SS": the player can tell two such mods apart (written at the audit
-- of 0.4.3). Mod Panel's own fields, which Mods Menu ignores: greyedUnless and neverGreyed (mod_panel_greyed.lua),
-- collapsed on a heading (mod_panel_folds.lua).

local Json = require("mod_panel_json")
local Text = require("mod_panel_text")
local Values = require("mod_panel_values")
local KeyNames = require("mod_panel_key_names")
local PadNames = require("mod_panel_pad_names")
local Greyed = require("mod_panel_greyed")
local Folds = require("mod_panel_folds")

local M = {}

M.MAX_ROWS = 100
local MAX_ROWS = M.MAX_ROWS
local TYPES = { toggle = true, choice = true, number = true, action = true, heading = true, key = true }
local NUMBER = Values.NUMBER
local KEY_OPTIONS = KeyNames.options()

local function valid_key(k)
	return type(k) == "string" and #k <= 64 and k:match("^[A-Za-z0-9_]+$") ~= nil
end

local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Mods Menu's way of giving its reasons: {0} and {1} replaced by the parts, nothing for an absent one, then trimmed;
-- each part cited as Text.cited cites it.
local function say(template, ...)
	local parts = table.pack(...)
	return Text.trim((template:gsub("{(%d)}", function(n)
		local v = parts[tonumber(n) + 1]
		if v == nil then return "" end
		return Text.cited(Values.js_string(v))
	end)))
end

local function options_of(raw, key_row, key, why)
	local list = key_row and KEY_OPTIONS or raw.options
	if not (key_row or Json.is_array(list)) or #list == 0 or #list > 64 then return why(say("{0}: options", key)) end
	local options = {}
	for i, o in ipairs(list) do
		local value = o
		if type(o) == "table" and o ~= Json.NULL then value = o.value end
		local kind = type(value)
		local shown = (kind == "string" or kind == "number" or kind == "boolean") and Values.js_string(value) or nil
		if shown == nil or Text.length(shown) > 64 or shown:find("[\r\n]") then
			return why(say("{0}: option value {1}", key, value))
		end
		local label = type(o) == "table" and o.label or nil
		options[i] = { value = value, label = Text.text(label, 40) or Text.text(shown, 40) or { en = shown } }
	end
	return options
end

-- Whether every option is a controller's button or None, one at least a button.
local function buttons_only(options)
	local any = false
	for _, o in ipairs(options) do
		if PadNames.known(o.value) then
			any = true
		elseif o.value ~= PadNames.NONE then
			return false
		end
	end
	return any
end

-- A choice is a bar when it asks for one and every option is a number but at most one word at either end.
local function choice_slider(options)
	local n, words, at_end = #options, 0, false
	for i, o in ipairs(options) do
		if not Text.trim(Values.js_string(o.value)):match(NUMBER) then
			words = words + 1
			at_end = at_end or i == 1 or i == n
		end
	end
	return n >= 2 and (words == 0 or (words == 1 and at_end))
end

-- The checked row, or nil after why(reason).
local function check_setting(raw, why)
	if type(raw) ~= "table" or raw == Json.NULL then return why("not an object") end
	local s = { type = raw.type, label = Text.text(raw.label, 80), help = Text.text(raw.help, 400),
		restart = raw.restart == true }
	if not TYPES[s.type] then return why(say("type {0}", raw.type)) end
	if s.type == "heading" then
		s.collapsed = raw.collapsed == true
		if s.label then return s end
		return why("heading without label")
	end
	s.greyed_raw, s.never_greyed = raw.greyedUnless, raw.neverGreyed == true
	s.key = valid_key(raw.key) and raw.key or nil
	if s.key == nil then return why(say("key {0}", raw.key)) end
	s.label = s.label or Text.text(s.key)
	if s.type == "action" then return s end
	if s.type == "key" then s.type, s.key_row = "choice", true end
	if s.type == "choice" then
		s.options = options_of(raw, s.key_row, s.key, why)
		if s.options == nil then return nil end
		s.button_row = not s.key_row and buttons_only(s.options)
	end
	if s.type == "number" then
		for _, k in ipairs({ "min", "max", "step" }) do
			if raw[k] ~= nil and not finite(raw[k]) then return why(say("{0}: {1}", s.key, k)) end
		end
		s.min, s.max, s.step = raw.min, raw.max, raw.step
		if not (s.step ~= nil and s.step > 0) or (s.min ~= nil and s.max ~= nil and s.min > s.max) then
			return why(say("{0}: step/min/max", s.key))
		end
	end
	s.default = Values.from_raw(s, raw.default, type(raw.default) ~= "string")
	if s.default == nil or (s.type == "choice" and Values.option_index(s.options, s.default) == nil) then
		return why(say("{0}: default {1}", s.key, raw.default))
	end
	if s.type == "number" and ((s.min ~= nil and s.default < s.min) or (s.max ~= nil and s.default > s.max)) then
		return why(say("{0}: default out of range", s.key))
	end
	if raw.missing == nil then
		s.missing = s.default
	else
		s.missing = Values.from_raw(s, raw.missing, type(raw.missing) ~= "string")
	end
	if s.type == "number" then
		s.slider = raw.slider ~= false and s.min ~= nil and s.max ~= nil and s.max > s.min
	elseif s.type == "choice" then
		s.slider = raw.slider == true and choice_slider(s.options)
	end
	return s
end

local function readonly(raw)
	return { type = "readonly", key = valid_key(raw.key) and raw.key or nil,
		label = Text.text(raw.label, 80) or Text.text(raw.key, 64), help = Text.text(raw.help, 400) }
end

-- The keys of the config in the order JavaScript lists them: keys that are array indexes first, by number, then the
-- others in the order of the text.
local function config_keys(config)
	local indexes, others = {}, {}
	for _, key in ipairs(Json.keys(config)) do
		local n = key:match("^0$") or key:match("^[1-9]%d*$")
		if n and #key <= 10 and tonumber(key) < 4294967295 then
			indexes[#indexes + 1] = key
		else
			others[#others + 1] = key
		end
	end
	table.sort(indexes, function(a, b) return tonumber(a) < tonumber(b) end)
	for _, key in ipairs(others) do indexes[#indexes + 1] = key end
	return indexes
end

-- The rows Mods Menu makes for the config's keys that no row of the descriptor names (its known set holds the keys
-- of every row, the refused ones too).
local function config_rows(config, known, list, made)
	for _, key in ipairs(config_keys(config)) do
		local v = config[key]
		if not known[key] and valid_key(key) then
			local row = nil
			if type(v) == "boolean" then
				row = { key = key, type = "toggle", label = key, default = v }
			elseif finite(v) then
				row = { key = key, type = "number", label = key, step = v == math.floor(v) and 1 or 0.1, default = v }
			elseif type(v) == "string" then
				row = { key = key, type = "readonly", label = key }
			end
			if row then
				list[#list + 1] = row
				made[row] = true
			end
		end
	end
end

-- The mod named name (its folder), from its descriptor doc (decoded JSON, or nil without one) and its config (a
-- decoded object): { name, described, title, description, version, rows }, or nil and why; described says whether it
-- has a descriptor. note(reason) is told each row left out. A row made from the config is marked generated: its value
-- is no default, so Restore defaults leaves it.
function M.check(name, doc, config, note)
	local list, known, made = {}, {}, {}
	local described = Json.is_object(doc) and doc or {}
	if Json.is_array(described.settings) then
		for _, r in ipairs(described.settings) do
			list[#list + 1] = r
			if type(r) == "table" and r.key ~= nil then known[r.key] = true end
		end
	end
	config_rows(config, known, list, made)
	local mod = { name = name, described = Json.is_object(doc), title = Text.text(described.title, 80)
		or Text.text(name, 80), description = Text.text(described.description, 300),
		version = Text.str(described.version, 20), rows = {} }
	local skipped = {}
	local function why(reason)
		skipped[#skipped + 1] = reason
		note("setting " .. reason)
		return nil
	end
	local keyed, fold_id = false, Folds.ids()
	for i = 1, math.min(#list, MAX_ROWS) do
		local r = list[i]
		local row
		if type(r) == "table" and r.type == "readonly" then row = readonly(r) else row = check_setting(r, why) end
		if row then
			row.generated = made[r] == true
			if row.type == "heading" then row.fold = fold_id(row.label.en) end
			mod.rows[#mod.rows + 1] = row
			keyed = keyed or row.key ~= nil
		end
	end
	if keyed then
		Greyed.read(mod, doc, note)
		return mod
	end
	if #skipped > 0 then return nil, "no usable setting (" .. table.concat(skipped, "; ") .. ")" end
	return nil, "no usable setting"
end

return M
