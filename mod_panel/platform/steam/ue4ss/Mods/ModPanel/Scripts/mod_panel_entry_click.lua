-- What a click on a list entry hit: its diamond (D178), its switch's arrows or word (D183), else the entry itself,
-- which chooses its mod. Each of the first is a button of its own inside the entry's button, asked whether it was
-- clicked. The entry's button cannot be asked where the pointer was: a pressed button takes the mouse, and the engine
-- then tells everything inside it that the pointer has left (Unreal 5.7, SlateApplication.cpp, ProcessReply), so at
-- the click nothing inside is hovered any more; 1.0.2 and the first 1.0.3 asked it, and in game 54 clicks on the
-- switches' arrows only chose their mods (10 November 2026). Out of mod_panel_pointer.lua in 1.0.3.

local Pool = require("mod_panel_pool")
local View = require("mod_panel_view")

local M = {}

-- Entry i under the pointer; clicked(b, before): whether button b was clicked (mod_panel_pointer.lua), before the
-- button seen pressed at the last read; hovered(b): whether the pointer is on b. Sets on R, the pointer's read, pick,
-- fav, or switch with flip (-1 its left arrow, 1 its right one, 0 its word). At each frame on an entry: its buttons,
-- those that show, asked if pressed. A press on the diamond or the switch counts only let go over it: the pressed
-- button keeps its own pointer true while the pointer stays on it (discovery 29), and a press on an arrow let go on
-- the title switched the mod (audit of 1.0.3).
function M.read(i, clicked, hovered, before, R)
	local e = Pool.entry(i)
	if e == nil then return end
	if clicked(e.button, before) then
		R.pick = i
		return
	end
	local fav, switch = View.entry_parts(i)
	if fav and clicked(e.fav, before) then
		if hovered(e.fav) then R.fav = i end
		return
	end
	if not switch then return end
	local flip = clicked(e.left, before) and -1 or clicked(e.right, before) and 1 or clicked(e.value, before) and 0
	if flip and hovered(flip == -1 and e.left or flip == 1 and e.right or e.value) then R.switch, R.flip = i, flip end
end

return M
