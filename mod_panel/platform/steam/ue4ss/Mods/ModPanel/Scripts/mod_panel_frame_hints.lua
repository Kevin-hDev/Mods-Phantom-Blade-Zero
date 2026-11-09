-- The help's pieces at the foot of the settings column (mod_panel_hints.lua), made with the frame, hidden: two lines
-- high whatever shows, so the rows above never move. The keyboard's line and the controller's in text, each wrapping by
-- itself, and the controller's in icons: for each part of Hints.PAD its buttons' icons then its word, the gaps in the
-- words' own text, as in the text lines, rather than in a slot's padding, a function more to check.

local L = require("mod_panel_layout")
local Hints = require("mod_panel_hints")

local M = {}

-- Adds the steps that make the help of frame F, each making one object, by add(step).
function M.add(F, add)
	local box
	add(function()
		box = F.B.sized(nil, L.HINTS_HEIGHT)
		F.settings_body:AddChildToVerticalBox(box):SetPadding(L.HINTS_PADDING)
	end)
	add(function()
		F.hints = F.B.new("VerticalBox")
		box:SetContent(F.hints)
	end)
	for _, name in ipairs({ "hint_keys", "hint_pad" }) do
		add(function()
			F[name] = F.B.text("font_text", L.SMALL_SIZE, L.SOFT)
			F[name]:SetAutoWrapText(true)
			F[name]:SetVisibility(L.COLLAPSED)
			F.hints:AddChildToVerticalBox(F[name])
		end)
	end
	add(function()
		F.hint_icons, F.hint_parts = F.B.new("HorizontalBox"), {}
		F.hint_icons:SetVisibility(L.COLLAPSED)
		F.hints:AddChildToVerticalBox(F.hint_icons)
	end)
	-- F.hint_parts[i]: { segment, images, word } of part i.
	for i, part in ipairs(Hints.PAD) do
		local p = { images = {} }
		add(function()
			p.segment = F.B.new("HorizontalBox")
			F.hint_icons:AddChildToHorizontalBox(p.segment)
			F.hint_parts[i] = p
		end)
		for j = 1, #part[1] do
			local size
			add(function()
				size = F.B.sized(L.HINT_ICON_SIZE, L.HINT_ICON_SIZE)
				p.segment:AddChildToHorizontalBox(size):SetVerticalAlignment(L.CENTRE)
			end)
			add(function()
				p.images[j] = F.B.new("Image")
				p.images[j]:SetColorAndOpacity(L.SOFT)
				size:SetContent(p.images[j])
			end)
		end
		add(function()
			p.word = F.B.text("font_text", L.SMALL_SIZE, L.SOFT)
			p.segment:AddChildToHorizontalBox(p.word):SetVerticalAlignment(L.CENTRE)
		end)
	end
end

return M
