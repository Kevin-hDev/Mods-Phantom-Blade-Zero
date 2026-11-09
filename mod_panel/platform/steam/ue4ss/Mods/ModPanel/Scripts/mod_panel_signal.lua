-- The change signal of a mod, written after its settings file (D18: never before), in the form Mods Menu 0.8.3 writes
-- it: Mods/PBZModsMenuBridge/events-<name>.txt, which each of our mods reads once a second to take its new settings at
-- once, or to carry out an action. "Changed=<n>" tells of new settings, "Action=<n> <key>" of an action; numbers only
-- grow, so a mod tells a new event from one it has seen. The mod writes the number of the last action it carried out in
-- done-<name>.txt. Also the one place of the signal's path, which the watch of Mod Panel's own file takes.

local Files = require("mod_panel_files")
local Folders = require("mod_panel_folders")

local M = {}

local BRIDGE = Folders.BRIDGE
local MAX_FILE_BYTES = 8192
local ACTIONS_KEPT = 16           -- as Mods Menu: the latest actions not done yet
local TRIES = 5                   -- the first at once, then one a second; then the signal is given up, and said
local NEWLINE = "\r\n"            -- Mods Menu's line ends
local WHY = { busy = "held by another program", big = "larger than 8 KiB" }

-- In a file name, letters, digits and "_" stay; every other byte becomes "%" and two lowercase hex digits (Mods
-- Menu's rule).
local function encode_name(name)
	return (name:gsub("[^A-Za-z0-9_]", function(c) return string.format("%%%02x", c:byte()) end))
end

local function bridge_file(mods_dir, prefix, name)
	return mods_dir .. "/" .. BRIDGE .. "/" .. prefix .. encode_name(name) .. ".txt"
end

function M.events_path(mods_dir, name)
	return bridge_file(mods_dir, "events-", name)
end

-- A number of the files, or nil. One too long for an integer (a file edited by hand) is left out.
local function integer(s)
	return s and math.tointeger(tonumber(s))
end

-- What the files hold now: the Changed value an action alone keeps, the actions not done yet ({ n, key }, the order of
-- the file), and the highest number of the file and of the done mark. nil and why while one cannot be read, or the
-- signal file is being written (no End=1): the signal waits.
local function current(events, done)
	local mark_text, mark_why = Files.read(done, MAX_FILE_BYTES)
	if mark_text == nil and mark_why ~= "missing" then return nil, "the mod's done file is " .. WHY[mark_why] end
	local text, why = Files.read(events, MAX_FILE_BYTES)
	if text == nil and why ~= "missing" then return nil, "the signal file is " .. WHY[why] end
	text = text or ""
	if text ~= "" and not text:find("\nEnd=1", 1, true) then return nil, "the signal file is being written" end
	local mark = mark_text and integer(mark_text:match("Action=(%d+)")) or 0
	local now = { changed = ("\n" .. text):match("\nChanged=(%d*)") or "", actions = {}, highest = mark }
	now.highest = math.max(now.highest, integer(now.changed) or 0)
	for line in text:gmatch("[^\n]+") do
		local n, key = line:match("^Action=(%d+) ([A-Za-z0-9_]+)\r?$")
		n = integer(n)
		if n ~= nil then
			now.highest = math.max(now.highest, n)
			if n > mark then now.actions[#now.actions + 1] = { n, key } end
		end
	end
	return now
end

local function text_of(name, changed, actions)
	-- Our mods want a line before Changed=, as Mods Menu writes one.
	local lines = { "; Mod Panel events for " .. name .. ": numbers only grow, one per event.", "Changed=" .. changed }
	for i = math.max(1, #actions - ACTIONS_KEPT + 1), #actions do
		lines[#lines + 1] = string.format("Action=%d %s", actions[i][1], actions[i][2])
	end
	lines[#lines + 1] = "End=1"
	return table.concat(lines, NEWLINE) .. NEWLINE
end

-- note(text): said in the log.
function M.new(mods_dir, note)
	-- last: by mod, the last number written. pending: by mod, what is still to tell ({ changed, actions, tries }).
	local S = { last = {}, pending = {}, folder_said = false }

	-- The bridge's folder is missing: the game makes it (Files.make_folder), then the file is written again.
	local function put_making_folder(events, text)
		local made, why = Files.make_folder(events)
		if made then
			note("made the folder " .. BRIDGE .. " through the game's text saver")
			return Files.put(events, text)
		end
		if not S.folder_said then
			S.folder_said = true
			note(string.format("the folder %s is missing and cannot be made (%s): the mods are not told of a change "
				.. "made in the panel until they start again", BRIDGE, why))
		end
		return false, "no folder"
	end

	local function write(name, p)
		local events = M.events_path(mods_dir, name)
		local now, why = current(events, bridge_file(mods_dir, "done-", name))
		if now == nil then return false, why end
		-- os.time() in milliseconds never passes Mods Menu's clock (Date.now()); the rest makes the number grow.
		local n = math.max(os.time() * 1000, (S.last[name] or 0) + 1, now.highest + 1)
		local changed = now.changed
		if p.changed then changed, n = tostring(n), n + 1 end
		for _, key in ipairs(p.actions) do
			now.actions[#now.actions + 1] = { n, key }
			n = n + 1
		end
		local text = text_of(name, changed, now.actions)
		local ok, put_why = Files.put(events, text)
		if not ok and put_why == "no folder" then ok, put_why = put_making_folder(events, text) end
		if ok then S.last[name] = n - 1 end
		return ok, put_why
	end

	local function attempt(name)
		local p = S.pending[name]
		local ok, why = write(name, p)
		if ok then
			S.pending[name] = nil
			return true
		end
		p.tries = p.tries + 1
		-- Without the folder, trying again each second would not make it: the next change tries again.
		if why == "no folder" or p.tries >= TRIES then
			S.pending[name] = nil
			if why ~= "no folder" then
				note(string.format("%s: the signal could not be written in %d tries (%s): the mod reads its new "
					.. "settings at its next start", name, TRIES, why))
			end
		end
		return false, why
	end

	-- Tells name's mod that its settings file was just written (changed), or sends it an action (action, a row's key),
	-- or both. Written now when it can be; else kept, and tried again at each second(), TRIES times in all. Returns
	-- whether it was written now, or false and why.
	function S.send(name, changed, action)
		local p = S.pending[name] or { changed = false, actions = {}, tries = 0 }
		S.pending[name] = p
		p.changed, p.tries = p.changed or changed == true, 0
		if action ~= nil then
			p.actions[#p.actions + 1] = action
			if #p.actions > ACTIONS_KEPT then table.remove(p.actions, 1) end
		end
		return attempt(name)
	end

	function S.second()
		for name in pairs(S.pending) do attempt(name) end
	end

	return S
end

return M
