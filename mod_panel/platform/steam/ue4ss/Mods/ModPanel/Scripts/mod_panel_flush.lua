-- When the panel last let go of the keys held (bFlushInput, mod_panel_input.lua), the one place that knows it. The
-- engine then reads a button still held as let go, until its next repeat brings it back: 0.2 s after its press, then
-- every 0.1 s (Unreal 5.7, XInputInterface.cpp lines 51-52; PlayerInput.cpp line 402). Read in that gap, a held button
-- came back as a new press: the controller's combination held opened and closed the panel over and over (trial of
-- 0.5.2, D142).

local L = require("mod_panel_layout")

local M = {}

-- at: the last letting go; count: how many so far, so a reader tells a new one from the one it saw.
local S = { at = -math.huge, count = 0 }

-- The keys held were just let go, at now.
function M.mark(now)
	S.at, S.count = now, S.count + 1
end

-- Whether now is in the gap after the last letting go, when a button held then and read let go may be held still.
function M.quiet(now) return now - S.at < L.FLUSH_QUIET end

-- How many lettings go so far.
function M.count() return S.count end

return M
