-- Makes the panel's pieces: texts in the menu's fonts, images, the menu's slider, invisible buttons around a text or an
-- arrow, rows and group titles, from the game's pieces when found (dynamic_fov_panel_pieces.lua). PanelProbe pass 7,
-- verified in game, plus the buttons and the centred values. Everything a piece shows (texture, font, style, a
-- controller's icon) is handed to it here, at the build, and held by it from then on: after the build the panel hands
-- the game no object (crashes of PanelProbe passes 4 and 5, 4 November 2026).

local PanelCalls = require("dynamic_fov_panel_calls")

local M = {}

M.VISIBLE, M.COLLAPSED, M.HIT_TEST_INVISIBLE, M.SELF_HIT_TEST_INVISIBLE = 0, 1, 3, 4
M.LEFT = 0.62                     -- the strip is full from 62% of the screen's width
M.FILL, M.CENTRE, M.RIGHT, M.BOTTOM = 0, 2, 3, 3   -- EHorizontalAlignment and EVerticalAlignment
M.FILL_SIZE = { SizeRule = 1, Value = 1.0 }        -- a box's child that takes the room left
-- Rows 44 high since the backdrop's row (1.0.3; 52, then 46 with the Image rows); the group titles too since 1.0.5,
-- so the place of each line in the box that scrolls is known (dynamic_fov_panel_view.lua).
M.ROW_HEIGHT = 44
local SLIDER_WIDTH, VALUE_WIDTH, CHOICE_WIDTH, ARROW_SIZE, TEXT_SIZE = 190, 56, 150, 24, 18
local ICON_SIZE, ICON_GAP = 26, 8
local LINE_WIDTH = 560
-- Interface colours are linear, not sRGB. The menu's row text is white, dark on the selected band (pass 2).
M.WHITE = { R = 1, G = 1, B = 1, A = 1 }
M.DARK = { R = 0.0212, G = 0.0212, B = 0.0212, A = 1 }
M.GREY = { R = 1, G = 1, B = 1, A = 0.4 }
M.DARK_GREY = { R = 0.0212, G = 0.0212, B = 0.0212, A = 0.45 }
M.SOFT = { R = 1, G = 1, B = 1, A = 0.65 }
local NONE = { R = 0, G = 0, B = 0, A = 0 }
local LIGHT = { R = 0.8, G = 0.8, B = 0.8, A = 0.9 }   -- the selected band when the menu's is not found
local NO_PADDING = { Left = 0, Top = 0, Right = 0, Bottom = 0 }
local ROW_PADDING = { Left = 24, Top = 0, Right = 24, Bottom = 0 }

function M.paint(tb, colour)
	tb:SetColorAndOpacity({ SpecifiedColor = colour, ColorUseRule = 0 })
end

-- The engine's widget class by its name ("TextBlock"); throws when it is not found, as every build step may.
function M.class(name)
	local c = StaticFindObject(PanelCalls.UMG .. name)
	assert(c ~= nil and c:IsValid(), "no widget class " .. name)
	return c
end

-- A builder for one panel. tree: the panel's widget tree, which holds every widget made here; got: the game's pieces
-- found for this build. Every call may throw: the build runs inside a pcall.
function M.builder(tree, got)
	local B, classes = {}, {}

	function B.new(class)
		local c = classes[class]
		if c == nil then
			c = M.class(class)
			classes[class] = c
		end
		return StaticConstructObject(c, tree)
	end

	local function font(key, size)
		local f = { Size = size, TypefaceFontName = FName("Default"), LetterSpacing = 0 }
		if got[key] then f.FontObject = got[key] end
		return f
	end

	function B.text(s, key, size, colour)
		local tb = B.new("TextBlock")
		tb:SetFont(font(key, size))
		tb:SetText(FText(s))
		M.paint(tb, colour)
		return tb
	end

	function B.place(canvas, widget, x1, y1, x2, y2)
		local slot = canvas:AddChildToCanvas(widget)
		slot:SetAnchors({ Minimum = { X = x1, Y = y1 }, Maximum = { X = x2, Y = y2 } })
		slot:SetOffsets(NO_PADDING)
		return slot
	end

	function B.sized(piece, w, h)
		local size = B.new("SizeBox")
		if w then size:SetWidthOverride(w) end
		if h then size:SetHeightOverride(h) end
		size:SetContent(piece)
		return size
	end

	function B.image(key, w, h)
		local img = B.new("Image")
		if key and got[key] then img:SetBrushFromTexture(got[key], false) end
		return B.sized(img, w, h), img
	end

	-- piece in the middle of a box w wide, so the arrows around a value stay in place whatever its length.
	function B.centred(piece, w)
		local overlay = B.new("Overlay")
		local slot = overlay:AddChildToOverlay(piece)
		slot:SetHorizontalAlignment(M.CENTRE)
		slot:SetVerticalAlignment(M.CENTRE)
		return B.sized(overlay, w)
	end

	-- A button whose own look is invisible: only piece shows. A click is read from IsPressed (the panel's view).
	function B.button(piece)
		local b = B.new("Button")
		b:SetBackgroundColor(NONE)
		b:SetContent(piece)
		return b
	end

	-- A text that is a button: { button, text }.
	function B.text_button(size, colour)
		local t = B.text("", "font_text", size, colour)
		return { button = B.button(t), text = t }
	end

	-- A text button with an icon before its text for each brand of controller (1.0.5): { button, text,
	-- icons[brand] }. textures[brand]: the icon's texture, or nil when the game does not hold it, and then no icon is
	-- made for that brand. The icons are hidden; the view shows one or none (dynamic_fov_panel_view.lua).
	function B.icon_button(size, colour, brands, textures)
		local h = B.new("HorizontalBox")
		local icons = {}
		for _, brand in ipairs(brands) do
			if textures[brand] ~= nil then
				local size_box, img = B.image(nil, ICON_SIZE, ICON_SIZE)
				img:SetBrushFromTexture(textures[brand], false)
				size_box:SetVisibility(M.COLLAPSED)
				local slot = h:AddChildToHorizontalBox(size_box)
				slot:SetVerticalAlignment(M.CENTRE)
				slot:SetPadding({ Left = 0, Top = 0, Right = ICON_GAP, Bottom = 0 })
				icons[brand] = size_box
			end
		end
		local t = B.text("", "font_text", size, colour)
		h:AddChildToHorizontalBox(t):SetVerticalAlignment(M.CENTRE)
		return { button = B.button(h), text = t, icons = icons }
	end

	function B.line()
		return (B.image("line", LINE_WIDTH, 2))
	end

	-- The menu's arrow, pointing left or right; a plain one when the menu's is not found. The menu's points right (seen
	-- in game on 4 November 2026: mirrored for the right arrow, both pointed inwards), so the left one is mirrored.
	local function arrow(left)
		if not got.arrow then return B.text(left and "<" or ">", "font_text", TEXT_SIZE, M.WHITE) end
		local size, img = B.image("arrow", ARROW_SIZE, ARROW_SIZE)
		if left then img:SetRenderScale({ X = -1, Y = 1 }) end
		return size
	end

	local function fill(slot, padding)
		slot:SetHorizontalAlignment(M.FILL)
		slot:SetVerticalAlignment(M.FILL)
		if padding then slot:SetPadding(padding) end
	end

	-- The selected-row band, laid over the row's own band; the view shows it only under the pointer, from its first
	-- paint, done in the frame that shows the panel. Held by the row from the build on: passes 4 and 5 gave the band a
	-- texture kept only in Lua on hover, the engine freed it, and the game crashed on the freed texture (4 November
	-- 2026, memory dumps).
	local function band(overlay)
		local b
		if got.row and got.selected_bar then
			b = B.new("Image")
			b:SetBrush(got.row.Background)
			b:SetBrushFromTexture(got.selected_bar, false)
		else
			b = B.new("Border")
			b:SetBrushColor(LIGHT)
		end
		fill(overlay:AddChildToOverlay(b))
		return b
	end

	-- A row of the panel: its label, then a slider and its value (a number), or the value between two arrows (the
	-- switch, the choices). Returns its pieces.
	function B.row(box, line)
		local frame = B.new("Border")
		if got.row then frame:SetBrush(got.row.Background) else frame:SetBrushColor(NONE) end
		frame:SetPadding(NO_PADDING)
		local overlay = B.new("Overlay")
		frame:SetContent(overlay)
		local r = { frame = frame, band = band(overlay), half = line.step and line.step / 2 }
		local h = B.new("HorizontalBox")
		fill(overlay:AddChildToOverlay(h), ROW_PADDING)
		r.label = B.text("", "font_text", TEXT_SIZE, M.WHITE)
		local label_slot = h:AddChildToHorizontalBox(r.label)
		label_slot:SetSize(M.FILL_SIZE)
		label_slot:SetVerticalAlignment(M.CENTRE)
		if line.kind == "number" then
			r.slider = B.new("Slider")
			if got.slider then r.slider.WidgetStyle = got.slider.WidgetStyle end
			r.slider:SetMinValue(line.min)
			r.slider:SetMaxValue(line.max)
			r.slider:SetStepSize(line.step)
			h:AddChildToHorizontalBox(B.sized(r.slider, SLIDER_WIDTH)):SetVerticalAlignment(M.CENTRE)
			r.value = B.text("", "font_number", TEXT_SIZE, M.WHITE)
			h:AddChildToHorizontalBox(B.sized(r.value, VALUE_WIDTH)):SetVerticalAlignment(M.CENTRE)
		else
			r.left = B.button(arrow(true))
			h:AddChildToHorizontalBox(r.left):SetVerticalAlignment(M.CENTRE)
			r.value = B.text("", "font_text", TEXT_SIZE, M.WHITE)
			h:AddChildToHorizontalBox(B.centred(r.value, CHOICE_WIDTH)):SetVerticalAlignment(M.CENTRE)
			r.right = B.button(arrow(false))
			h:AddChildToHorizontalBox(r.right):SetVerticalAlignment(M.CENTRE)
		end
		box:AddChildToVerticalBox(B.sized(frame, nil, M.ROW_HEIGHT))
		frame:SetVisibility(M.VISIBLE)
		return r
	end

	-- A group title and its line at the bottom of a row's height, the line just above the group's first row as before
	-- 1.0.5; returns the title's text.
	function B.heading(box)
		local inner = B.new("VerticalBox")
		local title = B.text("", "font_text", TEXT_SIZE, M.GREY)
		inner:AddChildToVerticalBox(title):SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 4 })
		inner:AddChildToVerticalBox(B.line())
		local overlay = B.new("Overlay")
		local slot = overlay:AddChildToOverlay(inner)
		slot:SetHorizontalAlignment(M.FILL)
		slot:SetVerticalAlignment(M.BOTTOM)
		box:AddChildToVerticalBox(B.sized(overlay, nil, M.ROW_HEIGHT))
		return title
	end

	return B
end

return M
