-- The changes made in the panel and not written yet, mod by mod: the only module that decides when a mod's settings
-- file is written. A change is written half a second after the last one, so ten steps of an arrow make one writing;
-- also before the panel goes to another mod, at its closing, and before an action. The file is read again just before,
-- and only the changed values are written over in its text (D35), so a value another program wrote meanwhile stays.
-- Then the mod's signal (D18: never before). A file that cannot be written is tried again each second, TRIES times,
-- while the panel says "Settings not saved"; the last failure is said with its reason, then the next change or the
-- closing tries again. Mod Panel never makes another mod's file: a file still missing after TRIES tries drops its
-- changes. A JavaScript mod's Key=Value file (D173) is the exception, as in Mods Menu: Mods Menu makes it, and its
-- folder, at its first save, so Mod Panel does too, under the line Mods Menu starts it with; and no signal follows,
-- the mod reads its file again by itself.

local Files = require("mod_panel_files")
local JsonEdit = require("mod_panel_json_edit")
local Values = require("mod_panel_values")
local JsMods = require("mod_panel_js_mods")
local Txt = require("mod_panel_txt")

local M = {}

local DELAY = 0.5                 -- seconds after the last change
local RETRY = 1                   -- seconds between two tries after a failure
local TRIES = 5
local MAX_FILE_BYTES = 256 * 1024 -- as the catalog reads it
local WHY = { busy = "held by another program", big = "larger than 256 KiB" }

-- d: { catalog, mods_dir, own (Mod Panel's folder name), signal (mod_panel_signal.lua), report(fmt, ...) and
-- note(fmt, ...) for the log's writings and problems, saved(name) told after each writing }.
function M.new(d)
	-- pending: by mod, { values = { [key] = { row, value } }, due (when to write; nil: at the next change or the
	-- closing), tries, failed }.
	local E = { pending = {} }

	-- The changes in the order of the mod's rows, as the file holds them: a key the file lacks is added in that order.
	local function changes(name, p)
		local list, entry = {}, d.catalog.get(name)
		local function add(key)
			local c = p.values[key]
			if c ~= nil then list[#list + 1] = { key, Values.to_file(c[1], c[2]), c[1] } end
		end
		local done = {}
		for _, row in ipairs(entry and entry.rows or {}) do
			if row.key ~= nil and not done[row.key] then
				done[row.key] = true
				add(row.key)
			end
		end
		-- Rows the mod no longer shows (its descriptor changed meanwhile), by key: the player's change still holds.
		local rest = {}
		for key in pairs(p.values) do
			if not done[key] then rest[#rest + 1] = key end
		end
		table.sort(rest)
		for _, key in ipairs(rest) do add(key) end
		return list
	end

	-- A JavaScript mod's new text: its values as Mods Menu writes them in a text file.
	local function txt_text(name, text, list)
		local entry = d.catalog.get(name)
		local title = entry and entry.title and entry.title.en or name
		for _, c in ipairs(list) do c[2] = Txt.literal(c[3], c[2]) end
		return Txt.set(text, list,
			"; " .. title .. " settings. Change a value and save; the mod picks it up while the game runs.")
	end

	-- A JavaScript mod's file put in place, its folder made first when it is not there yet: Mods Menu keeps some files
	-- in Saved/PBZModsMenu/Settings, a folder no one makes before their first save (Quest Status, trial of 8 November
	-- 2026). The path was checked against the two folders Mods Menu writes in (mod_panel_js_mods.lua).
	local function put_js(name, file, new)
		local ok, why = Files.put(file, new)
		if ok or why ~= "no folder" then return ok, why end
		local made, made_why = Files.make_folder(file)
		if not made then return false, "its folder could not be made: " .. made_why end
		d.report("%s: made the settings folder through the game's text saver", name)
		return Files.put(file, new)
	end

	-- Writes name's file now: true when it was written, false and why when it could not be, and whether the file is
	-- missing. Missing is tried again as any failure, at the closing too: a mod, or Mods Menu's bridge, may swap its
	-- file by a renaming, and a reading may fall in that instant (audit of 0.4.3, review of 0.4.4).
	local function write(name, p)
		local file, js = d.catalog.file(name), JsMods.is_js(name)
		local text, why = Files.read(file, MAX_FILE_BYTES)
		if why == "missing" and not js then return false, "the settings file is missing", true end
		if text == nil and why ~= "missing" then return false, "the settings file is " .. WHY[why] end
		local list = changes(name, p)
		local new, bad
		if js then new = txt_text(name, text, list) else new, bad = JsonEdit.set(text, list) end
		if new == nil then return false, "the settings file is not one JSON object (" .. bad .. ")" end
		if text ~= nil and not Files.writable(file) then
			return false, "the settings file is read-only, or held by another program"
		end
		local ok, put_why
		if js then ok, put_why = put_js(name, file, new) else ok, put_why = Files.put(file, new) end
		if not ok then return false, "the settings file could not be written (" .. put_why .. ")" end
		E.pending[name] = nil
		local keys = {}
		for i, c in ipairs(list) do keys[i] = c[1] .. " " .. (js and c[2] or JsonEdit.literal(c[2])) end
		d.report("%s: settings written (%s)", name, table.concat(keys, ", "))
		d.catalog.written(name, new)
		-- Mod Panel's own settings are read again by d.saved: a signal would only make its watch read them twice.
		if name ~= d.own and not js then d.signal.send(name, true) end
		d.saved(name)
		return true
	end

	-- last: no try follows before the next change, so a failure is said now.
	local function attempt(name, now, last)
		local p = E.pending[name]
		if p == nil then return true end
		local ok, why, missing = write(name, p)
		if ok then return true end
		p.failed, p.tries = true, p.tries + 1
		if missing and p.tries >= TRIES then
			E.pending[name] = nil
			d.note("%s: the settings file is gone, the changes made in the panel are dropped", name)
			return true
		elseif last or p.tries >= TRIES then
			p.due = nil
			d.note("%s: settings not saved (%s)", name, why)
		else
			p.due = now + RETRY
		end
		return false
	end

	-- The row's value changed in the panel to v (the row's value, written as Values.to_file gives it), at now.
	function E.set(name, row, v, now)
		local p = E.pending[name]
		if p == nil then
			p = { values = {}, tries = 0, failed = false }
			E.pending[name] = p
		end
		p.values[row.key] = { row, v }
		p.due, p.tries = now + DELAY, 0
	end

	-- The change waiting for key dropped: the file keeps what it holds (Undo of a Restore defaults not written yet).
	function E.drop(name, key)
		local p = E.pending[name]
		if p == nil then return end
		p.values[key] = nil
		if next(p.values) == nil then E.pending[name] = nil end
	end

	-- The value waiting to be written for key, or nil.
	function E.value(name, key)
		local p = E.pending[name]
		local c = p and p.values[key]
		if c == nil then return nil end
		return c[2]
	end

	-- At each frame of the open panel: writes the changes of one mod due. One a frame: All mods makes a change in every
	-- mod at once, and their writings in one frame made it last 27 to 171 ms (audit of 0.7.0).
	function E.step(now)
		for name, p in pairs(E.pending) do
			if p.due ~= nil and now >= p.due then
				attempt(name, now, false)
				return
			end
		end
	end

	-- Writes name's changes now (another mod, an action); whether nothing is left to write.
	function E.flush(name, now)
		return attempt(name, now, false)
	end

	-- At the closing: every mod's changes, a failure said at once.
	function E.flush_all(now)
		for name in pairs(E.pending) do attempt(name, now, true) end
	end

	-- Whether name has changes a writing failed to save: the panel then says "Settings not saved".
	function E.not_saved(name)
		local p = E.pending[name]
		return p ~= nil and p.failed
	end

	-- An action (a row's key) sent to name's mod, after its changes waiting: a mod carries it out with the settings
	-- the player set before it. Sent even when they could not be written: the panel says "Settings not saved", and
	-- the action then works on the settings the file holds.
	function E.action(name, key, now)
		attempt(name, now, false)
		return d.signal.send(name, false, key)
	end

	return E
end

return M
