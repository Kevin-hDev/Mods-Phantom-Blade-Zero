-- Reading a file within a size, and the only writing of a file in Mod Panel. A file is written to a temporary file
-- first, then put in place, with Mod Panel's own names beside it (D36): a mod may keep its own .tmp and .bak there,
-- and our recovery must never take them for ours. Taken from Dynamic FOV 1.0.4 (put_in_place and recover of
-- dynamic_fov_settings_file.lua). A missing folder is made by the game (M.make_folder).

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")

local M = {}

local NO_SUCH_FILE = 2            -- what io.open gives on Windows for a file, or a folder, that is not there
local TEMPORARY, ASIDE, KEPT = ".modpanel-tmp", ".modpanel-bak", ".modpanel-kept"
local FOLDER_MADE = "modpanel-folder.txt"   -- written by the game's text saver to make a folder, removed at once
local TEXT_SAVER = "/Script/EasyCsv.Default__EasyCsv"

-- The file's text, or nil and why: "missing", "busy" (another program holds it, or it cannot be read now) or "big"
-- (more than max bytes).
function M.read(path, max)
	local f, _, code = io.open(path, "rb")
	if f == nil then return nil, code == NO_SUCH_FILE and "missing" or "busy" end
	local text, err = f:read(max + 1)
	f:close()
	-- Without an error, nothing read is an empty file.
	if text == nil and err ~= nil then return nil, "busy" end
	text = text or ""
	if #text > max then return nil, "big" end
	return text, nil
end

-- Whether a file is there; true too when another program holds it.
function M.exists(path)
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
		return true
	end
	return code ~= NO_SUCH_FILE
end

-- Whether the file can be written now: false while it is read-only, or held by another program.
function M.writable(path)
	local f = io.open(path, "r+b")
	if f == nil then return false end
	f:close()
	return true
end

-- Writes text to a temporary file, then puts it in place: the file is never seen half written. The text reaches the
-- disk at the close, so a failed close (a full disk) fails the writing too. Windows renames onto no existing file: the
-- file in place is set aside first, put back if the new one cannot take its place, removed once it has. A copy set
-- aside and left there by a cut (power off) is put back at the next start (M.recover). Returns whether it was written,
-- or false and why: "no folder" (its folder is not there), "cannot write" or "cannot replace".
function M.put(path, text)
	local temporary, aside = path .. TEMPORARY, path .. ASIDE
	local f, _, code = io.open(temporary, "wb")
	if f == nil and code == NO_SUCH_FILE then return false, "no folder" end
	local ok = f ~= nil and f:write(text) ~= nil
	if f ~= nil then ok = f:close() == true and ok end
	if not ok then
		os.remove(temporary)
		return false, "cannot write"
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
			return false, "cannot replace"
		end
	end
	if os.rename(temporary, path) ~= true then
		if had then os.rename(aside, path) end
		os.remove(temporary)
		return false, "cannot replace"
	end
	if had then os.remove(aside) end
	return true
end

local function save(saver, text, path) return saver:SaveStringToFileWithFullPath(text, path) end

-- Makes the missing folder of path: Lua cannot, and a system command (mkdir) would open a window over the game. The
-- game's text saver (EasyCsv, the function Mods Menu writes with) makes the folders a path needs (discovery 9): it
-- writes a file of Mod Panel's in that folder, removed at once, then the caller writes path itself (M.put), so the
-- bytes put in place are always Mod Panel's. The file's name has one dot only (D108): Mods Menu says the saver cuts a
-- name at its first dot (X.config.json written X.json, source unique). Returns whether the folder is there now, or
-- false and why.
function M.make_folder(path)
	if not Calls.ok(Calls.TEXT_SAVER) then return false, "the game's text saver is missing or not the one known" end
	local ok, saver = pcall(StaticFindObject, TEXT_SAVER)
	if not ok or not U.is_valid(saver) then return false, "the game's text saver is not in memory" end
	local probe = path:match("^(.*)[/\\][^/\\]+$") .. "/" .. FOLDER_MADE
	pcall(save, saver, "Mod Panel made this folder.", probe)
	if not M.exists(probe) then return false, "the game's text saver did not write" end
	os.remove(probe)
	return true
end

-- Renames the file to its name with ending added, in place of an older file of that name; whether it was done.
function M.set_aside(path, ending)
	os.remove(path .. ending)
	return os.rename(path, path .. ending) == true
end

-- A file set aside by a writing that a cut stopped half way is put back when the file is missing; with the file in
-- place, the copy is older and is removed. A temporary file left by a cut is removed, never put in place: a power cut
-- can lose a file's last writes even after its close, while the copy set aside was on the disk long before.
-- note(text) is told when a file was put back.
function M.recover(path, note)
	os.remove(path .. TEMPORARY)
	local aside = path .. ASIDE
	local a = io.open(aside, "rb")
	if a == nil then return end
	a:close()
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
		os.remove(aside)
	elseif code == NO_SUCH_FILE and os.rename(aside, path) == true then
		note("put back a file a writing had set aside before it was cut short")
	end
end

-- The same at start for another mod's settings file (D107), with one difference: with the file in place, the copy
-- may be the player's settings and the file the mod's defaults, made anew by the mod when it started before Mod Panel.
-- So the copy is never removed: kept beside the file under another name, and said. note(text) is told what was done.
function M.recover_other(path, note)
	os.remove(path .. TEMPORARY)
	local aside = path .. ASIDE
	local a = io.open(aside, "rb")
	if a == nil then return end
	a:close()
	local file = path:match("([^/\\]+)$")
	local f, _, code = io.open(path, "rb")
	if f == nil then
		if code == NO_SUCH_FILE and os.rename(aside, path) == true then
			note(string.format("put back %s, set aside by a writing that was cut short", file))
		end
		return
	end
	f:close()
	os.remove(path .. KEPT)
	if os.rename(aside, path .. KEPT) == true then
		note(string.format("a copy of %s set aside by a writing that was cut short is kept as %s%s", file, file, KEPT))
	end
end

return M
