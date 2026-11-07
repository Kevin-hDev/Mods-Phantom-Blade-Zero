-- Mods Menu (Nexus 149) tells a UE4SS mod about each saved change through its bridge's event file,
-- Mods/PBZModsMenuBridge/events-<ModName>.txt: a line "Changed=<n>" whose number only grows, and "End=1" once the
-- file is whole. The bridge writes it after the new config is in place (FOR-MOD-AUTHORS.md of Mods Menu 0.4.3).
-- The menu's console command is not used: this game's UE4SS cannot hook the console (5 "Failed to add hook" on
-- ProcessConsoleExec in UE4SS.log, 3 November 2026).

local M = {}

local MAX_FILE_BYTES = 8192

-- In the file name, letters, digits and "_" stay, every other byte becomes "%" and two lowercase hex digits.
local function encode_name(name)
	return (name:gsub("[^%w_]", function(c) return string.format("%%%02x", c:byte()) end))
end

function M.events_file(mod_dir)
	local mods, name = mod_dir:match("^(.*)[/\\]([^/\\]+)$")
	return mods .. "/PBZModsMenuBridge/events-" .. encode_name(name) .. ".txt"
end

-- The number of the last change saved by the menu, or nil: no file (no bridge, or nothing saved yet), unreadable now,
-- or still being written.
function M.last_change(path)
	local f = io.open(path, "rb")
	if f == nil then return nil end
	local text = f:read(MAX_FILE_BYTES)
	f:close()
	if text == nil or not text:find("\nEnd=1") then return nil end
	return tonumber(text:match("\nChanged=(%d+)"))
end

return M
