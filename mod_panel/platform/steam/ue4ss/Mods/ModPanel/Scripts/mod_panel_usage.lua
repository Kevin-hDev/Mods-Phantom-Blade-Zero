-- What the player did in the open panel, said in one line when it closes: the keys heard, the controller's buttons
-- pressed, the rows and list entries the pointer came onto, the entries clicked, the frames the mouse moved in. The log
-- alone then tells what reached the mod: after 0.1.0's trial, only the panel key and C were said to work, and nothing
-- in the log told whether the other keys had reached it (D56). The pointer comes onto a row also when the row scrolls
-- under it: the mouse's moves tell the two apart (D100).

local Names = require("mod_panel_pad_names")

local M = {}

-- The keys of the open panel, by their count in the presses (mod_panel_keys.lua), and their name in the log.
local KEYS = { { "up", "Up" }, { "down", "Down" }, { "left", "Left" }, { "right", "Right" }, { "enter", "Enter" },
	{ "prev", "Z" }, { "next", "C" }, { "restore", "R" }, { "descriptions", "X" }, { "favorite", "F" } }

-- keys[count]: the presses heard; pad[name]: the controller's presses, in the order first pressed (order); rows,
-- entries: the times the pointer came onto one; row, entry: the one it was on at the last frame; moved: the frames the
-- mouse moved in; stick: the left stick's furthest push read, nil while its axes are not read (D86: the log then tells
-- whether they reach the mod).
local U = { keys = {}, pad = {}, order = {}, rows = 0, entries = 0, clicks = 0, row = nil, entry = nil, moved = 0,
	stick = nil }

-- At each opening.
function M.start()
	for _, k in ipairs(KEYS) do U.keys[k[1]] = 0 end
	U.pad, U.order = {}, {}
	U.rows, U.entries, U.clicks, U.row, U.entry, U.moved, U.stick = 0, 0, 0, nil, nil, 0, nil
end

-- At each frame the controller is read: how far the left stick was pushed (mod_panel_stick.lua), nil when not read.
function M.stick(push)
	if push ~= nil then U.stick = math.max(U.stick or 0, push) end
end

-- At each frame of the open panel: k, the presses (Keys.take(), or nil); R, what the pointer did
-- (mod_panel_pointer.lua).
function M.frame(k, R)
	if k ~= nil then
		for _, key in ipairs(KEYS) do U.keys[key[1]] = U.keys[key[1]] + k[key[1]] end
	end
	if R.over ~= nil and R.over ~= U.row then U.rows = U.rows + 1 end
	if R.entry ~= nil and R.entry ~= U.entry then U.entries = U.entries + 1 end
	if R.pick ~= nil or R.fav ~= nil then U.clicks = U.clicks + 1 end
	if R.mouse_moved then U.moved = U.moved + 1 end
	U.row, U.entry = R.over, R.entry
end

-- A press of the controller's button called name.
function M.pad(name)
	if U.pad[name] == nil then
		U.pad[name] = 0
		U.order[#U.order + 1] = name
	end
	U.pad[name] = U.pad[name] + 1
end

-- "keys Down 3, C 1; controller Cross 2; left stick pushed up to 0.98; the pointer came onto 12 rows and 4 mods,
-- 1 clicked; the mouse moved in 40 frames", the left stick's part only while its axes were read.
function M.summary()
	local heard, pressed = {}, {}
	for _, k in ipairs(KEYS) do
		if U.keys[k[1]] > 0 then heard[#heard + 1] = string.format("%s %d", k[2], U.keys[k[1]]) end
	end
	for _, name in ipairs(U.order) do pressed[#pressed + 1] = string.format("%s %d", Names.label(name), U.pad[name]) end
	return string.format("keys %s; controller %s; %sthe pointer came onto %d rows and %d mods, %d clicked; "
		.. "the mouse moved in %d frames",
		#heard > 0 and table.concat(heard, ", ") or "none", #pressed > 0 and table.concat(pressed, ", ") or "none",
		U.stick and string.format("left stick pushed up to %.2f; ", U.stick) or "", U.rows, U.entries, U.clicks, U.moved)
end

return M
