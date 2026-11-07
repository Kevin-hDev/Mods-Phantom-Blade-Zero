-- Dynamic FOV's settings file, <ModName>.config.json in the mod's folder: the file Mods Menu (Nexus 149) edits, so the
-- menu, a hand edit and the mod's panel change the same and only settings file. This module is the only part of the
-- mod that reads or writes it: two modules on one file end up with two ideas of it. Reading as in Dodge Jump's
-- dodge_jump_settings.lua; the writing is the panel's (1.0.2): the keys the player changed in it, over the file's own.

local Json = require("dynamic_fov_json")
local Settings = require("dynamic_fov_settings")

local M = {}

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2

-- The folder of the mod whose script is at script_path (".../DynamicFOV/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name.
function M.file_in(mod_dir)
	return mod_dir .. "/" .. mod_dir:match("([^/\\]+)$") .. ".config.json"
end

-- Writes text to a temporary file, then puts it in place: the file is never seen half written. The text reaches the
-- disk at the close, so a failed close (a full disk) fails the writing too. Windows renames onto no existing file: the
-- file in place is set aside first, put back if the new one cannot take its place, removed once it has. A copy set
-- aside and left there by a cut (power off) is put back at the next start (M.recover).
local function put_in_place(path, text)
	local temporary, aside = path .. ".tmp", path .. ".bak"
	local f = io.open(temporary, "wb")
	local ok = f ~= nil and f:write(text) ~= nil
	if f ~= nil then ok = f:close() == true and ok end
	if not ok then
		os.remove(temporary)
		return false
	end
	local had = false
	local current = io.open(path, "rb")
	if current ~= nil then
		current:close()
		-- Older than the file in place: a copy an earlier cut left there.
		os.remove(aside)
		had = os.rename(path, aside) == true
		if not had then
			os.remove(temporary)
			return false
		end
	end
	if os.rename(temporary, path) ~= true then
		if had then os.rename(aside, path) end
		os.remove(temporary)
		return false
	end
	if had then os.remove(aside) end
	return true
end

local function create(path, warn)
	if put_in_place(path, Settings.default_text()) then
		warn("created the settings file with the defaults")
	else
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
	local raw = lowered(values or {}, quiet)
	for key, value in pairs(changes) do raw[key] = value end
	local s = Settings.resolve(raw, quiet)
	local entries, ours, others = Settings.entries(s), {}, {}
	for _, e in ipairs(entries) do ours[e[1]:lower()] = true end
	for key in pairs(values or {}) do
		if not ours[key:lower()] then others[#others + 1] = key end
	end
	table.sort(others)
	for _, key in ipairs(others) do entries[#entries + 1] = { key, values[key] } end
	if put_in_place(path, Json.encode(entries)) then return s end
	warn("could not save the panel's settings: the settings file could not be written")
	return nil
end

-- At start: a file set aside by a save that a cut stopped half way is put back when the file is missing; with the
-- file in place, the copy is older and is removed. A temporary file left by a cut is removed, never put in place: a
-- power cut can lose a file's last writes even after its close, while the copy set aside was on the disk long before.
function M.recover(path, warn)
	os.remove(path .. ".tmp")
	local aside = path .. ".bak"
	local a = io.open(aside, "rb")
	if a == nil then return end
	a:close()
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
		os.remove(aside)
	elseif code == NO_SUCH_FILE and os.rename(aside, path) == true then
		warn("put back the settings file a save had set aside before it was cut short")
	end
end

return M
