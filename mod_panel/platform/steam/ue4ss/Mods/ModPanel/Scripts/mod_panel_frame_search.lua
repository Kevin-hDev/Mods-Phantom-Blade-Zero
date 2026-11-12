-- The search field's pieces (D186), made with the frame, right of the list's title on its line: a box taking the room
-- the title leaves, its foot on the title's. In it, the field, a button holding the magnifier and the text, and the
-- cross, a button of its own beside it, so that a click on it is not the field's; then the line under both. The
-- drawings start collapsed: the view shows each once its image holds it (mod_panel_view_head.lua).

local L = require("mod_panel_layout")
local Make = require("mod_panel_make")

local M = {}

-- Adds the steps that make the search field of frame F, each making one object, by add(step); line() gives the
-- title's line, made by an earlier step.
function M.add(F, add, line)
	local box, row, inner, size
	add(function()
		box = F.B.new("VerticalBox")
		local slot = line():AddChildToHorizontalBox(box)
		slot:SetSize(L.FILL_SIZE)
		slot:SetVerticalAlignment(L.END)
		slot:SetPadding(L.SEARCH_PADDING)
	end)
	add(function() row = F.B.new("HorizontalBox"); box:AddChildToVerticalBox(row) end)
	add(function()
		F.search_button = F.B.button()
		local slot = row:AddChildToHorizontalBox(F.search_button)
		slot:SetSize(L.FILL_SIZE)
		slot:SetVerticalAlignment(L.CENTRE)
	end)
	add(function() inner = F.B.new("HorizontalBox"); Make.fill(F.search_button:SetContent(inner), L.NO_PADDING) end)
	add(function()
		F.search_icon_box = F.B.sized(L.SEARCH_ICON_SIZE, L.SEARCH_ICON_SIZE)
		local slot = inner:AddChildToHorizontalBox(F.search_icon_box)
		slot:SetVerticalAlignment(L.CENTRE)
		slot:SetPadding(L.SEARCH_ICON_PADDING)
	end)
	add(function()
		F.search_icon = F.B.new("Image")
		F.search_icon:SetVisibility(L.COLLAPSED)
		F.search_icon_box:SetContent(F.search_icon)
	end)
	add(function()
		F.search_text = F.B.text("font_text", L.SMALL_SIZE, L.SOFT, true)
		local slot = inner:AddChildToHorizontalBox(F.search_text)
		slot:SetSize(L.FILL_SIZE)
		slot:SetVerticalAlignment(L.CENTRE)
	end)
	add(function()
		F.clear_button = F.B.button()
		F.clear_button:SetVisibility(L.COLLAPSED)
		row:AddChildToHorizontalBox(F.clear_button):SetVerticalAlignment(L.CENTRE)
	end)
	add(function()
		F.clear_box = F.B.sized(L.CLEAR_SIZE, L.CLEAR_SIZE)
		Make.fill(F.clear_button:SetContent(F.clear_box), L.NO_PADDING)
	end)
	add(function() F.clear_icon = F.B.new("Image"); F.clear_box:SetContent(F.clear_icon) end)
	add(function()
		size = F.B.sized(nil, L.SEARCH_LINE_HEIGHT)
		box:AddChildToVerticalBox(size):SetPadding(L.SEARCH_LINE_PADDING)
	end)
	add(function()
		F.search_line = F.B.new("Border")
		F.search_line:SetBrushColor(L.SEARCH_DIM)
		size:SetContent(F.search_line)
	end)
end

return M
