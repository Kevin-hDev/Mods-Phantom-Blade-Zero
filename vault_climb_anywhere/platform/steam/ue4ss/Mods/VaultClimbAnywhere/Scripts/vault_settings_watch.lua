-- When the settings file is read (vault_settings.lua reads it): at each new pawn, and within a second of a change saved
-- in Mods Menu (its event file, vault_menu.lua). A file that exists but cannot be read now (another program holds it)
-- is tried again each second: MAX_READ_RETRIES times after each change in the menu, and without end until a first
-- read since the mod started, the mod staying idle meanwhile, so that it never plays with its defaults while the
-- player has switched it off. A read that gives the same settings and warnings as the last one writes nothing.

local Settings = require("vault_settings")
local Menu = require("vault_menu")
local Status = require("vault_status")

local M = {}

local MENU_CHECK_EVERY = 1        -- seconds between two looks at the Mods Menu's event file
local MAX_READ_RETRIES = 5        -- looks spent on a settings file that cannot be read, after a change in the menu

-- loaded: a read succeeded since the mod started; said: what the last read wrote, said again only when it changes;
-- changed: settings applied since main.lua last took them.
local S = { file = nil, events = nil, say = nil, next = 0, last_change = nil, reading = false, retries = 0,
	loaded = false, said = nil, changed = false }

-- say(fmt, ...): main.lua's event writer; file, events: the settings file and the menu's event file, or nil.
function M.start(say, file, events)
	S.say, S.file, S.events = say, file, events
end

local function warn(message)
	S.say("settings: %s", message)
end

local function failed(change)
	S.retries = S.retries + 1
	S.reading = not S.loaded or S.retries <= MAX_READ_RETRIES
	if S.retries == 1 then
		warn(S.loaded and "the settings file cannot be read now; trying again"
			or "the settings file cannot be read now; the mod waits, trying again every second")
	elseif S.loaded and S.retries == MAX_READ_RETRIES + 1 then
		-- Without this, each menu event would start the reads again every second, without end.
		S.last_change = change
		warn("the settings file still cannot be read; the settings stay as they are until the next loaded save or "
			.. "the next change in the Mods Menu")
	end
end

local function read()
	Status.note("the settings file")
	-- Read before the settings: a change saved in between has a higher number and comes again at the next look.
	local change = S.events and Menu.last_change(S.events)
	local messages = {}
	local function collect(message) messages[#messages + 1] = message end
	local s
	if S.file == nil then
		s = Settings.resolve({}, collect)
	else
		s = Settings.load(S.file, collect)
	end
	if s == nil then
		for _, message in ipairs(messages) do warn(message) end
		return failed(change)
	end
	S.last_change, S.reading, S.retries, S.loaded = change, false, 0, true
	Settings.apply(s)
	S.changed = true
	messages[#messages + 1] = Settings.describe(s)
	local said = table.concat(messages, "\n")
	if said == S.said then return end
	S.said = said
	for _, message in ipairs(messages) do warn(message) end
end

-- A new pawn: the settings read again, with the tries of a new change.
function M.new_pawn()
	S.retries = 0
	read()
end

-- Each frame: the menu's event file looked at each second, or the file read again while it could not be.
function M.check(now)
	if now < S.next then return end
	S.next = now + MENU_CHECK_EVERY
	if S.reading then return read() end
	Status.note("the Mods Menu's file")
	local change = S.events and Menu.last_change(S.events)
	if change ~= nil and (S.last_change == nil or change > S.last_change) then
		S.say("settings changed in the Mods Menu")
		S.retries = 0
		read()
	end
end

-- Whether settings were read since the mod started: until then the mod stays idle.
function M.loaded()
	return S.loaded
end

-- Whether settings were applied since the last call.
function M.take_changed()
	local changed = S.changed
	S.changed = false
	return changed
end

return M
