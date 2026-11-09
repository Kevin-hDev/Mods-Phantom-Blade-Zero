-- Where the columns and the backdrop stand: the three columns, or, the descriptions hidden, the list and the settings
-- slid to the right edge and the backdrop narrowed behind them (D90). Only the places change, numbers handed to the
-- slots the frame kept (F.slots, and each band's): the shown panel takes no new piece. Hide, at the right end of the
-- descriptions' head, and Show, at the right end of the settings' head, are made here with the frame; the two stand
-- where the other was once the columns slid, so one place shows and hides.

local L = require("mod_panel_layout")
local Backdrop = require("mod_panel_backdrop")

local M = {}

local WIDE = { list = L.LIST, settings = L.SETTINGS, strip = L.STRIP }
local NARROW = { list = L.NARROW_LIST, settings = L.NARROW_SETTINGS, strip = L.NARROW_STRIP }

local function set_anchors(slot, x1, y1, x2, y2)
	slot:SetAnchors({ Minimum = { X = x1, Y = y1 }, Maximum = { X = x2, Y = y2 } })
end

-- Adds the steps that make a button at the right end of a column's head (x: its column's edges) over the head, each
-- making one object, by add(step): F[bar] the box placed (its slot in F.slots), F[button] the button, F[text] its text.
function M.add_corner(F, add, x, bar, button, text)
	add(function()
		F[bar] = F.B.new("HorizontalBox")
		F[bar]:SetVisibility(L.SELF_HIT_TEST_INVISIBLE)
		F.slots[bar] = F.B.place(F.canvas, F[bar], x[1], L.TOP, x[2], L.TOP + L.HEADER)
	end)
	add(function()
		local spacer = F.B.sized()
		spacer:SetVisibility(L.HIT_TEST_INVISIBLE)
		F[bar]:AddChildToHorizontalBox(spacer):SetSize(L.FILL_SIZE)
	end)
	add(function()
		F[button] = F.B.button()
		F[bar]:AddChildToHorizontalBox(F[button]):SetVerticalAlignment(L.START)
	end)
	add(function()
		F[text] = F.B.text("font_text", L.SMALL_SIZE, L.SOFT)
		F[button]:SetContent(F[text])
	end)
end

-- The list's and the settings' edges, and where the backdrop is full from, for shown (the descriptions shown or not).
function M.places(shown)
	return shown and WIDE or NARROW
end

-- Puts frame F's columns and backdrop where shown wants them; tried(ok) counts what the game refused. Returns whether
-- every slot took its place: one refused is set again at the next frame, with the others.
function M.apply(F, shown, tried)
	local p, all = M.places(shown), true
	local function place(slot, x, y1, y2)
		if not tried(pcall(set_anchors, slot, x[1], y1, x[2], y2)) then all = false end
	end
	local s, head, body = F.slots, L.TOP + L.HEADER, L.BOTTOM
	place(s.list_head, p.list, L.TOP, head)
	place(s.list_body, p.list, head, body)
	place(s.settings_head, p.settings, L.TOP, head)
	place(s.settings_bar, p.settings, L.TOP, head)
	place(s.settings_body, p.settings, head, body)
	for i, band in ipairs(F.bands) do
		local x1, x2 = Backdrop.span(i, F.max, p.strip)
		place(band.slot, { x1, x2 }, 0, 1)
	end
	return all
end

return M
