-- What the presses and the pointer do on the open panel: the keys' and the controller's moves, then the pointer's, then
-- the commands on the chosen row or head's item (mod_panel_head.lua). Taken out of mod_panel_panel.lua as it was in
-- 0.2.0; the controller's commands come as the keys'. X, Square, Hide and Show hide or show the descriptions (D91). F,
-- R3 and a click on a mod's diamond make it a favourite or undo it (D178). Right and Left on the chosen mod in
-- Classic's list turn it on and off, and so do its switch's arrows clicked; a click on its word turns it over (D183).
-- While a key or a button is awaited (mod_panel_capture.lua), the presses go to the wait, and only a click on another
-- mod, which ends it, acts (D83).

local View = require("mod_panel_view")
local FrameHead = require("mod_panel_frame_head")

local M = {}

-- The keyboard's commands that move or change in the panel: their keys are no keys to choose.
local MOVING = { "up", "down", "left", "right", "enter", "prev", "next", "restore", "descriptions", "favorite" }

-- d: nav (mod_panel_nav.lua), changes (mod_panel_changes.lua), capture (mod_panel_capture.lua), controls
-- (mod_panel_controls.lua), edits (mod_panel_edits.lua), catalog, head (mod_panel_head.lua), state
-- (mod_panel_state.lua), listing (mod_panel_listing.lua), favorites (mod_panel_favorites.lua), switches
-- (mod_panel_switches.lua), typing (mod_panel_typing.lua), classic() (whether the navigation is Classic now).
function M.new(d)
	local nav, changes, capture, controls, head = d.nav, d.changes, d.capture, d.controls, d.head
	-- over, over_head: the row and the frame's head item under the pointer at the last frame. stale: the mod changed
	-- while the mouse may hold something of the page before; the pointer's value, arrows, bar and Restore defaults
	-- then do nothing until nothing is pressed (D112). side: the controller's side held at the last frame, so that a
	-- mod's switch acts at its press only (audit of 1.0.3). input: what a wait is given at each frame, used again.
	local C = { over = nil, over_head = nil, stale = false, side = nil }
	local input = { moves = 0, escape = 0, buttons = nil, button = false }

	-- At each opening.
	function C.start()
		C.over, C.over_head, C.stale, C.side = nil, nil, false, nil
		d.listing.release()
	end

	-- The place among the head's items shown of the frame's head item j, or nil.
	local function item(j) return j and head.place(FrameHead.ITEMS[j]) end

	-- The mod called name made a favourite, or no longer one; the list sorted again keeps the chosen mod in view.
	local function favorite(name)
		if d.favorites.toggle(name) then nav.follow() end
	end

	-- Classic, the chosen mod's entry chosen in the list: Right and Left turn it on and off.
	local function on_entry() return d.classic() and nav.list and nav.head == nil end

	-- The moves of k, the presses; then the pointer's, a row or a head's item chosen only when the pointer comes onto
	-- it, so that a still pointer never takes back a move of the keys (D50). Only a move of the mouse brings it onto
	-- something: what scrolls or slides under a still pointer is not chosen (D100), and C.over and C.over_head keep
	-- what was under it at its last move. R: what the pointer did (mod_panel_pointer.lua), read on the page before when
	-- a key or a button changes the mod: it then chooses nothing.
	local function moves(k, R)
		local was = nav.mod
		if k ~= nil then
			if k.up > 0 then nav.move(-1, k.up) end
			if k.down > 0 then nav.move(1, k.down) end
			if k.prev > 0 then nav.switch(-1, k.prev) end
			if k.next > 0 then nav.switch(1, k.next) end
			if k.top > 0 then nav.edge(-1) end
			if k.bottom > 0 then nav.edge(1) end
		end
		if nav.mod ~= was then return end
		if R.pick ~= nil then nav.pick(R.pick) end
		if not R.mouse_moved then return end
		if R.pick == nil and R.over ~= C.over and R.over ~= nil then
			nav.hover(R.over)
		elseif R.pick == nil and R.head ~= C.over_head and R.head ~= nil then
			nav.hover_head(item(R.head))
		end
		C.over, C.over_head = R.over, R.head
	end

	-- The filter changed, at now: a chosen mod it no longer lists gives way (D94), its changes written at once, as when
	-- the player goes to another mod. The head's arrow held is kept: held on a box, it turns it only at its press.
	local function filtered(changed, now)
		if not changed then return end
		local was = nav.mod
		nav.refilter()
		if nav.mod ~= was then
			d.edits.flush(was, now)
			C.left()
		end
	end

	-- Enter, Cross or a click on row's value: a wait on a key or a button row, else what it does to the others.
	local function enter(entry, row, n, now)
		if not capture.start(entry, row, now) then changes.enter(entry, row, n, now) end
	end

	-- One arrow held at this frame at most: the pointer's on a row (page: read on this page) or on the head, else the
	-- controller's (side: -1 or 1 while it holds left or right, mod_panel_pad_commands.lua) on the chosen item or row.
	-- A mod's switch takes the side at its press only: held, it would turn off each mod Down passes, and the chosen
	-- mod again once Circle comes back to the list with Left still held (audit of 1.0.3).
	local function hold(entry, rows, R, now, side, page)
		local pressed = side ~= C.side and side or nil
		C.side = side
		local i = item(R.head)
		if R.arrow ~= nil and page then
			head.release()
			return changes.hold(entry, rows[R.over], R.over, R.arrow, now)
		end
		if R.head_arrow ~= nil and i ~= nil then return filtered(head.hold(i, R.head_arrow, now), now) end
		if side ~= nil and nav.head ~= nil then return filtered(head.hold(nav.head, side, now), now) end
		head.release()
		local f = nav.focus()
		if side ~= nil and entry ~= nil and f ~= nil then return changes.hold(entry, rows[f], f, side, now) end
		if pressed ~= nil and on_entry() then d.switches.set(nav.mod, pressed > 0, now) end
		changes.hold(nil, nil, nil, nil, now)
	end

	-- The keys and the controller on the chosen head's item or row; in Classic, Cross on the chosen mod's entry enters
	-- its page (mod_panel_nav.lua).
	local function keyed(k, entry, row, now)
		if nav.head ~= nil then
			if k.left > 0 then filtered(head.step(nav.head, -1, k.left, now), now) end
			if k.right > 0 then filtered(head.step(nav.head, 1, k.right, now), now) end
			if k.enter > 0 then
				filtered(head.enter(nav.head, k.enter, now), now)
			end
		elseif row ~= nil then
			if k.left > 0 then changes.step(entry, row, -1, k.left, now) end
			if k.right > 0 then changes.step(entry, row, 1, k.right, now) end
			if k.enter > 0 then
				enter(entry, row, k.enter, now)
			end
		else
			if k.left > 0 and on_entry() then d.switches.set(nav.mod, false, now) end
			if k.right > 0 and on_entry() then d.switches.set(nav.mod, true, now) end
			if k.enter > 0 then nav.enter() end
		end
	end

	-- The commands: the keys and the controller on the chosen item or row, the pointer on what is under it (which
	-- moves() made the chosen one), R and Restore defaults on the rows the page shows, the descriptions' switch. page:
	-- whether the pointer acts on this page (not C.stale); when not, its value, arrow, bar and Restore defaults do
	-- nothing.
	local function commands(k, R, now, side, page)
		local entry = nav.mod and d.catalog.get(nav.mod)
		local rows = entry and nav.rows() or {}
		local f = nav.focus()
		local row = f and rows[f] or nil
		local flips = (k and k.descriptions or 0) + ((R.hide or R.show) and 1 or 0)
		if flips % 2 == 1 then d.state.set("descriptions", not d.state.get("descriptions")) end
		-- The entries the pointer clicked, found before F sorts the list again under their places.
		local list = (R.fav or R.switch) and d.listing.list(nav.mod)
		local clicked, switched = R.fav and list[R.fav], R.switch and list[R.switch]
		if (k and k.favorite or 0) % 2 == 1 then favorite(nav.mod) end
		if clicked then favorite(clicked.name) end
		if switched then
			local yes = nil
			if R.flip ~= 0 then yes = R.flip > 0 end
			d.switches.set(switched.name, yes, now)
		end
		if k ~= nil then keyed(k, entry, row, now) end
		local i = item(R.head)
		if R.head_click and i ~= nil then filtered(head.enter(i, 1, now), now) end
		hold(entry, rows, R, now, side, page)
		-- A filter changed above may have chosen another mod: the rest acts on the mod chosen at its press only.
		if entry == nil or nav.mod ~= entry.name then return end
		local over = page and R.over and rows[R.over]
		if R.value and over then
			-- The row clicked is chosen first: a fold moves the rows under it, and the selection, left on another row,
			-- would land on a third one (audit of 0.7.0).
			nav.hover(R.over)
			enter(entry, over, 1, now)
		end
		if R.moved ~= nil then
			if page then changes.bar(entry, rows[R.moved], R.fraction, now) end
			View.bar_moved(R.moved)
		end
		for _ = 1, (k and k.restore or 0) + (R.restore and page and 1 or 0) do
			changes.restore(entry, d.all_rows_of(entry), now)
		end
	end

	-- A frame of a wait: k, the keys' presses; R, the pointer's. A click on another mod chooses it instead. A bar moved
	-- meanwhile goes back to its value, else the move would change it once the wait is over.
	local function wait(k, R, now)
		local was = nav.mod
		if R.pick ~= nil then nav.pick(R.pick, true) end
		if R.moved ~= nil then View.bar_moved(R.moved) end
		if R.mouse_moved then C.over, C.over_head = R.over, R.head end
		if nav.mod ~= was then return end
		local n = 0
		if k ~= nil then
			for _, name in ipairs(MOVING) do n = n + k[name] end
		end
		input.moves, input.escape = n, k and k.escape or 0
		input.buttons, input.button = controls.buttons(), controls.button()
		capture.frame(input, now)
	end

	-- At each frame of the open panel: k, the keys' presses (Keys.take()), and c, the controller's commands, each nil
	-- for none; R, what the pointer did; now, the clock. The changes of a mod left are written at once. Returns a
	-- reason to close the panel, or nil: Close clicked; Escape or Circle, but in a wait, which they end, and in a mod's
	-- page of the Classic navigation, where they come back to the list (D130).
	function C.frame(k, c, R, now)
		local was, waiting = nav.mod, capture.waiting()
		-- The search field types (D186): it takes the keys first, and its text may choose another mod.
		if not waiting then k, c = d.typing.frame(k, c, R, now) end
		local all = not waiting and controls.merge(k, c) or nil
		if waiting then wait(k, R, now) else moves(all, R) end
		if nav.mod ~= was then
			d.edits.flush(was, now)
			C.left()
		end
		if not waiting then commands(all, R, now, controls.side(), not C.stale) end
		-- Let go only now: a click let go in this frame was pressed on the page before (review of 0.4.4: a click let go
		-- frames after C, or an arrow held through it, still acted on the row at the same place of the new mod).
		if not R.pressed then C.stale = false end
		if R.close then return "Close" end
		if waiting then return nil end
		local why = k ~= nil and k.escape > 0 and "Escape" or c ~= nil and c.escape > 0 and "Circle" or nil
		if why == nil or not nav.back() then return why end
	end

	-- The panel went to another mod, or closed: Undo, an armed action, a row's held arrow and a wait end there, and the
	-- pointer's page goes stale. A box's arrow held is forgotten at the next opening (mod_panel_head.lua).
	function C.left()
		C.stale = true
		changes.left()
		capture.stop()
	end

	return C
end

return M
