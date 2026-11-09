-- Choosing a key or a button by pressing it. Cross, Enter or a click on the value of a key row: the row says "Press a
-- key", and each key pressed is judged. Taken when it is in the row's reach, any key Mod Panel can name for its own
-- panel key and the row's list for another mod's (D69), and when no other key row uses it (D64): set as a step is
-- (mod_panel_changes.lua). Else refused, the reason under the row's label, and the wait goes on. A button row says
-- "Press a button": a button of its list taken, another refused. The wait ends at a key or a button taken; at Escape;
-- at the panel's controller button, which never changes the row; at Circle, on a key row or on a button row whose list
-- lacks it; 5 s after the start or the last refusal (D84), "No key pressed" said 3 s; at another mod; at the panel's
-- closing (D83). Meanwhile no other command acts (mod_panel_commands.lua). Keys are read by UE4SS's binds, made at the
-- first wait for a key (D70, mod_panel_keys.lua); buttons as the open panel reads them (mod_panel_pad.lua). The row of
-- the controller's combination (mod_panel_combo_row.lua) says "Press two buttons" and takes the first two different
-- buttons of its list, together or one after the other, Circle included; it ends as a button row's wait does, 5 s after
-- the start or the first button, "Only one button pressed" said after one (D132).

local Keys = require("mod_panel_keys")
local Settings = require("mod_panel_settings")
local Values = require("mod_panel_values")
local ComboRow = require("mod_panel_combo_row")

local M = {}

local WAIT_SECONDS = 5
local NOTE_SECONDS = 3
local CIRCLE = "Gamepad_FaceButton_Right"
local NONE = {}

-- d: { catalog, changes (mod_panel_changes.lua), own (Mod Panel's folder name), pad_on() (whether the controller is
-- read in the panel), report(fmt, ...) (the panel's lines) }.
function M.new(d)
	-- wait: { name, key, kind ("key", "button" or "combo"), till, first (the combination's button taken first) } of
	-- the row waiting. note: what shows under a row's label,
	-- { name, key, word (mod_panel_words.lua), said (the key refused), used ({ entry, row } of the key row using it),
	-- till }.
	local C = { wait = nil, note = nil }

	-- What row waits for: "key", "button" or "combo" (only while the controller is read), or nil.
	function C.kind(row)
		if row == nil or row.key == nil then return nil end
		if row.key_row then return "key" end
		if not d.pad_on() then return nil end
		if row.type == "combo" then return "combo" end
		if row.button_row then return "button" end
		return nil
	end

	-- Cross, Enter or a click on row's value at now; whether a wait began.
	function C.start(entry, row, now)
		local kind = C.kind(row)
		if kind == nil or d.changes.locked(entry, row) ~= nil then return false end
		if kind == "key" then Keys.watch(d.report) end
		Keys.catch(kind == "key")
		C.wait, C.note = { name = entry.name, key = row.key, kind = kind, till = now + WAIT_SECONDS }, nil
		return true
	end

	local function finish(note)
		C.wait, C.note = nil, note
		Keys.catch(false)
	end

	-- At another mod, and at the panel's closing.
	function C.stop()
		if C.wait ~= nil then finish(nil) end
	end

	function C.waiting() return C.wait ~= nil end

	-- The mod and the row waiting, while both are still read; nil else.
	local function waited()
		local entry = d.catalog.get(C.wait.name)
		if entry ~= nil and C.wait.kind == "combo" then return entry, ComboRow.of(entry) end
		for _, row in ipairs(entry and entry.rows or NONE) do
			if row.key == C.wait.key then return entry, row end
		end
		return nil
	end

	local function refuse(word, now, said, used)
		local w = C.wait
		w.till = now + WAIT_SECONDS
		C.note = { name = w.name, key = w.key, word = word, said = said, used = used, till = math.huge }
	end

	-- Why the key called name cannot be row's: a word and the key row using it; nil when it can.
	local function refusal(entry, row, name)
		local own_key = entry.name == d.own and row.key == Settings.PANEL_KEY
		if not own_key and Values.option_index(row.options, name) == nil then return "key_list" end
		local used = d.changes.taken(entry, row)[name]
		if used == true then return "key_reserved" end
		if used then return "key_used", used end
		return nil
	end

	local function key_frame(entry, row, i, now)
		for _, b in ipairs(i.buttons or NONE) do
			if b == CIRCLE then return finish(nil) end
		end
		if i.moves > 0 then refuse("key_moves", now) end
		for _, name in ipairs(Keys.caught() or NONE) do
			local why, used = refusal(entry, row, name)
			if why == nil then
				d.changes.set(entry, row, name, now)
				return finish(nil)
			end
			refuse(why, now, name, used)
		end
	end

	local function button_frame(entry, row, i, now)
		for _, b in ipairs(i.buttons or NONE) do
			if Values.option_index(row.options, b) ~= nil then
				d.changes.set(entry, row, b, now)
				return finish(nil)
			end
			if b == CIRCLE then return finish(nil) end
			refuse("button_list", now)
		end
	end

	-- The combination: its first button taken, then a second, different one: both set, the order kept.
	local function combo_frame(entry, row, i, now)
		local w = C.wait
		for _, b in ipairs(i.buttons or NONE) do
			if not ComboRow.takes(row, b) then
				refuse("button_list", now)
			elseif w.first == nil then
				w.first, w.till, C.note = b, now + WAIT_SECONDS, nil
			elseif b ~= w.first then
				d.changes.set(entry, row.parts[1], w.first, now)
				d.changes.set(entry, row.parts[2], b, now)
				return finish(nil)
			end
		end
	end

	-- At each frame of the open panel while a wait runs. i: { moves, the keyboard's presses of the keys that move in
	-- the panel; escape, Escape's; buttons, the controller's pressed (nil: none); button, the panel's controller button
	-- pressed }; now: the clock.
	function C.frame(i, now)
		local w = C.wait
		if w == nil then return end
		local entry, row = waited()
		if entry == nil or row == nil or i.escape > 0 or i.button then return finish(nil) end
		if w.kind == "key" then
			key_frame(entry, row, i, now)
		elseif w.kind == "combo" then
			combo_frame(entry, row, i, now)
		else
			button_frame(entry, row, i, now)
		end
		if C.wait ~= nil and now > w.till then
			local word = w.kind == "key" and "no_key" or w.first ~= nil and "no_second" or "no_button"
			finish({ name = w.name, key = w.key, word = word, till = now + NOTE_SECONDS })
		end
	end

	-- What row of entry says while it waits: "press_key", "press_button" or "press_two"; nil when it does not wait.
	function C.shows(entry, row)
		local w = C.wait
		if w == nil or w.name ~= entry.name or w.key ~= row.key then return nil end
		return w.kind == "key" and "press_key" or w.kind == "combo" and "press_two" or "press_button"
	end

	-- The button a wait of row's combination took first, or nil.
	function C.first(entry, row)
		local w = C.wait
		if w == nil or w.first == nil or w.name ~= entry.name or w.key ~= row.key then return nil end
		return w.first
	end

	-- What shows under row's label at now, or nil.
	function C.note_of(entry, row, now)
		local n = C.note
		if n == nil or n.name ~= entry.name or n.key ~= row.key or now > n.till then return nil end
		return n
	end

	return C
end

return M
