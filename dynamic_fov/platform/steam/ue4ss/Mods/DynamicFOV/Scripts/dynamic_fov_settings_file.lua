-- Dynamic FOV's settings file, <ModName>.config.json in the mod's folder: the file Mods Menu (Nexus 149) edits, so the
-- menu, a hand edit and the mod's panel change the same and only settings file. This module is the only part of the
-- mod that reads or writes it: two modules on one file end up with two ideas of it. Reading as in Dodge Jump's
-- dodge_jump_settings.lua; the writing is the panel's (1.0.2): the keys the player changed in it, over the file's own.

local Json = require("dynamic_fov_json")
local Settings = require("dynamic_fov_settings")
local Switch = require("dynamic_fov_panel_switch")
local Write = require("dynamic_fov_settings_write")

local M = {}

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
-- The copy of a file being brought to this version, kept until the next start finds the new file in place.
local BEFORE = ".before-1.0.9"

-- The folder of the mod whose script is at script_path (".../DynamicFOV/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name.
function M.file_in(mod_dir)
	return mod_dir .. "/" .. mod_dir:match("([^/\\]+)$") .. ".config.json"
end

local function create(path, warn)
	if Write.put_in_place(path, Settings.default_text()) then
		warn("created the settings file with the defaults")
	else
		warn("could not create the settings file; the Mods Menu cannot change the settings until it exists")
	end
end

-- The file's object, keys as written; or nil, then "missing", "busy" (cannot be opened now) or "bad", and why.
local function read_object(path)
	local f, _, code = io.open(path, "rb")
	if f == nil then return nil, code == NO_SUCH_FILE and "missing" or "busy" end
	local text = f:read(MAX_FILE_BYTES + 1)
	f:close()
	if text ~= nil and #text > MAX_FILE_BYTES then
		return nil, "bad", string.format("is larger than %d bytes", MAX_FILE_BYTES)
	end
	local values, reason = Json.decode(text or "")
	if values == nil then return nil, "bad", string.format("is not valid JSON (%s)", reason) end
	return values
end

-- The file's keys lowercased. Two keys that differ only by case: the menu's spelling counts, and between two others
-- the first in byte order, so the result never depends on the order pairs gives.
local function lowered(values, warn)
	local raw, kept = {}, {}
	for key, value in pairs(values) do
		local low = key:lower()
		local before = kept[low]
		local spelling = Settings.SPELLING[low]
		if before ~= nil then warn(string.format("%s is in the settings file more than once", spelling or key)) end
		if before == nil or key == spelling or (before ~= spelling and key < before) then
			raw[low], kept[low] = value, key
		end
	end
	return raw
end

local function quiet() end

-- The file's entries for values (the file's object, or nil) with changes over them (raw settings, lowercase keys):
-- the mod's keys in its order, as the mod uses them, then every key it does not know, as written. The panel's two
-- keys are never among those: while the panel is off they leave the file.
local function merged(values, changes)
	local raw = lowered(values or {}, quiet)
	for key, value in pairs(changes) do raw[key] = value end
	local s = Settings.resolve(raw, quiet)
	local entries, ours, others = Settings.entries(s), {}, {}
	for _, e in ipairs(entries) do ours[e[1]:lower()] = true end
	for _, name in ipairs(Settings.PANEL_KEYS) do ours[name:lower()] = true end
	for key in pairs(values or {}) do
		if not ours[key:lower()] then others[#others + 1] = key end
	end
	table.sort(others)
	for _, key in ipairs(others) do entries[#entries + 1] = { key, values[key] } end
	return s, entries
end

-- 1.0.9, the panel off: an earlier version's file loses the panel's two keys, which a menu would show as rows that do
-- nothing. The earlier file is copied first. A file that cannot be read now, or is not valid JSON, is left to load().
local function upgrade(path, warn)
	local values = not Switch.ON and read_object(path) or nil
	local found = false
	for key in pairs(values or {}) do
		for _, name in ipairs(Settings.PANEL_KEYS) do found = found or key:lower() == name:lower() end
	end
	if not found then return end
	local copy = path .. BEFORE
	local f = io.open(path, "rb")
	local text = f and f:read(MAX_FILE_BYTES)
	if f ~= nil then f:close() end
	local c = text and io.open(copy, "wb")
	local copied = c ~= nil and c:write(text) ~= nil
	if c ~= nil then copied = c:close() == true and copied end
	if copied and Write.put_in_place(path, Json.encode(select(2, merged(values, {})))) then
		warn(string.format("the panel's two settings left the settings file (the mod's own panel is off since 1.0.9); "
			.. "the earlier file is kept as %s until the next start", copy:match("([^/\\]+)$")))
	else
		os.remove(copy)
		warn("could not take the panel's two settings out of the settings file; trying again at the next start")
	end
end

-- At start. The menu's bridge only replaces an existing config, so the file is made when missing; a file an upgrade
-- stopped halfway left missing comes back from its copy; an earlier version's file is upgraded.
function M.ensure_file(path, warn)
	local copy = path .. BEFORE
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
		-- The last start's upgrade is done: its copy can go.
		os.remove(copy)
	elseif code ~= NO_SUCH_FILE then
		return
	elseif os.rename(copy, path) == true then
		warn("put back the settings file from an upgrade that stopped halfway")
	else
		return create(path, warn)
	end
	upgrade(path, warn)
end

-- Returns the settings, or nil when the file exists but cannot be read at this moment (the caller tries again); then
-- whether they are the file's own values (false: the defaults, for a file missing or broken).
function M.load(path, warn)
	local values, kind, why = read_object(path)
	if kind == "busy" then return nil end
	if kind == "missing" then
		create(path, warn)
		return Settings.resolve({}, warn), false
	end
	if kind == "bad" then
		warn(string.format("the settings file %s; using the defaults", why))
		return Settings.resolve({}, warn), false
	end
	return Settings.resolve(lowered(values, warn), warn), true
end

-- Writes the panel's changes at its close (raw settings, lowercase keys: only those the player changed), over the
-- file read again just before: a value Mods Menu or a hand edit saved meanwhile is kept, and every key of the file
-- the mod does not know stays as it is. A value of the file the mod cannot use is written as the mod uses it; the
-- last read already reported it. A file that is not
-- valid JSON keeps nothing to merge: it is set aside as <file>.invalid, so a hand edit is never lost unseen; a file
-- that cannot be written (read-only) is never replaced. Returns the settings the file now holds, or nil.
function M.save(path, changes, warn)
	local values, kind, why = read_object(path)
	if kind == "busy" then
		warn("could not save the panel's settings: the settings file cannot be read now")
		return nil
	end
	if kind ~= "missing" then
		local f = io.open(path, "r+b")
		if f == nil then
			warn("could not save the panel's settings: the settings file cannot be written (read-only, or in use)")
			return nil
		end
		f:close()
	end
	if kind == "bad" then
		local name = path:match("([^/\\]+)$") .. ".invalid"
		os.remove(path .. ".invalid")
		if os.rename(path, path .. ".invalid") ~= true then
			warn(string.format("could not save the panel's settings: the settings file %s, and %s cannot be replaced",
				why, name))
			return nil
		end
		warn(string.format("the settings file %s: kept as %s", why, name))
		values = nil
	end
	local s, entries = merged(values, changes)
	if Write.put_in_place(path, Json.encode(entries)) then return s end
	warn("could not save the panel's settings: the settings file could not be written")
	return nil
end

M.recover = Write.recover

return M
