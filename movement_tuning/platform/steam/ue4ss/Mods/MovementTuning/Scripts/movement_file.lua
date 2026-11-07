-- The settings file: <ModName>.config.json in the mod's folder, the file Mods Menu (Nexus 149) edits, so the menu and
-- a hand edit change the same and only settings file.

local Json = require("movement_json")
local Settings = require("movement_settings")

local M = {}

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2

-- The folder of the mod whose script is at script_path (".../MovementTuning/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name; nil when the folder has no name.
function M.file_in(mod_dir)
	local name = mod_dir:match("([^/\\]+)$")
	if name == nil then return nil end
	return mod_dir .. "/" .. name .. ".config.json"
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
	if write_whole(temporary, Settings.default_text()) and os.rename(temporary, path) then
		warn("created the settings file with the defaults")
	else
		os.remove(temporary)
		warn("could not create the settings file; the Mods Menu cannot change the settings until it exists")
	end
end

-- At start: the file is made when missing, as the menu's bridge only replaces an existing config.
function M.ensure(path, warn)
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
	elseif code == NO_SUCH_FILE then
		create(path, warn)
	end
end

-- Keys are read in any case; when a key is there twice in two cases (one written by hand, one by the menu), the one
-- spelled as in the menu wins, whatever the order Lua walks them in.
local SPELLED = {}
for _, key in ipairs(Settings.keys()) do SPELLED[key:lower()] = key end

local function lowered(values)
	local raw = {}
	for key, value in pairs(values) do
		local low = key:lower()
		if raw[low] == nil or key == SPELLED[low] then raw[low] = value end
	end
	return raw
end

-- Returns the settings, or nil when the file exists but cannot be read at this moment (the caller tries again).
function M.load(path, warn)
	local f, _, code = io.open(path, "rb")
	if f == nil then
		if code ~= NO_SUCH_FILE then return nil end
		create(path, warn)
		return Settings.resolve({}, warn)
	end
	local text = f:read(MAX_FILE_BYTES)
	f:close()
	local values, reason = Json.decode(text or "")
	if values == nil then
		warn(string.format("the settings file is not valid JSON (%s); using the defaults", reason))
		return Settings.resolve({}, warn)
	end
	return Settings.resolve(lowered(values), warn)
end

return M
