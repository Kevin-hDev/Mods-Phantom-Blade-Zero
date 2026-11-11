-- What a command does to a row of the open panel; each change goes to mod_panel_edits.lua, which writes it. Left and
-- Right, or an arrow clicked: one step (Values.step), round a choice, stopping at the ends of a number or of a choice
-- shown as a bar. An arrow held with the mouse on a number steps again, faster as it stays held (1, then 2, then 5
-- steps; times in mod_panel_layout.lua); on the keyboard UE4SS sees the press only, so one press, one step. Enter, or a
-- click on the value: a switch turns over; an action is armed by a first press ("Press again", 3 s) and sent by a
-- second within 3 s (D32), then says "Sent" 3 s. A bar moved: the nearest value. R, or Restore defaults, and Undo:
-- mod_panel_restore.lua; a change here ends Undo. A read-only row takes nothing, nor a greyed row (D148), but Restore
-- defaults and Undo. On a section's title, Left folds, Right opens, Enter or a click does the other (D150). A key row
-- never takes a key another key row of a mod listed uses now, Mod Panel's own and the changes waiting included, nor a
-- reserved key (D64): one press would do two things. Its steps go past them, and Restore defaults leaves a key row
-- whose default is taken. Mod Panel's panel key and its controller's button are never both None (D71): a step of one
-- goes past None while the other is None. Their defaults are no None, so Restore defaults keeps that too. A key or a
-- button chosen by pressing it is set as a step is (mod_panel_capture.lua). On the row of the controller's combination,
-- a step sets both its settings to None (D132).

local Keys = require("mod_panel_key_names")
local L = require("mod_panel_layout")
local Settings = require("mod_panel_settings")
local Values = require("mod_panel_values")
local Restore = require("mod_panel_restore")
local PadNames = require("mod_panel_pad_names")
local Greyed = require("mod_panel_greyed")

local M = {}

local ACTION_SECONDS = 3          -- "Press again", then "Sent"
-- Mod Panel's two doors to its panel, each with the other (D71).
local DOORS = { [Settings.PANEL_KEY] = Settings.PAD_BUTTON, [Settings.PAD_BUTTON] = Settings.PANEL_KEY }

local function adjustable(row)
	return row ~= nil and row.key ~= nil and (row.type == "toggle" or row.type == "number" or row.type == "choice")
end

local function is(s, entry, row, now)
	return s ~= nil and s.name == entry.name and s.key == row.key and now <= s.till
end

-- d: { catalog, edits (mod_panel_edits.lua), own (Mod Panel's folder name), folds (mod_panel_folds.lua),
-- turned_on(name) told when a mod's Enabled switch is set on (mod_panel_all_mods.lua) }.
function M.new(d)
	-- armed, sent: { name, key, till } of the action pressed once, or sent. held: { row (its place), dir, since, next }
	-- of the arrow held with the mouse.
	local C = { armed = nil, sent = nil, held = nil }

	-- The row's value as the panel shows it: the change waiting to be written, else the file's.
	function C.value(entry, row)
		local v = d.edits.value(entry.name, row.key)
		if v == nil then v = d.catalog.value(entry, row) end
		return v
	end

	-- What row of entry waits for while greyed: the row to set first and the value it asks; nil when not greyed.
	function C.locked(entry, row)
		return Greyed.missing(entry, row, C.value)
	end

	-- Whether row of entry is a key row: a row of type key, or Mod Panel's own panel key.
	local function is_key(entry, row)
		return row.key_row == true or (entry.name == d.own and row.key == Settings.PANEL_KEY)
	end

	-- The keys row, a key row of entry, cannot take: true for a reserved one, { entry, row } of the other key row that
	-- uses it now for the others. None is never taken. Walked at a step or a key pressed in a wait, not at each frame.
	function C.taken(entry, row)
		local keys = {}
		for k in pairs(Keys.RESERVED) do keys[k] = true end
		for _, e in ipairs(d.catalog.list()) do
			for _, r in ipairs(e.rows) do
				if is_key(e, r) and not (e.name == entry.name and r.key == row.key) then
					local i = Values.option_index(r.options, C.value(e, r))
					if i ~= nil then keys[r.options[i].value] = { e, r } end
				end
			end
		end
		keys[Keys.NONE] = nil
		return keys
	end

	-- Every value the panel changes goes to edits here: a mod's Enabled switch set on is told to All mods (D163),
	-- Restore defaults and Undo included (audit of 0.7.0).
	local function set(name, row, v, now)
		d.edits.set(name, row, v, now)
		if v == true and row.key == "Enabled" and row.type == "toggle" then d.turned_on(name) end
	end

	local restore = Restore.new({ edits = d.edits, set = set, value = C.value, adjustable = adjustable,
		leaves = function(entry, row) return is_key(entry, row) and C.taken(entry, row)[row.default] ~= nil end })
	C.restore, C.label = restore.restore, restore.label

	-- Whether row is one of Mod Panel's doors while the other is None: then None would close both (D71).
	local function last_door(entry, row)
		local other = entry.name == d.own and DOORS[row.key] or nil
		if other == nil then return false end
		for _, r in ipairs(entry.rows) do
			if r.key == other then return C.value(entry, r) == Keys.NONE end
		end
		return false
	end

	-- One step of a key row: the next key that way not in keys, or nil when there is none.
	local function key_step(row, v, dir, wrap, keys)
		for _ = 1, #row.options do
			v = Values.step(row, v, dir, wrap)
			if not keys[v] then return v end
		end
		return nil
	end

	-- n steps of dir (-1 left, 1 right) on row; a step that changes nothing (an end) is no change.
	function C.step(entry, row, dir, n, now)
		if row ~= nil and row.type == "heading" then
			d.folds.set(entry, row, dir < 0)
			return
		end
		if row ~= nil and row.type == "combo" then
			for _, part in ipairs(row.parts) do C.set(entry, part, PadNames.NONE, now) end
			return
		end
		if not adjustable(row) or C.locked(entry, row) then return end
		local start = C.value(entry, row)
		if start == nil then start = row.default end
		local v = start
		local wrap = row.type == "choice" and not row.slider
		local keys = is_key(entry, row) and C.taken(entry, row) or nil
		if last_door(entry, row) then
			keys = keys or {}
			keys[Keys.NONE] = true
		end
		for _ = 1, n do
			if keys == nil then
				v = Values.step(row, v, dir, wrap)
			else
				v = key_step(row, v, dir, wrap, keys) or v
			end
		end
		if v == start then return end
		C.set(entry, row, v, now)
	end

	local function press(entry, row, now)
		if is(C.armed, entry, row, now) then
			C.armed = nil
			-- "Sent" only when the signal is written: one that waits or fails is not sent yet.
			if d.edits.action(entry.name, row.key, now) then
				C.sent = { name = entry.name, key = row.key, till = now + ACTION_SECONDS }
			end
		else
			C.armed = { name = entry.name, key = row.key, till = now + ACTION_SECONDS }
		end
	end

	-- n presses of Enter, or clicks on the value, on row.
	function C.enter(entry, row, n, now)
		if row == nil then return end
		for _ = 1, n do
			if row.type == "heading" then
				d.folds.toggle(entry, row)
			elseif row.type == "toggle" then
				C.step(entry, row, 1, 1, now)
			elseif row.type == "action" and row.key ~= nil and not C.locked(entry, row) then
				press(entry, row, now)
			end
		end
	end

	-- What an action row says now: "press_again" or "sent" (mod_panel_words.lua), nil for its own word.
	function C.word(entry, row, now)
		if is(C.armed, entry, row, now) then return "press_again" end
		if is(C.sent, entry, row, now) then return "sent" end
		return nil
	end

	-- row of entry set to v, written half a second after the last change (mod_panel_edits.lua); whether it changed.
	function C.set(entry, row, v, now)
		if v == C.value(entry, row) or C.locked(entry, row) then return false end
		set(entry.name, row, v, now)
		restore.forget()
		return true
	end

	-- A bar moved by the player to fraction (0 to 1); a greyed row refused by C.set.
	function C.bar(entry, row, fraction, now)
		if not adjustable(row) or not row.slider then return end
		C.set(entry, row, Values.at_fraction(row, fraction), now)
	end

	-- At each frame: dir, -1 or 1 while an arrow of row, the row under the pointer at place i, is pressed, else nil. A
	-- step at the press; on a number, more while it stays pressed.
	function C.hold(entry, row, i, dir, now)
		local h = C.held
		if dir == nil or row == nil then
			C.held = nil
			return
		end
		if h == nil or h.row ~= i or h.dir ~= dir then
			C.held = { row = i, dir = dir, since = now, next = now + L.HOLD_DELAY }
			return C.step(entry, row, dir, 1, now)
		end
		if row.type ~= "number" or now < h.next then return end
		local steps = 1
		for _, s in ipairs(L.HOLD_STEPS) do
			if now - h.since >= s[1] then steps = s[2] end
		end
		h.next = now + L.HOLD_EVERY
		C.step(entry, row, dir, steps, now)
	end

	-- The panel went to another mod, or closed: Undo, an armed action and a held arrow end there.
	function C.left()
		C.armed, C.held = nil, nil
		restore.forget()
	end

	return C
end

return M
