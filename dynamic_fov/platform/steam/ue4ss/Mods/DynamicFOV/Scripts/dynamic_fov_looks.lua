-- The cinematic looks (1.0.9): six colour grades the player picks from, written in the image settings of the cameras
-- the mod holds (dynamic_fov_image.lua). Each is made of values the game's places leave at their neutral (GradeProbe,
-- 12 November 2026, two zones read): the general contrast, the gain of the midtones and of the highlights, the gamma
-- of the shadows. The engine multiplies them with each place's own grade (Unreal 5.7, PostProcessCombineLUTs.usf,
-- ColorCorrectAll), so a look sits on top of a place's mood instead of replacing it.
-- A tint is not written in the general gain, which places of the second zone set (down to 0.85, 0.90, 0.95): it goes
-- in the gain of the midtones and of the highlights, and in the shadows as the gamma that gives the same at a
-- luminance of 0.045, the middle of the shadows' range. A look's saturation multiplies the colours', in the one
-- general saturation the mod writes.

local M = {}

-- The menu's values, in the order of its list; the first is the default.
M.NAMES = { "TealOrange", "Warm", "Cold", "Faded", "BlackWhite", "Vintage" }

local CONTRAST, SHADOWS = "ColorContrast", "ColorGammaShadows"
local MIDTONES, HIGHLIGHTS = "ColorGainMidtones", "ColorGainHighlights"

local function rgb(r, g, b, w) return { X = r, Y = g, Z = b, W = w or 1 } end
local function all(w) return rgb(1, 1, 1, w) end

-- saturation: times the colours', nil to leave it. values[field]: what multiplies the camera's own, axis by axis.
local LOOKS = {
	TealOrange = { values = { [CONTRAST] = all(1.10), [SHADOWS] = rgb(0.95, 1.00, 1.07),
		[HIGHLIGHTS] = rgb(1.08, 1.00, 0.90) } },
	Warm = { values = { [CONTRAST] = all(1.08), [SHADOWS] = rgb(1.025, 1.00, 0.960),
		[MIDTONES] = rgb(1.08, 1.00, 0.88), [HIGHLIGHTS] = rgb(1.08, 1.00, 0.88) } },
	Cold = { saturation = 0.85, values = { [CONTRAST] = all(1.10), [SHADOWS] = rgb(0.967, 1.00, 1.032),
		[MIDTONES] = rgb(0.90, 1.00, 1.10), [HIGHLIGHTS] = rgb(0.90, 1.00, 1.10) } },
	Faded = { saturation = 0.55, values = { [CONTRAST] = all(1.22) } },
	BlackWhite = { saturation = 0, values = { [CONTRAST] = all(1.25) } },
	-- The shadows a little lifted (the gamma's W), as on old film.
	Vintage = { saturation = 0.85, values = { [CONTRAST] = all(0.92), [SHADOWS] = rgb(1.019, 1.00, 0.967, 1.12),
		[MIDTONES] = rgb(1.06, 1.00, 0.90), [HIGHLIGHTS] = rgb(1.06, 1.00, 0.90) } },
}

-- The look of that name, or nil.
function M.get(name)
	return LOOKS[name]
end

return M
