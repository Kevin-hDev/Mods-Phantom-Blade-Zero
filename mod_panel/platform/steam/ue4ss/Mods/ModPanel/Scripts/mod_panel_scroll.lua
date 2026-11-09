-- The scroll of the rows' and the list's boxes: which items a box shows, and an item brought into view. Taken out of
-- mod_panel_pointer.lua in 0.4.2, when the mouse's own moves came in (D100). Rows are all as high, so the box's scroll
-- offset and the share of its content it shows (GetViewFraction, not verified in game) tell which rows it shows. A
-- scroll is a number (SetScrollOffset): the open panel is handed no object.

local U = require("mod_panel_unreal")

local M = {}

-- Named functions for pcall.
local function offset_of(box) return box:GetScrollOffset() end
local function fraction_of(box) return box:GetViewFraction() end
local function set_offset(box, v) box:SetScrollOffset(v) end

-- The first and last of n items h high that box shows, its scroll offset and the height it shows; all n, and nil for
-- the two others, when it cannot say.
function M.shown(box, n, h)
	local ok1, offset = pcall(offset_of, box)
	local ok2, fraction = pcall(fraction_of, box)
	offset, fraction = ok1 and U.num(offset), ok2 and U.num(fraction)
	if not offset or not fraction or fraction <= 0 then return 1, n, nil, nil end
	local view = fraction * n * h
	return math.floor(offset / h) + 1, math.ceil((offset + view) / h), offset, view
end

-- Brings item i of n, h high, into box's view; i = "start" brings the box to its start.
function M.to(box, i, n, h)
	if i == "start" then
		pcall(set_offset, box, 0)
		return
	end
	local _, _, offset, view = M.shown(box, n, h)
	if offset == nil then return end
	local top, bottom = (i - 1) * h, i * h
	if top < offset then
		pcall(set_offset, box, top)
	elseif bottom > offset + view then
		pcall(set_offset, box, bottom - view)
	end
end

return M
