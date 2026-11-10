-- The panel's backdrop: the right of the screen darkened, fading in from the left, without blur (the cleanest of the
-- looks tried in play for Dynamic FOV, 4 November 2026; a blur's edge cannot fade). How dark it is, the player chooses
-- (PanelOpacity); the fade stays as soft at every darkness. Taken from Dynamic FOV 1.0.4
-- (dynamic_fov_panel_backdrop.lua), made one band at a time for a build in slices (D38).

local L = require("mod_panel_layout")

local M = {}

M.BANDS = L.FADE_STEPS + 1        -- the fade's bands, then the strip

-- 0 at the fade's left edge, 1 where the strip is full; flat at both ends (no first derivative nor second), so neither
-- the edge nor the join with the strip shows as a line.
local function ease(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- How wide the fade is for an alpha: a darker backdrop fades over a wider band, so its slope, what makes a fade look
-- hard, stays look C's at every darkness.
local function fade_width(alpha)
	return L.FADE_WIDTH * alpha / L.FADE_ALPHA
end

-- Where band i of M.BANDS stands for a strip full from strip (a share of the screen's width) to the right edge, and a
-- fade covering the darkest backdrop the player may choose (max, in %): its left and right edges, then where its middle
-- sits in screen widths left of the strip, which the strip's place does not change (D90).
function M.span(i, max, strip)
	if i >= M.BANDS then return strip, 1, 0 end
	local widest = fade_width(max / 100)
	local step = widest / L.FADE_STEPS
	local x1 = strip - widest + (i - 1) * step
	return x1, x1 + step, widest - (i - 1) * step - step / 2
end

-- Band i under canvas, clear, by B (mod_panel_make.lua), the three columns shown. Returns the band, its slot, and where
-- its middle sits left of the strip.
function M.band(B, canvas, i, max)
	local x1, x2, from_strip = M.span(i, max, L.STRIP)
	local b = B.new("Border")
	b:SetBrushColor(L.CLEAR)
	local slot = B.place(canvas, b, x1, 0, x2, 1)
	b:SetVisibility(L.HIT_TEST_INVISIBLE)
	return { border = b, slot = slot, from_strip = from_strip }
end

-- How dark a band is for a backdrop opacity % dark, max % at most.
function M.alpha(from_strip, opacity, max)
	local alpha = math.min(opacity, max) / 100
	if alpha <= 0 then return 0 end
	return alpha * ease(1 - from_strip / fade_width(alpha))
end

local function set_alpha(band, shade, alpha)
	band.border:SetBrushColor({ R = shade.R, G = shade.G, B = shade.B, A = alpha })
end

-- The colour of a Background color value (D177); the default's for a value Mod Panel does not know.
function M.shade(color)
	return L.BACKDROPS[color] or L.BACKDROPS[L.BACKDROP]
end

-- Darkens the bands for opacity, in color; tried(ok) counts what the game refused. Returns whether every band took it.
function M.paint(bands, opacity, color, max, tried)
	local all, shade = true, M.shade(color)
	for _, band in ipairs(bands) do
		if not tried(pcall(set_alpha, band, shade, M.alpha(band.from_strip, opacity, max))) then all = false end
	end
	return all
end

return M
