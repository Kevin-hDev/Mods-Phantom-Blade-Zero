-- Mod Panel's own signal file, read once a second (D37), so a key changed in Mods Menu works at once. Mods Menu, or
-- its bridge, writes Mods/PBZModsMenuBridge/events-<ModName>.txt after each change it saves (the path is
-- mod_panel_signal.lua's): a line "Changed=<n>" whose number only grows, and "End=1" once the file is whole. Taken
-- from Dynamic FOV 1.0.4 (dynamic_fov_menu.lua and dynamic_fov_watch.lua): a number already there at start is from
-- before it, and a file that cannot be read keeps the number already seen.

local Files = require("mod_panel_files")

local M = {}

local MAX_FILE_BYTES = 8192

-- The number of the last change saved, or nil: no file, unreadable now, or still being written.
local function last_change(path)
	local text = Files.read(path, MAX_FILE_BYTES)
	if text == nil or not text:find("\nEnd=1", 1, true) then return nil end
	return tonumber(text:match("\nChanged=(%d+)"))
end

-- on_change() is called at the first second() that finds a higher number.
function M.new(path, on_change)
	local W = { last = last_change(path) }

	function W.second()
		local n = last_change(path)
		if n ~= nil and (W.last == nil or n > W.last) then
			W.last = n
			on_change()
		end
	end

	return W
end

return M
