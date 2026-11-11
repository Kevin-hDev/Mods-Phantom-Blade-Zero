-- The head of the list's pieces, made with the frame, hidden, in the list's body before its line: All mods, Freeze game
-- and Background as a row of the settings is (a name, an arrow, a value, an arrow), then Enabled and Disabled (a name
-- and a box drawn by two borders, D92), each as high as a mod of the list. Then, first in the list's box, the phrase of
-- an empty list. F.head[i] is item i of ITEMS: { size, frame, band, label } and either { left, right, value, word,
-- room_on, room_off } or { check, edge, mark }.

local L = require("mod_panel_layout")
local Make = require("mod_panel_make")

local M = {}

M.ITEMS = { "all", "freeze", "background", "enabled", "disabled" }
M.BOXES = { enabled = true, disabled = true }

local function beside(h, w)
	h:AddChildToHorizontalBox(w):SetVerticalAlignment(L.CENTRE)
end

-- A word of the language kept hidden in an item's value, so that the value is as wide as it (L.HIDDEN).
local function room(F, h, key, add)
	add(function()
		h[key] = F.B.text("font_text", L.TEXT_SIZE, L.WHITE)
		h[key]:SetVisibility(L.HIDDEN)
		Make.centre(h.value_overlay:AddChildToOverlay(h[key]))
	end)
end

-- The steps of an item's value between its arrows, on h: HEAD_VALUE_WIDTH wide at least, and as wide as the
-- language's On and Off, on every item, so that the arrows stand in line (D183).
local function arrows(F, h, add)
	add(function() h.left = F.B.button(); beside(h.h, h.left) end)
	add(function() h.left_box = F.B.sized(L.ARROW_SIZE, L.ARROW_SIZE); h.left:SetContent(h.left_box) end)
	add(function() h.left_box:SetContent(F.B.arrow(true)) end)
	add(function() h.value = F.B.button(); beside(h.h, h.value) end)
	add(function() h.value_box = F.B.sized(); h.value:SetContent(h.value_box) end)
	add(function() h.value_overlay = F.B.new("Overlay"); h.value_box:SetContent(h.value_overlay) end)
	add(function() h.least = F.B.sized(L.HEAD_VALUE_WIDTH); h.value_overlay:AddChildToOverlay(h.least) end)
	room(F, h, "room_on", add)
	room(F, h, "room_off", add)
	add(function()
		h.word = F.B.text("font_text", L.TEXT_SIZE, L.WHITE)
		Make.centre(h.value_overlay:AddChildToOverlay(h.word))
	end)
	add(function() h.right = F.B.button(); beside(h.h, h.right) end)
	add(function() h.right_box = F.B.sized(L.ARROW_SIZE, L.ARROW_SIZE); h.right:SetContent(h.right_box) end)
	add(function() h.right_box:SetContent(F.B.arrow(false)) end)
end

-- The steps of an item's box, on h: a button for its click, the pale square, the mark inside it.
local function box(F, h, add)
	add(function() h.check = F.B.button(); beside(h.h, h.check) end)
	add(function() h.check_size = F.B.sized(L.CHECK_SIZE, L.CHECK_SIZE); h.check:SetContent(h.check_size) end)
	add(function()
		h.edge = F.B.new("Border")
		h.edge:SetBrushColor(L.CHECK_EDGE)
		h.edge:SetPadding(L.CHECK_INSET)
		h.check_size:SetContent(h.edge)
	end)
	add(function()
		h.mark = F.B.new("Border")
		h.mark:SetBrushColor(L.CLEAR)
		h.edge:SetContent(h.mark)
	end)
end

-- Adds the steps that make the head of frame F in its list's body, each making one object, by add(step).
function M.add(F, add)
	F.head = {}
	for i, name in ipairs(M.ITEMS) do
		local h = { name = name }
		add(function()
			h.size = F.B.sized(nil, L.ENTRY_HEIGHT)
			F.list_body:AddChildToVerticalBox(h.size)
			F.head[i] = h
		end)
		-- Hit by the pointer, for the item under it (IsHovered), as a row's frame is.
		add(function() h.frame = F.B.row_frame(); h.frame:SetVisibility(L.VISIBLE); h.size:SetContent(h.frame) end)
		add(function() h.overlay = F.B.new("Overlay"); h.frame:SetContent(h.overlay) end)
		add(function()
			h.band = F.B.band()
			h.band:SetVisibility(L.COLLAPSED)
			Make.fill(h.overlay:AddChildToOverlay(h.band))
		end)
		add(function() h.h = F.B.new("HorizontalBox"); Make.fill(h.overlay:AddChildToOverlay(h.h), L.ENTRY_PADDING) end)
		add(function()
			h.label = F.B.text("font_text", L.TEXT_SIZE, L.WHITE, true)
			local slot = h.h:AddChildToHorizontalBox(h.label)
			slot:SetSize(L.FILL_SIZE)
			slot:SetVerticalAlignment(L.CENTRE)
			slot:SetPadding(L.LABEL_PADDING)
		end)
		if M.BOXES[name] then box(F, h, add) else arrows(F, h, add) end
	end
end

-- Adds the steps that make the phrase of an empty list, first in frame F's list box, collapsed, its margins those of a
-- mod's title.
function M.add_phrase(F, add)
	add(function()
		F.empty_box = F.B.new("Border")
		F.empty_box:SetBrushColor(L.CLEAR)
		F.empty_box:SetPadding(L.EMPTY_PADDING)
		F.empty_box:SetVisibility(L.COLLAPSED)
		F.list:AddChild(F.empty_box)
	end)
	add(function()
		F.empty = F.B.text("font_text", L.SMALL_SIZE, L.SOFT)
		F.empty:SetAutoWrapText(true)
		F.empty_box:SetContent(F.empty)
	end)
end

return M
