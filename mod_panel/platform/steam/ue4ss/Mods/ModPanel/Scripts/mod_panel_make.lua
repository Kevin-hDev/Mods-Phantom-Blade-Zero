-- Makes the panel's pieces, one engine object at each call, so that a build cut in slices looks at the clock after each
-- one (D38): texts in the menu's fonts, images, the menu's slider, invisible buttons, bands, boxes. Each takes from the
-- game's pieces in memory what it shows (a texture, a font, a style) when it is made (mod_panel_pieces.lua), and holds
-- it from then on: after its build, a piece is handed no object (crashes of PanelProbe passes 4 and 5, 4 November
-- 2026). Taken from Dynamic FOV 1.0.4 (dynamic_fov_panel_make.lua, PanelProbe pass 7, verified in game).

local Calls = require("mod_panel_calls")
local Pieces = require("mod_panel_pieces")
local L = require("mod_panel_layout")

local M = {}

-- The texts made in the text font, each { size, from, want, font }: the language its words were borrowed from (nil:
-- the panel's, D159), the text font its language wants and the one it has (mod_panel_pieces.lua's text_font keys);
-- they differ while the wanted font is not in memory. The font changes with the language (D154). Made again with each
-- frame (M.builder): after a load, the texts of the frame the game freed must not be touched, and UE4SS's IsValid may
-- answer true for another object at a freed address (D103).
local TEXTS = setmetatable({}, { __mode = "k" })
local S = { lacking = false }      -- lacking: a text has the menu's font in place of its own

function M.paint(tb, colour)
	tb:SetColorAndOpacity({ SpecifiedColor = colour, ColorUseRule = 0 })
end

-- The engine's widget class by its name ("TextBlock"); throws when it is not found, as every build step may.
function M.class(name)
	local c = StaticFindObject(Calls.UMG .. name)
	assert(c ~= nil and c:IsValid(), "no widget class " .. name)
	return c
end

-- A slot that gives its child all its room, inside padding.
function M.fill(slot, padding)
	slot:SetHorizontalAlignment(L.FILL)
	slot:SetVerticalAlignment(L.FILL)
	if padding then slot:SetPadding(padding) end
	return slot
end

function M.centre(slot)
	slot:SetHorizontalAlignment(L.CENTRE)
	slot:SetVerticalAlignment(L.CENTRE)
	return slot
end

-- A builder for one panel: tree, the panel's widget tree, holds every widget made here. Every call may throw.
function M.builder(tree)
	local B, classes = {}, {}
	TEXTS, S.lacking = setmetatable({}, { __mode = "k" }), false

	function B.new(class)
		local c = classes[class]
		if c == nil then
			c = M.class(class)
			classes[class] = c
		end
		return StaticConstructObject(c, tree)
	end

	-- An empty text in one of the menu's fonts ("font_text", "font_number"). cut: too long, it ends with "…".
	function B.text(font, size, colour, cut)
		local tb = B.new("TextBlock")
		local object, key = Pieces.find(font)
		tb:SetFont({ Size = size, TypefaceFontName = FName("Default"), LetterSpacing = 0, FontObject = object })
		if font == "font_text" then
			local want = Pieces.text_font()
			TEXTS[tb] = { size = size, from = nil, want = want, font = key }
			if key ~= want then S.lacking = true end
		end
		M.paint(tb, colour)
		if cut then
			tb:SetTextOverflowPolicy(L.ELLIPSIS)
			tb:SetClipping(L.CLIP_TO_BOUNDS)
		end
		return tb
	end

	function B.place(canvas, widget, x1, y1, x2, y2)
		local slot = canvas:AddChildToCanvas(widget)
		slot:SetAnchors({ Minimum = { X = x1, Y = y1 }, Maximum = { X = x2, Y = y2 } })
		slot:SetOffsets(L.NO_PADDING)
		return slot
	end

	-- A box w wide and h high, either nil for its content's own; the content is set apart.
	function B.sized(w, h)
		local size = B.new("SizeBox")
		if w then size:SetWidthOverride(w) end
		if h then size:SetHeightOverride(h) end
		return size
	end

	-- An image of one of the game's textures ("line"), blank when it is not in memory.
	function B.image(texture)
		local img = B.new("Image")
		local t = Pieces.find(texture)
		if t then img:SetBrushFromTexture(t, false) end
		return img
	end

	-- A button whose own look is invisible: only its content shows. A click is read from IsPressed. Never focusable: a
	-- click gives Slate's focus to the widget under the mouse, and a focused button takes Cross, Enter and Space before
	-- the panel reads them (audit of 0.4.3). Set before its Slate widget is made, the only time the engine reads it
	-- (Unreal 5.7, Button.cpp line 84).
	function B.button()
		local b = B.new("Button")
		b.IsFocusable = false
		b:SetBackgroundColor(L.CLEAR)
		return b
	end

	-- The menu's arrow, pointing left or right; a plain one when the menu's is not in memory. The menu's points right
	-- (seen in game on 4 November 2026: mirrored for the right arrow, both pointed inwards), so the left one is mirrored.
	function B.arrow(left)
		local t = Pieces.find("arrow")
		if t == nil then
			local tb = B.text("font_text", L.TEXT_SIZE, L.WHITE)
			tb:SetText(FText(left and "<" or ">"))
			return tb
		end
		local img = B.new("Image")
		img:SetBrushFromTexture(t, false)
		if left then img:SetRenderScale({ X = -1, Y = 1 }) end
		return img
	end

	-- A row's own band, as the game's settings rows have it; then whether it is the game's (clear without it).
	function B.row_frame()
		local frame = B.new("Border")
		local row = Pieces.find("row")
		if row then frame:SetBrush(row.Background) else frame:SetBrushColor(L.CLEAR) end
		frame:SetPadding(L.NO_PADDING)
		return frame, row ~= nil
	end

	-- The selected-row band, laid over a row's own band; the view shows it on the chosen row only. Held by the row from
	-- its build on: passes 4 and 5 gave the band a texture kept only in Lua, the engine freed it, and the game crashed on
	-- the freed texture (4 November 2026, memory dumps).
	function B.band()
		local row, bar = Pieces.find("row"), Pieces.find("selected_bar")
		local b
		if row and bar then
			b = B.new("Image")
			b:SetBrush(row.Background)
			b:SetBrushFromTexture(bar, false)
		else
			b = B.new("Border")
			b:SetBrushColor(L.LIGHT)
		end
		return b
	end

	-- The menu's slider, from 0 to 1: the view sets a value's place on it. Never focusable, as the buttons (Slider.cpp
	-- line 52): a focused slider takes Cross and the left and right of the D-pad.
	function B.slider()
		local s = B.new("Slider")
		s.IsFocusable = false
		local template = Pieces.find("slider")
		if template then s.WidgetStyle = template.WidgetStyle end
		s:SetMinValue(0)
		s:SetMaxValue(1)
		s:SetStepSize(L.SLIDER_STEP)
		return s
	end

	return B
end

local function refont(tb, size, font)
	if tb:IsValid() then
		tb:SetFont({ Size = size, TypefaceFontName = FName("Default"), LetterSpacing = 0, FontObject = font })
	end
end

-- Gives text tb the font of its words' language: from, the language they were borrowed from (nil: the panel's).
-- Whether the game took it; nothing is asked of it while it has that font. fonts: { [key] = { object, key } } of the
-- fonts looked for in this call, nil for none kept.
local function give(tb, t, from, fonts)
	t.from = from
	local want = Pieces.text_font(from)
	t.want = want
	if want == t.font then return true end
	local f = fonts and fonts[want]
	if f == nil then
		f = { Pieces.find("font_text", from) }
		if fonts then fonts[want] = f end
	end
	if f[2] == t.font then
		S.lacking = true
		return true
	end
	if not pcall(refont, tb, t.size, f[1]) then
		-- Forgotten, so the next M.written asks the game again.
		t.want = nil
		return false
	end
	t.font = f[2]
	if f[2] ~= want then S.lacking = true end
	return true
end

-- The words of text tb come from the language from (nil: the panel's): their font (D159). Whether the game took it;
-- true for a text not in the text font. A wanted font not in memory is looked for again only by M.refont, not at each
-- frame.
function M.written(tb, from)
	local t = TEXTS[tb]
	if t == nil or (t.from == from and t.want == Pieces.text_font(from)) then return true end
	return give(tb, t, from, nil)
end

-- Whether a text has the menu's font in place of its own, which a later M.refont may find.
function M.lacking() return S.lacking end

-- Every text made in the text font given the font of its words' language now (mod_panel_pieces.lua), each font
-- looked for once, those not in memory at the last look too. How many texts the game refused.
function M.refont()
	local fonts, refused = {}, 0
	S.lacking = false
	Pieces.forget()
	for tb, t in pairs(TEXTS) do
		if not give(tb, t, t.from, fonts) then refused = refused + 1 end
	end
	return refused
end

return M
