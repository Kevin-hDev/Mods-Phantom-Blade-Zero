-- When the settings are read: at each new character (M.reload), and within a second of a change saved in Mods Menu
-- (M.check, which looks at the menu's event file). A file that exists but cannot be read now is tried again a few times.

local File = require("movement_file")
local Settings = require("movement_settings")
local Menu = require("movement_menu")

local M = {}

local CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5   -- looks spent on a settings file that exists but cannot be read

local W = { path = nil, events = nil, log = nil, next_check = 0, last_change = nil, pending = false, retries = 0,
	settings = Settings.resolve({}, function() end) }

local function warn(message)
	W.log("settings: %s", message)
end

-- mod_dir: the mod's folder, nil when it cannot be found (the settings stay at their defaults). log: as main.lua's.
function M.init(mod_dir, log)
	W.log = log
	W.path = mod_dir and File.file_in(mod_dir)
	W.events = mod_dir and Menu.events_file(mod_dir)
	if W.path ~= nil then File.ensure(W.path, warn) end
end

function M.settings()
	return W.settings
end

local function load()
	-- Read before the settings: a change saved in between has a higher number and comes again at the next look.
	local change = W.events and Menu.last_change(W.events)
	local s
	if W.path == nil then
		s = Settings.resolve({}, warn)
	else
		s = File.load(W.path, warn)
	end
	if s == nil then
		W.retries = W.retries + 1
		W.pending = W.retries <= MAX_READ_RETRIES
		if W.retries == 1 then
			warn("the settings file cannot be read now; trying again")
		elseif W.retries > MAX_READ_RETRIES then
			-- Without this, each menu event would start the reads again every second, without end.
			W.last_change = change
			if W.retries == MAX_READ_RETRIES + 1 then
				warn("the settings file still cannot be read; the settings stay as they are until the next loaded "
					.. "save or the next change in the Mods Menu")
			end
		end
		return
	end
	W.last_change, W.pending, W.retries, W.settings = change, false, 0, s
	W.log("settings: %s", Settings.describe(s))
end

-- A new character: the file gets its tries again.
function M.reload()
	W.retries = 0
	load()
end

function M.check(now)
	if now < W.next_check then return end
	W.next_check = now + CHECK_EVERY
	if W.pending then
		load()
		return
	end
	local change = W.events and Menu.last_change(W.events)
	if change ~= nil and (W.last_change == nil or change > W.last_change) then
		W.log("settings changed in the Mods Menu")
		-- A new change gets its own tries, even after an earlier one was given up.
		W.retries = 0
		load()
	end
end

return M
