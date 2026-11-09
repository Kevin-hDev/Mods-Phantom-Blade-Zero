-- The settings file: <ModName>.config.json in the mod's folder, the file Mods Menu (Nexus 149) edits, so the menu and
-- a hand edit change the same and only settings file. A file from an earlier version is upgraded at start
-- (movement_upgrade.lua), a copy kept until the next start finds the new file in place.

local Json = require("movement_json")
local Settings = require("movement_settings")
local Upgrade = require("movement_upgrade")
local V = require("movement_values")

local M = {}

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
local BEFORE_UPGRADE = ".before-1.0.3"

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

-- Written whole beside the file, then the old file is moved aside and the new one takes its place. Windows cannot
-- rename over a file, so for a moment there is no settings file: a start that finds only the copy puts it back.
local function replace(path, text)
	local temporary, before = path .. ".tmp", path .. BEFORE_UPGRADE
	if not write_whole(temporary, text) or not os.rename(path, before) then
		os.remove(temporary)
		return false
	end
	if os.rename(temporary, path) then return true end
	os.rename(before, path)
	os.remove(temporary)
	return false
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

-- An earlier version's file: its AutoSprint becomes SprintMode. One the decoder cannot read is left to M.load.
local function upgrade(path, text, warn)
	local values = Json.decode(text)
	if values == nil then return end
	local raw = lowered(values)
	local old = Settings.OLD_AUTO
	local on = V.switch(raw, old.key:lower(), old.key, old.default, function() end)
	local new = Upgrade.new_text(text, raw, on)
	if new == nil then return end
	local check = Json.decode(new)
	local mode = on and "Auto" or "Game"
	if check ~= nil and check[Settings.MODE.key] == mode and replace(path, new) then
		warn(string.format("the earlier version's %s is now %s %s", old.key, Settings.MODE.key, mode))
	else
		warn(string.format("could not replace the earlier version's %s in the settings file (still read as %s %s); "
			.. "trying again at the next start", old.key, Settings.MODE.key, mode))
	end
end

-- At start: the file is made when missing (the menu's bridge only replaces an existing config), put back when an
-- upgrade stopped halfway, and upgraded when it comes from an earlier version.
function M.ensure(path, warn)
	local before = path .. BEFORE_UPGRADE
	local f, _, code = io.open(path, "rb")
	if f == nil then
		if code ~= NO_SUCH_FILE then return end
		if not os.rename(before, path) then
			create(path, warn)
			return
		end
		warn("put back the settings file from an upgrade that stopped halfway")
		f = io.open(path, "rb")
		if f == nil then return end
	else
		-- The last start's upgrade is done: its copy can go.
		os.remove(before)
	end
	local text = f:read(MAX_FILE_BYTES)
	f:close()
	upgrade(path, text or "", warn)
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
