-- The panel's backdrop: the right of the screen darkened, fading in from the left, without blur (the cleanest of the looks
-- tried in play, 4 November 2026; a blur's edge cannot fade). How dark it is, the player chooses (PanelOpacity,
-- 1.0.3); the fade stays very soft at every opacity.

local Make = require("dynamic_fov_panel_make")
local Settings = require("dynamic_fov_settings")

local M = {}

-- Look C: 55 % dark, fading from 56 % of the width to where the strip is full. A darker backdrop fades over a wider
-- band, so its slope, what makes a fade look hard, stays look C's at every darkness.
local LOOK_C_ALPHA, LOOK_C_WIDTH = 0.55, Make.LEFT - 0.56
local MAX_ALPHA = Settings.OPACITY_MAX / 100
-- The bands cover the widest fade, about 2 px each on a 1080 screen; even at 90 % two of them differ by under 2 % of
-- darkness. 48 bands of a narrower fade were enough at 55 %; 8 showed as columns (pass 3).
local FADE_STEPS = 96
local WIDEST = LOOK_C_WIDTH * MAX_ALPHA / LOOK_C_ALPHA
local SHADE = { R = 0.01, G = 0.011, B = 0.014 }

-- 0 at the fade's left edge, 1 where the strip is full; flat at both ends (no first derivative nor second), so neither
-- the edge nor the join with the strip shows as a line.
local function ease(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- B: the panel's builder (dynamic_fov_panel_make.lua). Built clear; paint() darkens it. Returns the bands, each with
-- where its middle sits, in screen widths left of the strip (the strip itself at 0).
function M.build(B, canvas)
	local bands = {}
	local function shade(x1, x2, from_strip)
		local b = B.new("Border")
		b:SetBrushColor({ R = SHADE.R, G = SHADE.G, B = SHADE.B, A = 0 })
		B.place(canvas, b, x1, 0, x2, 1)
		b:SetVisibility(Make.HIT_TEST_INVISIBLE)
		bands[#bands + 1] = { border = b, from_strip = from_strip }
	end
	local step = WIDEST / FADE_STEPS
	for i = 1, FADE_STEPS do
		local x = Make.LEFT - WIDEST + (i - 1) * step
		shade(x, x + step, Make.LEFT - (x + step / 2))
	end
	shade(Make.LEFT, 1, 0)
	return bands
end

-- How dark a band is for a backdrop opacity % dark.
function M.alpha(from_strip, opacity)
	local alpha = math.min(opacity / 100, MAX_ALPHA)
	local width = LOOK_C_WIDTH * alpha / LOOK_C_ALPHA
	return alpha * ease(1 - from_strip / width)
end

local function set_alpha(band, alpha)
	band.border:SetBrushColor({ R = SHADE.R, G = SHADE.G, B = SHADE.B, A = alpha })
end

-- Darkens the bands for opacity; tried(ok) counts what the game refused. Returns whether every band took it.
function M.paint(bands, opacity, tried)
	local all = true
	for _, band in ipairs(bands) do
		if not tried(pcall(set_alpha, band, M.alpha(band.from_strip, opacity))) then all = false end
	end
	return all
end

return M
