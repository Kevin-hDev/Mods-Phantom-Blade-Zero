-- Mod Panel's own settings, in ModPanel.config.json, the file Mods Menu shows too. Their defaults are in
-- ModPanel.modsmenu.json, the only place that gives them (read by the catalog); this module turns the file's values
-- into the settings in use, a value that cannot serve giving its default.

local Files = require("mod_panel_files")
local Json = require("mod_panel_json")
local JsonEdit = require("mod_panel_json_edit")
local Values = require("mod_panel_values")
local KeyNames = require("mod_panel_key_names")
local PadNames = require("mod_panel_pad_names")

local M = {}

M.CONFIG_VERSION = 1
local MAX_FILE_BYTES = 256 * 1024
-- The panel key's row, a key row since the controller's button can open the panel too (D71); the controller's button,
-- a button row (D72); whose icons (D73); the freeze and the background, at the head of the list (mod_panel_head.lua).
M.PANEL_KEY, M.PAD_BUTTON, M.ICONS = "PanelKey", "PadButton", "ButtonIcons"
M.FREEZE, M.OPACITY = "FreezeGame", "PanelOpacity"
-- The way to move in the panel (D123, D129), and the controller's combination, one button by key so that Mods Menu
-- shows each as a list (D131).
M.NAVIGATION, M.HYBRID = "Navigation", "Hybrid"
M.COMBO_FIRST, M.COMBO_SECOND = "PadComboFirst", "PadComboSecond"
-- The panel's language: Game, the game's own, or one of the 15 (D153).
M.LANGUAGE, M.GAME = "Language", "Game"
-- The backdrop's colour, one of a list of dark ones (D177, mod_panel_layout.lua).
M.COLOR = "PanelColor"
-- Rows of Mod Panel that its own page leaves out: Enabled only in Mods Menu, which can turn it back on (D22); the
-- freeze and the background, at the head of the list (D28).
M.HIDDEN = { Enabled = true, [M.FREEZE] = true, [M.OPACITY] = true }

-- The combination of the buttons a and b, both in options (a combination row's list), neither None and not the same:
-- a, b; else nil, nil. The only judge of what a combination is: the settings in use and the row that shows them ask
-- it (audit of 0.5.1: a button off the list showed on the row while nothing could open the panel).
function M.combo(a, b, options)
	if a == nil or b == nil or a == b or a == PadNames.NONE or b == PadNames.NONE then return nil, nil end
	if Values.option_index(options, a) == nil or Values.option_index(options, b) == nil then return nil, nil end
	return a, b
end

local function file_name(path)
	return path:match("([^/\\]+)$")
end

-- The file's text with the version and the defaults of rows, Mod Panel's checked rows.
local function default_text(rows)
	local entries = { { "config-version", M.CONFIG_VERSION } }
	for _, row in ipairs(rows) do
		if row.key ~= nil and row.default ~= nil then
			entries[#entries + 1] = { row.key, Values.to_file(row, row.default) }
		end
	end
	return JsonEdit.flat_object(entries)
end

-- At start: a missing file is made with the defaults, so Mods Menu shows Mod Panel's settings too. A file that is no
-- JSON object is set aside as <file>.invalid, never lost, and made again. A file another program holds is left.
function M.ensure(path, rows, note)
	local text, why = Files.read(path, MAX_FILE_BYTES)
	if why == "busy" then return end
	if text ~= nil and Json.is_object((Json.decode(text))) then return end
	local name = file_name(path)
	if why ~= "missing" then
		if not Files.set_aside(path, ".invalid") then
			note(string.format("%s is not one JSON object, and %s.invalid cannot be replaced: the defaults are used",
				name, name))
			return
		end
		note(string.format("%s was not one JSON object: kept as %s.invalid", name, name))
	end
	if Files.put(path, default_text(rows)) then
		note(string.format("made %s with the defaults", name))
	else
		note(string.format("could not make %s: Mods Menu cannot show these settings until it exists", name))
	end
end

-- The settings in use, from Mod Panel's entry in the catalog (nil when it is not shown), each value checked against
-- its row: { enabled, panel_key, pad_button, icons, opacity, color, freeze, navigation, classic, combo, language }.
-- The panel key can be any key Mod Panel can name, as a wait writes it (D69, mod_panel_capture.lua). combo: { first,
-- second }, two buttons of their lists, neither None and not the same, else nil: no combination.
function M.from(entry, rows)
	local by_key = {}
	for _, row in ipairs(rows) do
		if row.key ~= nil then by_key[row.key] = row end
	end
	local function value(key, fits)
		local row, v = by_key[key], entry and entry.values[key]
		if row == nil then return nil end
		if v ~= nil and fits(v, row) then return v end
		return row.default
	end
	local function boolean(v) return type(v) == "boolean" end
	local opacity = value(M.OPACITY, function(v) return type(v) == "number" end)
	local row = by_key[M.OPACITY]
	if opacity ~= nil and row.min ~= nil and row.max ~= nil then
		opacity = math.min(row.max, math.max(row.min, opacity))
	end
	local function listed(v, r) return Values.option_index(r.options, v) ~= nil end
	local function key(v) return v == KeyNames.NONE or KeyNames.UE4SS[v] ~= nil end
	local combo_row, combo = by_key[M.COMBO_FIRST], nil
	if combo_row ~= nil then
		local a, b = M.combo(value(M.COMBO_FIRST, listed), value(M.COMBO_SECOND, listed), combo_row.options)
		combo = a and { a, b } or nil
	end
	local navigation = value(M.NAVIGATION, listed)
	return {
		enabled = value("Enabled", boolean),
		panel_key = value(M.PANEL_KEY, key),
		pad_button = value(M.PAD_BUTTON, listed),
		icons = value(M.ICONS, listed),
		opacity = opacity,
		freeze = value(M.FREEZE, boolean) == true,
		navigation = navigation,
		classic = navigation ~= M.HYBRID,
		combo = combo,
		language = value(M.LANGUAGE, listed),
		color = value(M.COLOR, listed),
	}
end

-- For the log.
function M.describe(s)
	return string.format("%s, panel key %s, background %s %% %s, button %s, combination %s, icons %s, freeze %s, "
		.. "navigation %s, language %s", s.enabled and "on" or "off", tostring(s.panel_key),
		s.opacity and Json.number_text(s.opacity) or "?", tostring(s.color), tostring(s.pad_button),
		s.combo and s.combo[1] .. " + " .. s.combo[2] or "none", tostring(s.icons), s.freeze and "on" or "off",
		tostring(s.navigation), tostring(s.language))
end

return M
