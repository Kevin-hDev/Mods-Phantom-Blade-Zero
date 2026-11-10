-- Dynamic FOV's settings: their ranges, steps and defaults, the presets, and which key of the settings file gives which
-- setting. Tolerant reading (dynamic_fov_values.lua): an unknown key is ignored, a missing or wrong value falls back to
-- its default, a number out of range is brought back into it, and both are reported in UE4SS.log. The file itself,
-- read and written in one place only: dynamic_fov_settings_file.lua.

local Json = require("dynamic_fov_json")
local Hotkey = require("dynamic_fov_hotkey")
local Values = require("dynamic_fov_values")

local M = {}

-- Each field of view is the one seen in its situation, not an amount added to the normal view (design decision,
-- 3 November 2026: each row reads on its own). 75 is the game's own in all four situations (CameraProbe, sessions 1
-- to 4); the sprint starts wider so the mod does what it is installed for without any setting.
M.FOV_MIN, M.FOV_MAX, M.FOV_STEP = 40, 150, 1
M.GAME_FOV = 75
M.TIME_MIN, M.TIME_MAX, M.TIME_STEP = 0.2, 3.0, 0.1
-- The colours: the game's, or a general saturation at one of five profiles, in % (chosen on 5 November 2026); each
-- place keeps its own ranges (dynamic_fov_image.lua). The clean image turns off five effects. No preset changes either.
M.COLOURS = { "Game", "120", "140", "160", "180", "200" }
-- How dark the panel's backdrop is, in % (5 November 2026: a little darker than 1.0.2's 55 by default).
M.OPACITY_MIN, M.OPACITY_MAX, M.OPACITY_STEP = 40, 90, 5
M.DEFAULTS = { enabled = true, preset = "Default", normal = M.GAME_FOV, sprint = 90, crouch = M.GAME_FOV,
	lock_on = M.GAME_FOV, transition = 1.5, distance = 0, height = 0, side = 0, steady = false, no_recenter = false,
	no_pull_back = false, no_shake = false, colours = "Game", clean_image = false, panel_opacity = 65,
	panel_key = Hotkey.DEFAULT }
-- Each preset moves the four fields of view from the defaults above by the same amount, so the sprint stays wider
-- than the normal view (values and names chosen on 3 November 2026). Game gives the game's own everywhere, the sprint
-- too, first in the list (7 November 2026: Default widens the sprint, and no preset gave the game's view). Custom uses
-- the file's four values.
M.PRESETS = {
	{ value = "Game", fov = M.GAME_FOV },
	{ value = "VeryClose", offset = -26 },
	{ value = "Close", offset = -13 },
	{ value = "Default", offset = 0 },
	{ value = "Far", offset = 15 },
	{ value = "Custom", custom = true },
}
M.FOV_KEYS = {
	{ field = "normal", key = "fieldofview", name = "FieldOfView" },
	{ field = "sprint", key = "sprint", name = "Sprint" },
	{ field = "crouch", key = "crouch", name = "Crouch" },
	{ field = "lock_on", key = "lockon", name = "LockOn" },
}
-- Where the view sits, the same in the four situations (design decision, 4 November 2026). Distance in % of each
-- mode's own, so the sprint keeps its step back; height and side in cm, side positive to the right (the game's view
-- sits 80 cm right of the character: -80 centres it, CameraProbe pass 4). 0 is the game's view, and no preset
-- changes them.
M.POSITION_KEYS = {
	{ field = "distance", key = "distance", name = "Distance", min = -50, max = 100, step = 5 },
	{ field = "height", key = "height", name = "Height", min = -100, max = 100, step = 5 },
	{ field = "side", key = "side", name = "Side", min = -200, max = 200, step = 5 },
}
-- The comfort options (1.0.5, chosen on 7 November 2026), the game's camera unless turned on: a mod updated changes no
-- one's camera unasked. No preset changes them (dynamic_fov_comfort.lua writes them).
M.COMFORT_KEYS = {
	{ field = "steady", key = "steadycharacter", name = "SteadyCharacter", log = "steady character" },
	{ field = "no_recenter", key = "nosprintrecentering", name = "NoSprintRecentering", log = "no recentering in sprint" },
	{ field = "no_pull_back", key = "nosprintpullback", name = "NoSprintPullBack", log = "no pull-back in sprint" },
	{ field = "no_shake", key = "nosprintshake", name = "NoSprintShake", log = "no shake in sprint" },
}

local PRESET_VALUES = {}
for i, p in ipairs(M.PRESETS) do PRESET_VALUES[i] = p.value end

-- The file's keys, spelled as the menu writes them; read in any case. SPELLING gives a lowercase key's spelling.
M.ENABLED, M.PRESET, M.TRANSITION, M.PANEL_KEY = "Enabled", "Preset", "TransitionTime", "PanelKey"
M.COLOURS_KEY, M.CLEAN_KEY, M.OPACITY_KEY = "Colours", "CleanImage", "PanelOpacity"
M.SPELLING = {}
for _, name in ipairs({ M.ENABLED, M.PRESET, M.TRANSITION, M.PANEL_KEY, M.COLOURS_KEY, M.CLEAN_KEY, M.OPACITY_KEY }) do
	M.SPELLING[name:lower()] = name
end
for _, k in ipairs(M.FOV_KEYS) do M.SPELLING[k.key] = k.name end
for _, k in ipairs(M.POSITION_KEYS) do M.SPELLING[k.key] = k.name end
for _, k in ipairs(M.COMFORT_KEYS) do M.SPELLING[k.key] = k.name end

M.snap = Values.snap

-- The menu writes the key's engine name, or None; a hand edit may change its case.
local function key_name(raw, warn)
	local value = raw[M.PANEL_KEY:lower()]
	if value == nil then return M.DEFAULTS.panel_key end
	local name = type(value) == "string" and Hotkey.canonical(Values.trim(value)) or nil
	if name == Hotkey.MODS_MENU then
		warn(string.format("PanelKey %s opens Mods Menu; using %s", name, M.DEFAULTS.panel_key))
		return M.DEFAULTS.panel_key
	end
	if name ~= nil then return name end
	warn(string.format("PanelKey must be a key the Mods Menu offers, or None; using %s", M.DEFAULTS.panel_key))
	return M.DEFAULTS.panel_key
end

-- The four fields of view a preset gives, or nil for Custom.
function M.preset_values(value)
	local preset = nil
	for _, p in ipairs(M.PRESETS) do
		if p.value:lower() == value:lower() then preset = p end
	end
	if preset == nil or preset.custom then return nil end
	local v = {}
	for _, k in ipairs(M.FOV_KEYS) do v[k.field] = preset.fov or M.DEFAULTS[k.field] + preset.offset end
	return v
end

-- raw: the file's keys, lowercased. The four fields of view come out as the preset gives them, or from the file
-- with Custom; the file's four values are read in every preset, kept in s.custom (they come back with Custom), and
-- reported when wrong, saying they wait for Custom.
function M.resolve(raw, warn)
	local preset = Values.choice(raw, M.PRESET:lower(), M.PRESET, PRESET_VALUES, M.DEFAULTS.preset, warn)
	local s = { enabled = Values.switch(raw, M.ENABLED:lower(), M.ENABLED, M.DEFAULTS.enabled, warn),
		preset = preset, custom = {} }
	local warn_row = warn
	local given = M.preset_values(preset)
	if given ~= nil then
		warn_row = function(message) warn(string.format("%s under Custom (Preset is %s)", message, preset)) end
	end
	for _, k in ipairs(M.FOV_KEYS) do
		s.custom[k.field] = Values.number(raw, k.key, k.name, M.DEFAULTS[k.field], M.FOV_MIN, M.FOV_MAX, M.FOV_STEP,
			warn_row)
		s[k.field] = given and given[k.field] or s.custom[k.field]
	end
	s.transition = Values.number(raw, M.TRANSITION:lower(), M.TRANSITION, M.DEFAULTS.transition, M.TIME_MIN,
		M.TIME_MAX, M.TIME_STEP, warn)
	for _, k in ipairs(M.POSITION_KEYS) do
		s[k.field] = Values.number(raw, k.key, k.name, M.DEFAULTS[k.field], k.min, k.max, k.step, warn)
	end
	for _, k in ipairs(M.COMFORT_KEYS) do
		s[k.field] = Values.switch(raw, k.key, k.name, M.DEFAULTS[k.field], warn)
	end
	s.colours = Values.choice(raw, M.COLOURS_KEY:lower(), M.COLOURS_KEY, M.COLOURS, M.DEFAULTS.colours, warn)
	s.clean_image = Values.switch(raw, M.CLEAN_KEY:lower(), M.CLEAN_KEY, M.DEFAULTS.clean_image, warn)
	s.panel_opacity = Values.number(raw, M.OPACITY_KEY:lower(), M.OPACITY_KEY, M.DEFAULTS.panel_opacity, M.OPACITY_MIN,
		M.OPACITY_MAX, M.OPACITY_STEP, warn)
	s.panel_key = key_name(raw, warn)
	return s
end

-- Whether the four fields of view are the game's own (the Game preset, or Custom at 75).
function M.game_fovs(s)
	for _, k in ipairs(M.FOV_KEYS) do
		if s[k.field] ~= M.GAME_FOV then return false end
	end
	return true
end

-- The factor the colours give to the saturation, or nil for the game's own.
function M.colour_factor(s)
	local percent = tonumber(s.colours)
	return percent and percent / 100 or nil
end

-- The file's keys for settings s, as resolve() would read them back: the switch, the preset, the transition, the four
-- fields of view as set under Custom, the place, the comfort options, the image, then the panel's backdrop and key, in
-- the order the mod writes them.
function M.raw(s)
	local raw = { [M.ENABLED:lower()] = s.enabled, [M.PRESET:lower()] = s.preset,
		[M.TRANSITION:lower()] = s.transition, [M.COLOURS_KEY:lower()] = s.colours,
		[M.CLEAN_KEY:lower()] = s.clean_image, [M.OPACITY_KEY:lower()] = s.panel_opacity,
		[M.PANEL_KEY:lower()] = s.panel_key }
	for _, k in ipairs(M.FOV_KEYS) do raw[k.key] = s.custom[k.field] end
	for _, k in ipairs(M.POSITION_KEYS) do raw[k.key] = s[k.field] end
	for _, k in ipairs(M.COMFORT_KEYS) do raw[k.key] = s[k.field] end
	return raw
end

function M.entries(s)
	local raw = M.raw(s)
	local order = { M.ENABLED, M.PRESET, M.TRANSITION }
	for _, k in ipairs(M.FOV_KEYS) do order[#order + 1] = k.name end
	for _, k in ipairs(M.POSITION_KEYS) do order[#order + 1] = k.name end
	for _, k in ipairs(M.COMFORT_KEYS) do order[#order + 1] = k.name end
	order[#order + 1] = M.COLOURS_KEY
	order[#order + 1] = M.CLEAN_KEY
	order[#order + 1] = M.OPACITY_KEY
	order[#order + 1] = M.PANEL_KEY
	local entries = {}
	for i, name in ipairs(order) do entries[i] = { name, raw[name:lower()] } end
	return entries
end

-- The comfort options turned on, for the log.
local function comfort_text(s)
	local on = {}
	for _, k in ipairs(M.COMFORT_KEYS) do
		if s[k.field] then on[#on + 1] = k.log end
	end
	return #on > 0 and table.concat(on, ", ") or "none"
end

-- The settings for the log; under a preset, the file's own four values too when they differ, as they are the ones
-- written.
function M.describe(s)
	local text = string.format("mod %s, preset %s, field of view %d, sprint %d, crouch %d, lock-on %d, transition "
		.. "%.1f s, distance %+d%%, height %+d cm, side %+d cm, colours %s, clean image %s, panel background %d%%, panel key %s"
		.. ", comfort: %s",
		s.enabled and "on" or "off", s.preset, s.normal, s.sprint, s.crouch, s.lock_on, s.transition, s.distance,
		s.height, s.side, s.colours == "Game" and "the game's" or s.colours .. "%", s.clean_image and "on" or "off",
		s.panel_opacity, s.panel_key, comfort_text(s))
	local c = s.custom
	if c.normal == s.normal and c.sprint == s.sprint and c.crouch == s.crouch and c.lock_on == s.lock_on then
		return text
	end
	return string.format("%s; under Custom: field of view %d, sprint %d, crouch %d, lock-on %d", text, c.normal,
		c.sprint, c.crouch, c.lock_on)
end

-- No format number in the file yet: a file without one is this format. A later format adds one under a key Mods Menu
-- makes no row for: it shows every key made of letters, digits and _ as a row the player could edit (seen on 3
-- November 2026).
function M.default_text()
	return Json.encode(M.entries(M.resolve({}, function() end)))
end

return M
