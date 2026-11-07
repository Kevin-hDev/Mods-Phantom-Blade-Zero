-- Dodge Jump's settings: <ModName>.config.json in the mod's folder, the file Mods Menu (Nexus 149) edits, so the menu
-- and a hand edit change the same and only settings file. Tolerant reading: an unknown key is ignored, a missing or
-- wrong value falls back to its default and is reported in UE4SS.log.
-- Same file handling as Tap Strafe's tap_strafe_settings.lua, plus the length check in trim and the upgrade of an
-- earlier version's file (dodge_jump_upgrade.lua); only the keys and their values differ.

local Json = require("dodge_jump_json")
local Buttons = require("dodge_jump_buttons")
local Upgrade = require("dodge_jump_upgrade")

local M = {}

-- Chains: how many double-then-triple jumps one jump may hold, 1 to 3, so 2 to 6 jumps in the air (design decision,
-- 3 November 2026: more, or no limit, climbs past the height where the game kills the character in the air, which
-- this version does not handle).
-- The buttons' rows and names are in dodge_jump_buttons.lua. Keys of earlier versions (the test version's
-- DoubleSound and TripleSound, the Button of 1.0.0 and 1.0.1) are read nowhere else: an unknown key is ignored.
M.MAX_CHAINS = 3
-- Speed: the rate the air jumps' dodges play at, 1 (the game's) to 3 (Kevin, 5 November 2026: "plage de réglage
-- entre 1 et 3"). The menu offers tenths, and a hand edit is kept to the nearest tenth too: the log says a few things
-- once per speed (dodge_jump_exit.lua), so a few speeds only.
M.MIN_SPEED, M.MAX_SPEED = 1, 3
-- Volume: the air jumps' sounds, 0 (none) to 100 % (their measured loudness), asked by Kevin on 5 November 2026.
-- The menu offers steps of 5; a hand edit is kept to the percent.
M.MAX_VOLUME = 100
M.DEFAULTS = { enabled = true, chains = 1, speed = 1, volume = 100 }

local MAX_FILE_BYTES = 16384
local NO_SUCH_FILE = 2
-- The copy of a file being upgraded, kept until the next start finds the new file in place.
local BEFORE_UPGRADE = ".before-1.0.2"
-- A hand edit may write a switch as text, or as the number 0 or 1.
local BOOLEANS = { ["true"] = true, yes = true, on = true, ["1"] = true,
	["false"] = false, no = false, off = false, ["0"] = false }

-- No setting value is this long: a longer one is refused before trimming, whose pattern takes time growing with the
-- square of a long run of spaces (a hand edit could freeze the game for seconds, crash audit of 4 November 2026).
local MAX_VALUE_LENGTH = 64

local function trim(s)
	if #s > MAX_VALUE_LENGTH then return "" end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A text value as the settings compare it, trimmed and lowercase; nil for any other value.
local function word(value)
	return type(value) == "string" and trim(value):lower() or nil
end

local function switch(raw, key, name, default, warn)
	local value = raw[key]
	if value == nil then return default end
	if type(value) == "string" then
		value = BOOLEANS[word(value)]
	elseif value == 0 or value == 1 then
		value = value == 1
	end
	if type(value) == "boolean" then return value end
	warn(string.format("%s must be true or false; using %s", name, tostring(default)))
	return default
end

-- The menu writes the choice as text ("1" to "3"); a hand edit may write a number.
local function chains(raw, warn)
	local value = raw.chains
	if value == nil then return M.DEFAULTS.chains end
	if type(value) == "string" then value = tonumber(trim(value)) end
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= M.MAX_CHAINS then
		return value
	end
	warn(string.format("Chains must be 1 to %d; using %d", M.MAX_CHAINS, M.DEFAULTS.chains))
	return M.DEFAULTS.chains
end

-- A number from low to high, kept to the nearest 1/per. The menu writes the choice as text ("1.0", "50"); a hand
-- edit may write a number. shown: how the warning writes the bounds.
local function number(raw, name, low, high, default, per, shown, warn)
	local value = raw[name:lower()]
	if value == nil then return default end
	if type(value) == "string" then value = tonumber(trim(value)) end
	if type(value) == "number" and value >= low and value <= high then
		return math.floor(value * per + 0.5) / per
	end
	warn(string.format("%s must be " .. shown .. " to " .. shown .. "; using " .. shown, name, low, high, default))
	return default
end

-- The menu writes the engine's key name; a hand edit may change its case.
local function button(raw, row, warn)
	local value = raw[row.name:lower()]
	if value == nil then return row.default end
	local name = row.known[word(value)]
	if name ~= nil then return name end
	warn(string.format("%s is not one of the menu's buttons; using %s", row.name, row.default))
	return row.default
end

-- raw: the file's keys, lowercased. air_keys and jump_keys: the controller's button, then the keyboard's.
function M.resolve(raw, warn)
	return {
		enabled = switch(raw, "enabled", "Enabled", M.DEFAULTS.enabled, warn),
		chains = chains(raw, warn),
		speed = number(raw, "AirJumpSpeed", M.MIN_SPEED, M.MAX_SPEED, M.DEFAULTS.speed, 10, "%.1f", warn),
		volume = number(raw, "AirJumpSoundVolume", 0, M.MAX_VOLUME, M.DEFAULTS.volume, 1, "%d", warn),
		air_keys = { button(raw, Buttons.AIR_PAD, warn), button(raw, Buttons.AIR_KEY, warn) },
		jump_keys = { button(raw, Buttons.JUMP_PAD, warn), button(raw, Buttons.JUMP_KEY, warn) },
	}
end

function M.describe(s)
	return string.format("mod %s, chains %d, speed %g, sound %d%%, air jump %s, jump %s", s.enabled and "on" or "off",
		s.chains, s.speed, s.volume, table.concat(s.air_keys, " / "), table.concat(s.jump_keys, " / "))
end

-- The folder of the mod whose script is at script_path (".../DodgeJump/Scripts/main.lua"), or nil.
function M.mod_dir(script_path)
	return script_path:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
end

-- The menu looks for <ModName>.config.json, ModName being the mod's folder name.
function M.file_in(mod_dir)
	return mod_dir .. "/" .. mod_dir:match("([^/\\]+)$") .. ".config.json"
end

-- No format number in the file: Mods Menu shows every key of the config as a row, which the player could even
-- edit (seen on 3 November 2026). A future format will add one; a file without it is this format.
function M.default_text()
	local entries = { { "Enabled", M.DEFAULTS.enabled }, { "Chains", tostring(M.DEFAULTS.chains) },
		{ "AirJumpSpeed", string.format("%.1f", M.DEFAULTS.speed) },
		{ "AirJumpSoundVolume", tostring(M.DEFAULTS.volume) } }
	for _, row in ipairs(Buttons.ROWS) do entries[#entries + 1] = { row.name, row.default } end
	return Json.encode(entries)
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
	if write_whole(temporary, M.default_text()) and os.rename(temporary, path) then
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

local function lowered(values)
	local raw = {}
	for key, value in pairs(values) do raw[key:lower()] = value end
	return raw
end

-- An earlier version's file gets the rows that keep its choices; one the decoder cannot read is left to load().
local function upgrade(path, text, warn)
	local values = Json.decode(text)
	if values == nil then return end
	local new = Upgrade.new_text(text, lowered(values), word)
	if new == nil then return end
	local added = Json.decode(new)
	local air = string.format("%s / %s", Buttons.JUMP_PAD.default, Buttons.JUMP_KEY.default)
	if added ~= nil and added[Buttons.AIR_PAD.name] ~= nil and replace(path, new) then
		warn(string.format("the earlier version's Button Jump is carried over: air jumps on %s", air))
	else
		warn(string.format("could not carry the earlier version's Button Jump over (air jumps on %s); air jumps stay "
			.. "on the default buttons, trying again at the next start", air))
	end
end

-- At start: the file is made when missing (the menu's bridge only replaces an existing config), put back when an
-- upgrade stopped halfway, and upgraded when it comes from an earlier version.
function M.ensure_file(path, warn)
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
		return M.resolve({}, warn)
	end
	local text = f:read(MAX_FILE_BYTES)
	f:close()
	local values, reason = Json.decode(text or "")
	if values == nil then
		warn(string.format("the settings file is not valid JSON (%s); using the defaults", reason))
		return M.resolve({}, warn)
	end
	return M.resolve(lowered(values), warn)
end

return M
