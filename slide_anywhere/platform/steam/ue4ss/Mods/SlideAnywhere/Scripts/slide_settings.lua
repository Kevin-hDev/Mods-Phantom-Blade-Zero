-- Slide Anywhere's settings: <ModName>.config.json in the mod's folder, the file Mods Menu (Nexus 149) edits, so the
-- menu and a hand edit change the same and only settings file. Tolerant reading: an unknown key is ignored, a missing
-- or wrong value falls back to its default and is reported in UE4SS.log.
-- Same file handling as Dodge Jump's dodge_jump_settings.lua, without its upgrade of an earlier version's file (this
-- mod has none yet); only the keys and their values differ.

local Json = require("slide_json")
local Buttons = require("slide_buttons")

local M = {}

-- SlideSpeed and SlideLength: 1 to 3 (Kevin, 5 November 2026: "un réglage avec une plage entre 1 et 3 pour la vitesse
-- du slide", and a range for its end, "glisser plus longtemps"); what they do is in slide_motion.lua. The menu offers
-- tenths, and a hand edit is kept to the nearest tenth too.
M.LOWEST, M.HIGHEST = 1, 3
-- SlideHold, the button held keeps the slide's speed (slide_trigger.lua): off by default, a setting to turn on (Kevin,
-- 5 November 2026: "un nouveau réglage activable").
M.DEFAULTS = { enabled = true, hold = false, speed = 1, length = 1 }

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
-- A hand edit may write a switch as text, or as the number 0 or 1.
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

-- No setting value is this long: a longer one is refused before trimming, whose pattern takes time growing with the
-- square of a long run of spaces (a hand edit could freeze the game for seconds, crash audit of 4 November 2026).
local MAX_VALUE_LENGTH = 64

local function trim(s)
	if #s > MAX_VALUE_LENGTH then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A text value as the settings compare it, trimmed and lowercase; nil for any other value.
local function word(value)
	return type(value) == "string" and trim(value):lower() or nil
end

local function switch(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then
		value = BOOLEANS[word(value)]
	elseif value == 0 or value == 1 then
		value = value == 1
	end
	if type(value) == "boolean" then return value end
	warn(string.format("%s must be true or false; using %s", name, tostring(default)))
	return default
end

-- The menu writes the choice as text ("1.0" to "3.0"); a hand edit may write a number.
local function ratio(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then value = tonumber(trim(value)) end
	if type(value) == "number" and value >= M.LOWEST and value <= M.HIGHEST then
		return math.floor(value * 10 + 0.5) / 10
	end
	warn(string.format("%s must be %.1f to %.1f; using %.1f", name, M.LOWEST, M.HIGHEST, default))
	return default
end

-- The menu writes the engine's key name, or None; a hand edit may change its case. nil: no button.
local function button(raw, row, warn)
	local value = raw[row.name:lower()]
	if value == nil then return nil end
	local name = row.known[word(value)]
	if name == nil then
		warn(string.format("%s is not one of the menu's buttons; using %s", row.name, Buttons.NONE))
	end
	if name == Buttons.NONE then return nil end
	return name
end

-- raw: the file's keys, lowercased. keys: the buttons picked, the controller's then the keyboard's, none missing.
function M.resolve(raw, warn)
	local s = {
		enabled = switch(raw, "enabled", "Enabled", M.DEFAULTS.enabled, warn),
		keys = {},
		hold = switch(raw, "slidehold", "SlideHold", M.DEFAULTS.hold, warn),
		speed = ratio(raw, "slidespeed", "SlideSpeed", M.DEFAULTS.speed, warn),
		length = ratio(raw, "slidelength", "SlideLength", M.DEFAULTS.length, warn),
	}
	for _, row in ipairs(Buttons.ROWS) do
		s.keys[#s.keys + 1] = button(raw, row, warn)
	end
	return s
end

function M.describe(s)
	return string.format("mod %s, buttons %s, hold %s, speed x%.1f, length x%.1f", s.enabled and "on" or "off",
		#s.keys > 0 and table.concat(s.keys, " / ") or "none", s.hold and "on" or "off", s.speed, s.length)
end

-- The folder of the mod whose script is at script_path (".../SlideAnywhere/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name.
function M.file_in(mod_dir)
	return mod_dir .. "/" .. mod_dir:match("([^/\\]+)$") .. ".config.json"
end

-- No format number in the file: Mods Menu shows every key of the config as a row, which the player could even
-- edit (seen on 3 November 2026). A future format will add one; a file without it is this format.
function M.default_text()
	local entries = { { "Enabled", M.DEFAULTS.enabled } }
	for _, row in ipairs(Buttons.ROWS) do entries[#entries + 1] = { row.name, Buttons.NONE } end
	entries[#entries + 1] = { "SlideHold", M.DEFAULTS.hold }
	entries[#entries + 1] = { "SlideSpeed", string.format("%.1f", M.DEFAULTS.speed) }
	entries[#entries + 1] = { "SlideLength", string.format("%.1f", M.DEFAULTS.length) }
	return Json.encode(entries)
end

-- The text reaches the disk at the close, so a failed close (a full disk) fails the write too.
local function write_whole(path, text)
	local f = io.open(path, "wb")
	local ok = f ~= nil and f:write(text) ~= nil
	if f ~= nil then ok = f:close() == true and ok end
	return ok
end

-- Written to a temporary file, then renamed: the config is never seen half written.
local function create(path, warn)
	local temporary = path .. ".tmp"
	if write_whole(temporary, M.default_text()) and os.rename(temporary, path) then
		warn("created the settings file with the defaults")
	else
		os.remove(temporary)
		warn("could not create the settings file; the Mods Menu cannot change the settings until it exists")
	end
end

-- At start: the file is made when missing, as the menu's bridge only replaces an existing config.
function M.ensure_file(path, warn)
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
	elseif code == NO_SUCH_FILE then
		create(path, warn)
	end
end

local function lowered(values)
	local raw = {}
	for key, value in pairs(values) do raw[key:lower()] = value end
	return raw
end

-- Returns the settings, or nil when the file exists but cannot be read at this moment (the caller tries again).
function M.load(path, warn)
	local f, _, code = io.open(path, "rb")
	if f == nil then
		if code ~= NO_SUCH_FILE then return nil end
		create(path, warn)
		return M.resolve({}, warn)
	end
	local text = f:read(MAX_FILE_BYTES)
	f:close()
	local values, reason = Json.decode(text or "")
	if values == nil then
		warn(string.format("the settings file is not valid JSON (%s); using the defaults", reason))
		return M.resolve({}, warn)
	end
	return M.resolve(lowered(values), warn)
end

return M
