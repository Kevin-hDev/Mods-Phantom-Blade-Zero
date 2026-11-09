-- The mouse in the open panel: the row, the list entry and the head's item under it, a click on an entry, on a row's
-- value, on a head's value or box, on Restore defaults, Close, Hide or Show, an arrow held, a bar the player moved.
-- Each row and entry is asked itself whether the pointer is on it, as Dynamic FOV 1.0.4's rows are in play: 0.1.0 first
-- asked their box, and found nothing under the pointer in the game (D54). It asks the game only where it must: the item
-- found at the last read first, as the pointer stays on it from frame to frame; else the items the box shows and one on
-- each side; the list only when no row is under the pointer, the head only when no entry is, the buttons only when no
-- head's item is; a click, an arrow, only on what is under the pointer and shows; a bar only on the row under the
-- pointer, or while it moves. An arrow acts at its press, so that held it can go on (mod_panel_changes.lua); anything
-- else at its click. Which rows a box shows: mod_panel_scroll.lua. The wheel scrolls the box under the pointer by
-- itself (not verified in game). Clicks as in Dynamic FOV 1.0.4 (read of dynamic_fov_panel_view.lua). What is under the
-- pointer lights only while the mouse is in use (mod_panel_mouse.lua, D100).

local U = require("mod_panel_unreal")
local L = require("mod_panel_layout")
local Frame = require("mod_panel_frame")
local Pool = require("mod_panel_pool")
local View = require("mod_panel_view")
local ViewHead = require("mod_panel_view_head")
local Mouse = require("mod_panel_mouse")
local Scroll = require("mod_panel_scroll")

local M = {}

-- over: the row under the pointer; entry: the entry under it; pick: an entry clicked; arrow: -1 or 1 while the left
-- or right arrow of the row under the pointer is pressed; value: that row's value clicked; head: the frame's head item
-- under the pointer, head_arrow its arrow pressed (-1, 1), head_click its value or box clicked; close, restore, hide,
-- show: those buttons clicked; on_close, on_restore: the pointer on them; lit: "hide" or "show" under the pointer;
-- moved: a row whose bar the player moved, to fraction; mouse_moved: the mouse itself moved; band: the entry to light,
-- under the pointer while the mouse is in use; pressed: a button, an arrow or a bar under the pointer is held.
-- on_close, on_restore and lit stay off while the mouse is not in use. A table used again at each read.
local R = { over = nil, entry = nil, pick = nil, arrow = nil, value = false, head = nil, head_arrow = nil,
	head_click = false, close = false, on_close = false, restore = false, on_restore = false, hide = false,
	show = false, lit = nil, moved = nil, fraction = nil, mouse_moved = false, band = nil, pressed = false }
local held = nil                  -- the button seen pressed at the last read
local moving = nil                -- the row whose bar moved at the last read
local last = { row = nil, entry = nil, head = nil }   -- what was under the pointer at the last read
local CORNERS = { { "hide_button", "hide" }, { "show_button", "show" } }

-- Named functions for pcall.
local function hovered(w) return w:IsHovered() end
local function pressed(b) return b:IsPressed() end
local function value_of(slider) return slider:GetValue() end

local function is_hovered(w)
	local ok, h = pcall(hovered, w)
	return ok and h == true
end

local function hovers(widget, i)
	local w = widget(i)
	return w ~= nil and is_hovered(w)
end

-- The place of the item under the pointer among n items h high in box, or nil; widget(i) gives item i's widget that
-- the pointer hovers; before, the item under it at the last read: while the pointer stays there, no other is. No box:
-- all n items show (the head of the list).
local function under(box, n, h, widget, before)
	if n == 0 then return nil end
	if before ~= nil and before <= n and hovers(widget, before) then return before end
	local first, final = 1, n
	if box ~= nil then first, final = Scroll.shown(box, n, h) end
	for i = math.max(1, first - 1), math.min(n, final + 1) do
		if i ~= before and hovers(widget, i) then return i end
	end
	return nil
end

local function is_pressed(b)
	local ok, p = pcall(pressed, b)
	return ok and p == true
end

-- Whether b, under the pointer, was clicked: pressed at the last read, no longer now. A press taken off a button and
-- let go elsewhere is no click, as with the engine's own buttons.
local function clicked(b, before)
	if is_pressed(b) then
		held = b
		return false
	end
	return rawequal(before, b)
end

-- The value of the bar of row i when it stands more than half a step from where the view put it, else nil.
local function bar_moved(i)
	local at, r = View.bar_at(i), Pool.row(i)
	if at == nil or r == nil then return nil end
	local ok, v = pcall(value_of, r.slider)
	v = ok and U.num(v) or nil
	if v ~= nil and math.abs(v - at) > L.SLIDER_STEP / 2 then return v end
	return nil
end

-- What the pointer does on row i, under it: an arrow pressed, a click on the value.
local function on_row(i, before)
	local r = Pool.row(i)
	if r == nil then return end
	if View.arrows_on(i) then
		if is_pressed(r.left) then
			R.arrow = -1
		elseif is_pressed(r.right) then
			R.arrow = 1
		end
	end
	R.value = clicked(r.value, before)
end

-- Close, else Restore defaults while it shows, else Hide or Show, the one that shows, under the pointer when it is on
-- no row, entry nor head's item.
local function on_buttons(F, before)
	R.on_close = is_hovered(F.close_button)
	if R.on_close then
		R.close = clicked(F.close_button, before)
		return
	end
	if View.restore_on() then
		R.on_restore = is_hovered(F.restore_button)
		if R.on_restore then
			R.restore = clicked(F.restore_button, before)
			return
		end
	end
	for _, c in ipairs(CORNERS) do
		if ViewHead.button_on(c[1]) and is_hovered(F[c[1]]) then
			R.lit, R[c[2]] = c[2], clicked(F[c[1]], before)
			return
		end
	end
end

local function head_frame(i)
	local F = Frame.get()
	local h = F and F.head[i]
	return h and ViewHead.item_on(i) and h.frame or nil
end

-- What the pointer does on the head's item i: an arrow pressed, a click on the value or on the box.
local function on_head(F, i, before)
	local h = F.head[i]
	if h.check ~= nil then
		R.head_click = clicked(h.check, before)
		return
	end
	if is_pressed(h.left) then
		R.head_arrow = -1
	elseif is_pressed(h.right) then
		R.head_arrow = 1
	end
	R.head_click = clicked(h.value, before)
end

local function row_frame(i)
	local r = Pool.row(i)
	return r and r.frame
end

local function entry_button(i)
	local e = Pool.entry(i)
	return e and e.button
end

-- What the mouse did since the last read: rows, the number of rows the chosen mod shows; entries, the number listed;
-- keyed, a key or a button acted in this frame. The frame must be alive (Frame.alive(), asked first at each frame).
function M.read(rows, entries, keyed)
	R.over, R.entry, R.pick, R.arrow, R.value = nil, nil, nil, nil, false
	R.head, R.head_arrow, R.head_click, R.hide, R.show, R.lit = nil, nil, false, false, false, nil
	R.close, R.on_close, R.restore, R.on_restore, R.moved, R.fraction = false, false, false, false, nil, nil
	R.mouse_moved, R.band, R.pressed = false, nil, false
	local F = Frame.get()
	if F == nil then return R end
	local before = held
	held = nil
	R.over = under(F.rows, rows, L.ROW_HEIGHT, row_frame, last.row)
	if R.over == nil then R.entry = under(F.list, entries, L.ENTRY_HEIGHT, entry_button, last.entry) end
	if R.over == nil and R.entry == nil then R.head = under(nil, #F.head, 0, head_frame, last.head) end
	if R.over ~= nil then
		on_row(R.over, before)
	elseif R.entry ~= nil then
		if clicked(entry_button(R.entry), before) then R.pick = R.entry end
	elseif R.head ~= nil then
		on_head(F, R.head, before)
	else
		on_buttons(F, before)
	end
	last.row, last.entry, last.head = R.over, R.entry, R.head
	local bar = R.over or moving
	moving = nil
	local v = bar ~= nil and bar_moved(bar) or nil
	if v ~= nil then R.moved, R.fraction, moving = bar, v, bar end
	R.pressed = held ~= nil or R.arrow ~= nil or R.head_arrow ~= nil or R.moved ~= nil
	-- Last: Mouse.frame needs this frame's hover.
	R.mouse_moved = Mouse.frame(keyed)
	if Mouse.active() then
		R.band = R.entry
	else
		R.on_close, R.on_restore, R.lit = false, false, nil
	end
	return R
end

-- At each opening: a button pressed when the panel last closed, let go since, is no click. report(fmt, ...) hears
-- that the mouse's place cannot be read.
function M.reset(report)
	held, moving, last.row, last.entry, last.head = nil, nil, nil, nil, nil
	Mouse.start(report)
end

return M
