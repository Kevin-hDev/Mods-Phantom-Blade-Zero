-- The controller's combination (D124): its two buttons pressed together, the second at most COMBO_WINDOW seconds
-- after the first, open the panel, and close it (mod_panel_controls.lua, when neither is a command of the open panel).
-- No hold: a press is what a player does (D136). One held for long, then the other, is no
-- combination, so a button kept down in a fight does not turn the other into a way to open the panel. After each use,
-- one of the two is let go before they count again, so a press does not close what it just opened (D133). The panel
-- closed, both are read held at each frame (D136); open, they come from the buttons the panel reads anyway
-- (mod_panel_pad.lua).

local L = require("mod_panel_layout")
local Pad = require("mod_panel_pad")
local Flush = require("mod_panel_flush")

local M = {}

-- at: when each of the two went down (at[1], at[2]), nil while it is up; LONG_AGO for one held at a start. armed: one
-- was let go since the last use. first, second: the pair this state was made for.
local LONG_AGO = -math.huge
local S = { at = {}, armed = true, first = nil, second = nil }

-- Made again for pair, first and second telling whether each is held now: one held counts as pressed long ago, and
-- the two count again only once one is let go. At an opening, at the end of a wait, and whenever the pair changes:
-- a pair just chosen, in the panel or in Mods Menu, while its buttons are still held must not close the panel
-- (audit of 0.5.1).
local function rebase(pair, first, second)
	S.first, S.second = pair and pair[1], pair and pair[2]
	S.at[1] = first and LONG_AGO or nil
	S.at[2] = second and LONG_AGO or nil
	S.armed = not (first and second)
end

local function seen(i, down, now)
	if not down then
		S.at[i] = nil
	elseif S.at[i] == nil then
		S.at[i] = now
	end
end

-- first, second: whether each button of pair is held now, at now. Whether they were just pressed together. One read
-- let go just after the panel let go of the keys may be held still: it lets them count again only after (D142).
local function together(pair, first, second, now)
	if pair[1] ~= S.first or pair[2] ~= S.second then
		rebase(pair, first, second)
		return false
	end
	seen(1, first, now)
	seen(2, second, now)
	if not (first and second) then
		if not Flush.quiet(now) then S.armed = true end
		return false
	end
	if not S.armed or math.abs(S.at[1] - S.at[2]) > L.COMBO_WINDOW then return false end
	S.armed = false
	return true
end

-- The panel closed, at each frame: pair, { first, second } (mod_panel_settings.lua). Whether it opens the panel.
function M.closed(pc, pair, now)
	return together(pair, Pad.down(pc, pair[1]), Pad.down(pc, pair[2]), now)
end

-- At an opening, and at the end of a wait (mod_panel_capture.lua): down, the buttons held then (Pad.held()).
function M.start(down, pair)
	rebase(pair, pair ~= nil and down[pair[1]] == true, pair ~= nil and down[pair[2]] == true)
end

-- The panel open, at each frame: down, the buttons held (Pad.held()). Whether it closes the panel.
function M.open(down, pair, now)
	return together(pair, down[pair[1]] == true, down[pair[2]] == true, now)
end

return M
