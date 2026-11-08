-- Vault & Climb Anywhere's settings: <ModName>.config.json in the mod's folder, the file Mods Menu edits, so the menu
-- and a hand edit change the same and only settings file. Tolerant reading: an unknown key is ignored, a missing or
-- wrong value falls back to its default and is reported in UE4SS.log. The settings in force are this module's: the
-- measuring modules read MinHeight, MaxHeight, ClimbLeaning, EyeObstacles, DropLimit and MaxDropBehind here; apply()
-- sets them. A file from 0.1.0 still holds JumpButton and JumpKey, read as unknown keys: the mod now reads the game's
-- own jump keys (vault_jump_keys.lua).

local Json = require("vault_json")

local M = {}

-- Heights and drop in cm.
M.DEFAULTS = { enabled = true, min_height = 30, max_height = 500, climb_leaning = true, eye_obstacles = true,
	drop_limit = true, max_drop = 800 }

-- The menu's sliders, as the file holds them: MinHeight in cm by 5, MaxHeight in m by tenths, MaxDropBehind in whole
-- m. Each range keeps a value near the base game's, whose traversal goes from 75 to 155 cm. unit: cm per unit of the
-- file; digits: decimals the menu writes.
M.RANGES = {
	min_height = { key = "MinHeight", low = 20, high = 100, step = 5, unit = 1, digits = 0 },
	max_height = { key = "MaxHeight", low = 150, high = 500, step = 10, unit = 100, digits = 1 },
	max_drop = { key = "MaxDropBehind", low = 100, high = 1000, step = 100, unit = 100, digits = 0 },
}

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
-- A hand edit may write a switch as text, or as the number 0 or 1.
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

-- No setting value is this long: a longer one is refused before trimming, whose pattern takes time growing with the
-- square of a long run of spaces (a hand edit could freeze the game for seconds).
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

-- The value in the file's unit, as the menu writes it.
local function shown(range, cm)
	return string.format("%." .. range.digits .. "f", cm / range.unit)
end

-- The menu writes the slider's value as text; a hand edit may write a number, kept to the nearest step. In cm.
local function slider(raw, name, warn)
	local range = M.RANGES[name]
	local value = raw[range.key:lower()]
	if value == nil then return M.DEFAULTS[name] end
	if type(value) == "string" then value = tonumber(trim(value)) end
	if type(value) == "number" and value == value then
		local cm = math.floor(value * range.unit / range.step + 0.5) * range.step
		if cm >= range.low and cm <= range.high then return cm end
	end
	warn(string.format("%s must be %s to %s; using %s", range.key, shown(range, range.low), shown(range, range.high),
		shown(range, M.DEFAULTS[name])))
	return M.DEFAULTS[name]
end

-- raw: the file's keys, lowercased.
function M.resolve(raw, warn)
	return {
		enabled = switch(raw, "enabled", "Enabled", M.DEFAULTS.enabled, warn),
		min_height = slider(raw, "min_height", warn),
		max_height = slider(raw, "max_height", warn),
		climb_leaning = switch(raw, "climbleaning", "ClimbLeaning", M.DEFAULTS.climb_leaning, warn),
		eye_obstacles = switch(raw, "eyeobstacles", "EyeObstacles", M.DEFAULTS.eye_obstacles, warn),
		drop_limit = switch(raw, "droplimit", "DropLimit", M.DEFAULTS.drop_limit, warn),
		max_drop = slider(raw, "max_drop", warn),
	}
end

-- The settings in force: current, as resolve gave them, and the measuring modules' values.
function M.apply(s)
	M.current = s
	M.MinHeight, M.MaxHeight = s.min_height, s.max_height
	M.ClimbLeaning, M.EyeObstacles = s.climb_leaning, s.eye_obstacles
	M.DropLimit, M.MaxDropBehind = s.drop_limit, s.max_drop
end

function M.describe(s)
	return string.format("mod %s, heights %d cm to %.1f m, leaning faces %s, eye obstacles %s, drop limit %s",
		s.enabled and "on" or "off", s.min_height, s.max_height / 100,
		s.climb_leaning and "on" or "off", s.eye_obstacles and "on" or "off",
		s.drop_limit and string.format("%d m", s.max_drop // 100) or "off")
end

-- The folder of the mod whose script is at script_path (".../VaultClimbAnywhere/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name.
function M.file_in(mod_dir)
	return mod_dir .. "/" .. mod_dir:match("([^/\\]+)$") .. ".config.json"
end

-- No format number in the file: Mods Menu shows every key of the config as a row, which the player could even
-- edit. A future format will add one; a file without it is this format.
function M.default_text()
	local d, r = M.DEFAULTS, M.RANGES
	return Json.encode({
		{ "Enabled", d.enabled },
		{ "MinHeight", shown(r.min_height, d.min_height) }, { "MaxHeight", shown(r.max_height, d.max_height) },
		{ "ClimbLeaning", d.climb_leaning }, { "EyeObstacles", d.eye_obstacles }, { "DropLimit", d.drop_limit },
		{ "MaxDropBehind", shown(r.max_drop, d.max_drop) },
	})
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

M.apply(M.resolve({}, function() end))

return M
