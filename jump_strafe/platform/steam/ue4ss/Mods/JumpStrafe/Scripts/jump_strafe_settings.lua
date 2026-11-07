-- Jump Strafe's settings: <ModName>.config.json in the mod's folder, the file Mods Menu (Nexus 149) edits, so the
-- menu and a hand edit change the same and only settings file. Tolerant reading: an unknown key is ignored, a missing
-- or wrong value falls back to its default and is reported in UE4SS.log.

local Json = require("jump_strafe_json")

local M = {}

-- Air acceleration of each grip, in units/s². The game's own is about 245 (AirControl 0.35 x 700). Light, Medium
-- and Strong were tried in game and kept on 3 November 2026; Extreme and Max, the last one, were added the same day
-- and follow the same step (about x1.6).
M.GRIPS = { light = 1500, medium = 2500, strong = 4000, extreme = 6500, max = 10500 }
M.DEFAULTS = { enabled = true, grip = "medium", keep_momentum = true }

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
-- A hand edit may write a switch as text.
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function display(name)
	return name:sub(1, 1):upper() .. name:sub(2)
end

local function switch(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then value = BOOLEANS[trim(value):lower()] end
	if type(value) == "boolean" then return value end
	warn(string.format("%s must be true or false; using %s", name, tostring(default)))
	return default
end

-- raw: the file's keys, lowercased.
function M.resolve(raw, warn)
	local s = { grip = M.DEFAULTS.grip }
	s.enabled = switch(raw, "enabled", "Enabled", M.DEFAULTS.enabled, warn)
	s.keep_momentum = switch(raw, "keepmomentum", "KeepMomentum", M.DEFAULTS.keep_momentum, warn)
	if raw.grip ~= nil then
		local grip = type(raw.grip) == "string" and trim(raw.grip):lower() or nil
		if M.GRIPS[grip] ~= nil then
			s.grip = grip
		else
			warn(string.format("Grip must be Light, Medium, Strong, Extreme or Max; using %s", M.DEFAULTS.grip))
		end
	end
	s.air_accel = M.GRIPS[s.grip]
	return s
end

-- The folder of the mod whose script is at script_path (".../JumpStrafe/Scripts/main.lua"), or nil.
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
	return Json.encode({
		{ "Enabled", M.DEFAULTS.enabled },
		{ "Grip", display(M.DEFAULTS.grip) },
		{ "KeepMomentum", M.DEFAULTS.keep_momentum },
	})
end

-- Written to a temporary file, then renamed: the config is never seen half written.
local function create(path, warn)
	local temporary = path .. ".tmp"
	local f = io.open(temporary, "wb")
	local ok = f ~= nil and f:write(M.default_text()) ~= nil
	if f ~= nil then f:close() end
	ok = ok and os.rename(temporary, path)
	if ok then
		warn("created the settings file with the defaults")
	else
		os.remove(temporary)
		warn("could not create the settings file; the Mods Menu cannot change the settings until it exists")
	end
end

-- The menu's bridge only replaces an existing config, so the file is made as soon as the mod starts.
function M.ensure_file(path, warn)
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
	elseif code == NO_SUCH_FILE then
		create(path, warn)
	end
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
	local raw = {}
	for key, value in pairs(values) do raw[key:lower()] = value end
	return M.resolve(raw, warn)
end

return M
