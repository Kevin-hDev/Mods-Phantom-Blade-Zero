-- The panel's rows (1.0.2): which settings, in which order, with which bounds, what each row shows, and whether it can
-- change now. The order and the texts are DynamicFOV.modsmenu.json's (dynamic_fov_panel_texts.lua); the values,
-- bounds, steps and presets dynamic_fov_settings.lua's, and every change goes through its resolve(): each has one
-- place. The panel key is set in Mods Menu only, picked from its list of keys.

local Settings = require("dynamic_fov_settings")

local M = {}

local PRESET_VALUES = {}
for i, p in ipairs(Settings.PRESETS) do PRESET_VALUES[i] = p.value end

-- What the panel shows for each key of the settings file. A switch shows On or Off between two arrows; a choice, the
-- option's name in the menu between two arrows, the arrows going round values.
local KINDS = {
	[Settings.ENABLED] = { kind = "switch", field = "enabled" },
	[Settings.PRESET] = { kind = "choice", field = "preset", values = PRESET_VALUES },
	[Settings.COLOURS_KEY] = { kind = "choice", field = "colours", values = Settings.COLOURS },
	[Settings.CLEAN_KEY] = { kind = "switch", field = "clean_image" },
	-- First in the panel, though under the panel's heading in Mods Menu, whose first row is Enabled (chosen on 5 November
	-- 2026); never greyed, as it changes the panel, not the game.
	[Settings.OPACITY_KEY] = { kind = "number", field = "panel_opacity", min = Settings.OPACITY_MIN,
		max = Settings.OPACITY_MAX, step = Settings.OPACITY_STEP, first = true },
	[Settings.TRANSITION] = { kind = "number", field = "transition", min = Settings.TIME_MIN, max = Settings.TIME_MAX,
		step = Settings.TIME_STEP },
}
for _, k in ipairs(Settings.FOV_KEYS) do
	KINDS[k.name] = { kind = "number", field = k.field, min = Settings.FOV_MIN, max = Settings.FOV_MAX,
		step = Settings.FOV_STEP, fov = true }
end
for _, k in ipairs(Settings.POSITION_KEYS) do
	KINDS[k.name] = { kind = "number", field = k.field, min = k.min, max = k.max, step = k.step }
end

-- The preset whose four fields of view are the player's own.
local CUSTOM
for _, p in ipairs(Settings.PRESETS) do
	if p.offset == nil then CUSTOM = p.value end
end

local function row_of(e)
	local k = KINDS[e.key]
	local row = { key = e.key, kind = k.kind, field = k.field, min = k.min, max = k.max, step = k.step, fov = k.fov,
		label = e.label, help = e.help }
	if k.kind == "choice" then
		row.options = {}
		for i, value in ipairs(k.values) do row.options[i] = { value = value, label = e.options[value] } end
	end
	return row
end

-- The panel's lines from the descriptor D: a heading ({ heading = true, label }) or a row; a heading with no row of
-- the panel under it (the panel key's) is left out, and a row marked first goes above all, without its heading.
function M.build(D)
	local list, heading = {}, nil
	for _, e in ipairs(D.order) do
		if e.heading then
			heading = e
		elseif KINDS[e.key] ~= nil and KINDS[e.key].first then
			table.insert(list, 1, row_of(e))
		elseif KINDS[e.key] ~= nil then
			if heading ~= nil then list[#list + 1], heading = heading, nil end
			list[#list + 1] = row_of(e)
		end
	end
	return list
end

function M.value(row, s)
	return s[row.field]
end

-- What must be set first for the row to change, and to what, or nil: the switch on for every other row; Custom for a
-- field of view while a preset gives it. A row that moved without changing the view would mislead the player (design
-- decision, 4 November 2026).
function M.waits_for(row, s)
	if row.key ~= Settings.ENABLED and row.key ~= Settings.OPACITY_KEY and not s.enabled then
		return Settings.ENABLED, true
	end
	if row.fov and s.preset ~= CUSTOM then return Settings.PRESET, CUSTOM end
	return nil
end

-- How the row shows value: On or Off, a preset by its name in the menu, a number on its step as Mods Menu writes it
-- (formatNumber in its main.js, 0.5.3: 3 and 1.5, not 3.0). say(text) gives a descriptor's text in the panel's
-- language, own(name) one of the panel's own words.
function M.text(row, value, say, own)
	if row.kind == "switch" then return own(value and "on" or "off") end
	if row.kind == "choice" then
		for _, o in ipairs(row.options) do
			if o.value == value then return say(o.label) or o.value end
		end
		return tostring(value)
	end
	if row.step < 1 then return (string.format("%.1f", value):gsub("%.0$", "")) end
	return string.format("%d", math.floor(value + 0.5))
end

-- The value a slider's position stands for: on the row's step, in its range.
function M.on_step(row, v)
	return math.max(row.min, math.min(row.max, Settings.snap(v, row.step)))
end

-- A switch turned over, or the option before (dir -1) or after (dir 1) the one set, round the list.
function M.next(row, s, dir)
	if row.kind == "switch" then return not s[row.field] end
	local at = 1
	for i, o in ipairs(row.options) do
		if o.value == s[row.field] then at = i end
	end
	return row.options[(at - 1 + dir) % #row.options + 1].value
end

-- Settings s with the row at value, read as the settings file would be: a preset gives its four fields of view.
function M.with(s, row, value, warn)
	local raw = Settings.raw(s)
	raw[row.key:lower()] = value
	return Settings.resolve(raw, warn)
end

-- Every setting the panel shows back to its default; the panel key stays, as it is set in Mods Menu.
function M.defaults(s, warn)
	return Settings.resolve({ [Settings.PANEL_KEY:lower()] = s.panel_key }, warn)
end

-- The field of view the view shows while the pointer is on the row, or nil: a field of view's row, the mod on.
function M.preview(row, s)
	if row ~= nil and row.fov and s.enabled then return s[row.field] end
	return nil
end

return M
