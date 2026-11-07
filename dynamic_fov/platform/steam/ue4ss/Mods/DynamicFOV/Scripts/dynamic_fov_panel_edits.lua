-- What the panel changed (1.0.2): only the settings the player changed in it are written at its closing, over the
-- file read again, so a value Mods Menu or a hand edit saved meanwhile is kept; a change saved in Mods Menu while the
-- panel is open keeps the panel's own changes on top (audit of 5 November 2026: the panel wrote back every setting it
-- held, and a menu's change read while it was open undid the panel's). Changes a save could not write stay in use,
-- are tried again for a few looks, then at the next closing, unless the file changes that setting meanwhile: the
-- newer choice wins (reread of the audit: an unwritten change came back over a later choice made in Mods Menu).

local Settings = require("dynamic_fov_settings")
local SettingsFile = require("dynamic_fov_settings_file")

local M = {}

local MAX_RETRIES = 5             -- looks spent on changes a save could not write

-- The raw settings of a whose value differs from b's, or nil for none.
local function diff(a, b)
	local out = nil
	for key, value in pairs(a) do
		if value ~= b[key] then
			out = out or {}
			out[key] = value
		end
	end
	return out
end

-- raw with the changes of each table given on top, the last one winning.
local function over(raw, ...)
	for i = 1, select("#", ...) do
		for key, value in pairs(select(i, ...) or {}) do raw[key] = value end
	end
	return raw
end

local function quiet() end

function M.new()
	-- base: the raw settings in use at the opening, or as read since, without the changes made in the panel. unsaved:
	-- changes a save could not write; known: the file's raw settings when they were kept, or as read since. tries:
	-- looks that tried them since.
	local E = { base = nil, unsaved = nil, known = nil, tries = 0 }

	-- The unsaved changes the file has changed since give way to it; known becomes a copy of what was just read (raw
	-- itself gets the panel's changes next: reread of 5 November 2026, round 2).
	local function give_way(raw)
		if E.unsaved == nil then return end
		for key in pairs(E.unsaved) do
			if raw[key] ~= E.known[key] then E.unsaved[key] = nil end
		end
		E.known = over({}, raw)
		if next(E.unsaved) == nil then E.unsaved, E.known, E.tries = nil, nil, 0 end
	end

	-- At the opening, from the settings in use.
	function E.start(s)
		E.base = Settings.raw(s)
	end

	-- The changes to write: those not saved yet, then those made since the opening; nil for none.
	function E.changes(s)
		local made = E.base and diff(Settings.raw(s), E.base) or nil
		if made == nil and E.unsaved == nil then return nil end
		return over({}, E.unsaved, made)
	end

	-- Settings s just read from the file, with the panel's changes on top: those not saved yet and, while it is open,
	-- those made since the opening (current: the settings in use). The file's become the new base. read: whether s is
	-- the file's own; the defaults put in place of a missing or broken file are no newer choice.
	function E.on_read(s, current, open, read)
		local raw = Settings.raw(s)
		if read then give_way(raw) end
		local made = nil
		if open and E.base ~= nil then
			made = diff(Settings.raw(current), E.base)
			E.base = over(Settings.raw(s), E.unsaved)
		end
		if made == nil and E.unsaved == nil then return s end
		return Settings.resolve(over(raw, E.unsaved, made), quiet)
	end

	-- Writes the changes made on settings s; returns the settings the file now holds, or nil when nothing was written
	-- (nothing to write, or a failure, said by warn, whose changes are kept for the next try).
	function E.save(path, s, warn)
		local changes = E.changes(s)
		local known = E.unsaved ~= nil and E.known or E.base
		E.base = nil
		if changes == nil then return nil end
		local saved = SettingsFile.save(path, changes, warn)
		if saved == nil then
			E.unsaved, E.known = changes, known
		else
			E.unsaved, E.known = nil, nil
		end
		E.tries = 0
		return saved
	end

	-- Whether unsaved changes are due another try at this look.
	function E.retry_due()
		return E.unsaved ~= nil and E.tries < MAX_RETRIES
	end

	-- Tries the unsaved changes again, the panel closed; returns the settings the file now holds, or nil. The tries
	-- that fail are silent but the last, said with its reason: the failure at the closing was said already. What a try
	-- that works says is passed on (a broken file set aside).
	function E.retry(path, warn)
		E.tries = E.tries + 1
		local said = {}
		local saved = SettingsFile.save(path, E.unsaved, function(message) said[#said + 1] = message end)
		if saved ~= nil then
			E.unsaved, E.known, E.tries = nil, nil, 0
			for _, message in ipairs(said) do warn(message) end
		elseif E.tries == MAX_RETRIES then
			warn(string.format("the panel's changes still cannot be saved after %d more tries (%s): they stay in use "
				.. "until the game closes, and the panel tries again at its next closing", MAX_RETRIES,
				tostring(said[#said])))
		end
		return saved
	end

	return E
end

return M
