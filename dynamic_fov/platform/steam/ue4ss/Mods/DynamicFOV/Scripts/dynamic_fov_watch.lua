-- When Dynamic FOV reads its settings: at each new pawn, and within a second of a change saved in the Mods Menu,
-- told by the bridge's event file (dynamic_fov_menu.lua). A settings file that exists but cannot be read is tried
-- again for a few looks, then left as it is until the next pawn or the next change. Taken from Dodge Jump's main.lua,
-- with two fixes: events from before the start do not count, and an event file unreadable during a read keeps the
-- number already seen.

local Settings = require("dynamic_fov_settings")
local SettingsFile = require("dynamic_fov_settings_file")
local Menu = require("dynamic_fov_menu")

local M = {}

local MAX_READ_RETRIES = 5        -- looks spent on a settings file that exists but cannot be read

-- settings_path and events_path are nil when the mod's folder is unknown. use(s, read) gets each settings read (read:
-- whether they are the file's own, not defaults for a missing or broken file) and returns the settings it put in
-- use, if not s (the panel's changes kept on top), which the log line gives; log and warn write to UE4SS.log.
function M.new(settings_path, events_path, use, log, warn)
	-- Events already in the file at start are from before it: only a higher number is a change.
	local W = { pending = false, retries = 0, last_change = events_path and Menu.last_change(events_path) or nil }

	local function load()
		-- Read before the settings: a change saved in between has a higher number and comes again at the next look.
		-- An event file unreadable now keeps the number already seen, or that change would count again.
		local change = events_path and Menu.last_change(events_path)
		local s, read = nil, false
		if settings_path then
			s, read = SettingsFile.load(settings_path, warn)
		else
			s = Settings.resolve({}, warn)
		end
		if not s then
			W.retries = W.retries + 1
			W.pending = W.retries <= MAX_READ_RETRIES
			if W.retries == 1 then
				warn("the settings file cannot be read now; trying again")
			elseif W.retries > MAX_READ_RETRIES then
				-- Without this, each menu event would start the reads again every second, without end.
				W.last_change = change or W.last_change
				if W.retries == MAX_READ_RETRIES + 1 then
					warn("the settings file still cannot be read; the settings stay as they are until the next pawn "
						.. "or the next change in the Mods Menu")
				end
			end
			return
		end
		W.last_change, W.pending, W.retries = change or W.last_change, false, 0
		log("settings: %s", Settings.describe(use(s, read) or s))
	end

	-- At each look: a read still pending, or a change saved in the menu since the last read.
	function W.check()
		if W.pending then
			load()
			return
		end
		local change = events_path and Menu.last_change(events_path)
		if change ~= nil and (W.last_change == nil or change > W.last_change) then
			log("settings changed in the Mods Menu")
			load()
		end
	end

	function W.new_pawn()
		W.retries = 0
		load()
	end

	return W
end

return M
