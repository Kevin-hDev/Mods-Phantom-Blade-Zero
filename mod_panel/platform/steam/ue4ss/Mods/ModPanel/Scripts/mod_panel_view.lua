-- Paints what the screen gives it on the frame and its reserve, only what changed (mod_panel_paint.lua). A row of the
-- reserve past the chosen mod's is hidden. The head of the list, the columns, Hide and Show are painted by
-- mod_panel_view_head.lua. Forms of Dynamic FOV 1.0.4's dynamic_fov_panel_view.lua.

local L = require("mod_panel_layout")
local Frame = require("mod_panel_frame")
local Pool = require("mod_panel_pool")
local Backdrop = require("mod_panel_backdrop")
local Hints = require("mod_panel_hints")
local P = require("mod_panel_paint")

local M = {}

local apply, text, visible, colour, on, icon = P.apply, P.text, P.visible, P.colour, P.on, P.icon

function M.refusals() return P.refusals() end

-- The texts of the frame: the heads of the list and of the settings, the descriptions, Close and its keys.
function M.texts(list_title, list_sub, title, sub, descriptions, close)
	local F = Frame.get()
	if F == nil then return end
	local sh = F.shown
	text(sh, F.list_title, list_title)
	text(sh, F.list_sub, list_sub)
	text(sh, F.title, title)
	text(sh, F.sub, sub)
	text(sh, F.descriptions, descriptions)
	text(sh, F.close_text, close)
end

-- Entry i of the list: its title, "Off" in the player's language for a mod turned off (nil else), whether it is the
-- chosen mod, and whether the pointer is on it.
function M.entry(i, title, off, chosen, hovered)
	local F, e = Frame.get(), Pool.entry(i)
	if F == nil or e == nil then return end
	local sh = F.shown
	visible(sh, e.size, L.SELF_HIT_TEST_INVISIBLE)
	text(sh, e.title, title)
	colour(sh, e.title, chosen and "DARK" or off and "GREY" or "WHITE")
	visible(sh, e.band, on(chosen or hovered, L.HIT_TEST_INVISIBLE))
	if chosen or hovered then apply(sh, e.band, "opacity", chosen and 1 or L.HOVER_OPACITY, P.set_opacity) end
	visible(sh, e.off, on(off ~= nil, L.HIT_TEST_INVISIBLE))
	if off ~= nil then
		text(sh, e.off, off)
		colour(sh, e.off, chosen and "DARK_GREY" or "GREY")
	end
end

-- Row i, by its look k (mod_panel_screen.lua): kind, label, value, number (the value in the number font), button (the
-- button whose icon is the value, else nil; value is its name, shown without the icon), bar and fraction, arrows, grey,
-- selected.
function M.row(i, k)
	local F, r = Frame.get(), Pool.row(i)
	if F == nil or r == nil then return end
	local sh = F.shown
	local title = k.kind == "heading"
	local dim = title or k.grey
	local tint = k.selected and (dim and "DARK_GREY" or "DARK") or (dim and "GREY" or "WHITE")
	visible(sh, r.size, L.SELF_HIT_TEST_INVISIBLE)
	text(sh, r.label, k.label)
	colour(sh, r.label, tint)
	apply(sh, r.frame, "brush", (title or not r.has_band) and "CLEAR" or "BAND", P.set_brush)
	visible(sh, r.band, on(k.selected, L.HIT_TEST_INVISIBLE))
	visible(sh, r.line, on(title, L.HIT_TEST_INVISIBLE))
	visible(sh, r.bar, on(k.bar, L.SELF_HIT_TEST_INVISIBLE))
	visible(sh, r.left, on(k.arrows, L.VISIBLE))
	visible(sh, r.right, on(k.arrows, L.VISIBLE))
	visible(sh, r.value, L.VISIBLE)
	apply(sh, r.value_box, "width", k.bar and L.VALUE_WIDTH or L.CHOICE_WIDTH, P.set_width)
	local pictured = k.button ~= nil and icon(sh, r.icon, k.button)
	visible(sh, r.icon_box, on(pictured, L.HIT_TEST_INVISIBLE))
	if pictured then apply(sh, r.icon, "colour", tint, P.set_tint) end
	local shows, hides = r.word, r.number
	if k.number then shows, hides = r.number, r.word end
	visible(sh, hides, L.COLLAPSED)
	visible(sh, shows, on(not pictured, L.HIT_TEST_INVISIBLE))
	text(sh, shows, k.value)
	colour(sh, shows, tint)
	if k.bar then apply(sh, r.slider, "value", k.fraction, P.set_value) end
end

-- The last hide_from: the frame, where the hidden rows and entries began, the reserve's counts and the game's refusals
-- then. Only M.row and M.entry show a piece of the reserve, and only before i and j.
local hidden = { frame = nil, i = 0, j = 0, rows = 0, entries = 0, refusals = 0 }

-- Hides the reserve's rows from i on, and its entries from j on. Not again while none of that changed: going over the
-- reserve at each frame to change nothing was a tenth of an open frame's Lua (audit of 0.4.3). A call the game refused
-- makes it go over again, so the refused piece is tried at the next frame.
function M.hide_from(i, j)
	local F = Frame.get()
	if F == nil then return end
	local rows, entries = Pool.counts()
	local h, refusals = hidden, P.refusals()
	if h.frame == F and h.i == i and h.j == j and h.rows == rows and h.entries == entries and h.refusals == refusals then
		return
	end
	for n = i, rows do visible(F.shown, Pool.row(n).size, L.COLLAPSED) end
	for n = j, entries do visible(F.shown, Pool.entry(n).size, L.COLLAPSED) end
	h.frame, h.i, h.j, h.rows, h.entries, h.refusals = F, i, j, rows, entries, refusals
end

-- The bar of row i is set again at the next paint: the player moved it, and it goes to the value that move gave, on
-- the row's step.
function M.bar_moved(i)
	local F, r = Frame.get(), Pool.row(i)
	local s = F and r and F.shown[r.slider]
	if s then s.value = nil end
end

-- Where the view put the bar of row i while that bar shows, else nil: what a move of the player is told from.
function M.bar_at(i)
	local F, r = Frame.get(), Pool.row(i)
	if F == nil or r == nil then return nil end
	local bar, slider = F.shown[r.bar], F.shown[r.slider]
	if bar == nil or bar.visibility ~= L.SELF_HIT_TEST_INVISIBLE or slider == nil then return nil end
	return slider.value
end

-- Whether the arrows of row i show: the pointer asks them only then.
function M.arrows_on(i)
	local F, r = Frame.get(), Pool.row(i)
	local s = F and r and F.shown[r.left]
	return s ~= nil and s.visibility == L.VISIBLE
end

function M.close_lit(on_close)
	local F = Frame.get()
	if F ~= nil then colour(F.shown, F.close_text, on_close and "WHITE" or "SOFT") end
end

-- The button under the rows: word, its text (nil: no button for this mod), lit under the pointer.
function M.restore(word, lit)
	local F = Frame.get()
	if F == nil then return end
	local sh = F.shown
	visible(sh, F.restore_button, on(word ~= nil, L.VISIBLE))
	if word == nil then return end
	text(sh, F.restore_text, word)
	colour(sh, F.restore_text, lit and "WHITE" or "SOFT")
end

-- The help under Close: the keyboard's line, the controller's in text, the word of each of its parts in icons (false:
-- left out), and the device whose help shows ("keys", "pad"). The icons are set at each paint, whichever help shows,
-- so they are in place from the hidden panel's first paint; the controller's help is in icons only when each one is.
function M.hints(keys, pad, words, device)
	local F = Frame.get()
	if F == nil then return end
	local sh = F.shown
	text(sh, F.hint_keys, keys)
	text(sh, F.hint_pad, pad)
	local all = true
	for i, part in ipairs(Hints.PAD) do
		local p = F.hint_parts[i]
		for j, name in ipairs(part[1]) do all = icon(sh, p.images[j], name) and all end
		visible(sh, p.segment, on(words[i] ~= false, L.HIT_TEST_INVISIBLE))
		if words[i] then text(sh, p.word, words[i]) end
	end
	visible(sh, F.hint_keys, on(device ~= "pad", L.HIT_TEST_INVISIBLE))
	visible(sh, F.hint_pad, on(device == "pad" and not all, L.HIT_TEST_INVISIBLE))
	visible(sh, F.hint_icons, on(device == "pad" and all, L.HIT_TEST_INVISIBLE))
end

-- Whether that button shows: the pointer asks it only then.
function M.restore_on()
	local F = Frame.get()
	local s = F and F.shown[F.restore_button]
	return s ~= nil and s.visibility == L.VISIBLE
end

-- The backdrop opacity % dark, set again only when it changes or the game refused a band.
function M.backdrop(opacity)
	local F = Frame.get()
	if F == nil or F.opacity == opacity then return end
	if Backdrop.paint(F.bands, opacity, F.max, P.tried) then F.opacity = opacity end
end

return M
