-- Paints the head of the list (mod_panel_head.lua), the phrase of an empty list, where the columns stand
-- (mod_panel_columns.lua, D90), Hide and Show, only what changed (mod_panel_paint.lua). A box shows checked by the mark
-- inside its pale square, so by a shape and not by a colour alone (D92).

local L = require("mod_panel_layout")
local Frame = require("mod_panel_frame")
local Columns = require("mod_panel_columns")
local P = require("mod_panel_paint")

local M = {}

local apply, text, visible, colour, on = P.apply, P.text, P.visible, P.colour, P.on

-- Item i of the frame's head by its look k (Head.look: shown, label, box, checked, value); selected: the chosen one.
function M.item(i, k, selected)
	local F = Frame.get()
	local h = F and F.head[i]
	if h == nil then return end
	local sh = F.shown
	visible(sh, h.size, on(k.shown, L.SELF_HIT_TEST_INVISIBLE))
	if not k.shown then return end
	local tint = selected and "DARK" or "WHITE"
	text(sh, h.label, k.label)
	colour(sh, h.label, tint)
	visible(sh, h.band, on(selected, L.HIT_TEST_INVISIBLE))
	if k.box then
		apply(sh, h.edge, "brush", selected and "CHECK_EDGE_DARK" or "CHECK_EDGE", P.set_brush)
		apply(sh, h.mark, "brush", k.checked and tint or "CLEAR", P.set_brush)
	else
		text(sh, h.word, k.value)
		colour(sh, h.word, tint)
	end
end

-- The language's On and Off, hidden in each item's value: its room (D183).
function M.words(on_word, off_word)
	local F = Frame.get()
	if F == nil then return end
	for _, h in ipairs(F.head) do
		if h.room_on ~= nil then
			text(F.shown, h.room_on, on_word)
			text(F.shown, h.room_off, off_word)
		end
	end
end

-- Whether the head's item i shows: the pointer asks only those.
function M.item_on(i)
	local F = Frame.get()
	local h = F and F.head[i]
	local s = h and F.shown[h.size]
	return s ~= nil and s.visibility ~= L.COLLAPSED
end

-- The phrase of an empty list, shown while no mod is listed.
function M.empty(phrase, shown)
	local F = Frame.get()
	if F == nil then return end
	visible(F.shown, F.empty_box, on(shown, L.HIT_TEST_INVISIBLE))
	if shown then text(F.shown, F.empty, phrase) end
end

-- The descriptions shown or hidden: the columns where that wants them, the descriptions' column, Hide and Show with
-- their words, the one under the pointer lit (lit: "hide", "show" or nil). Places the game refused are set again at the
-- next frame.
function M.columns(shown, hide, show, lit)
	local F = Frame.get()
	if F == nil then return end
	local sh = F.shown
	if F.columns ~= shown and Columns.apply(F, shown, P.tried) then F.columns = shown end
	visible(sh, F.descriptions_body, on(shown, L.SELF_HIT_TEST_INVISIBLE))
	visible(sh, F.descriptions_bar, on(shown, L.SELF_HIT_TEST_INVISIBLE))
	visible(sh, F.hide_button, on(shown, L.VISIBLE))
	visible(sh, F.show_button, on(not shown, L.VISIBLE))
	text(sh, F.hide_text, hide)
	text(sh, F.show_text, show)
	colour(sh, F.hide_text, lit == "hide" and "WHITE" or "SOFT")
	colour(sh, F.show_text, lit == "show" and "WHITE" or "SOFT")
end

-- Whether the frame's button called name ("hide_button", "show_button") shows: the pointer asks it only then.
function M.button_on(name)
	local F = Frame.get()
	local s = F and F.shown[F[name]]
	return s ~= nil and s.visibility == L.VISIBLE
end

return M
