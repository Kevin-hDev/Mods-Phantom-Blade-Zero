-- What the player did in the open panel, said in one line when it closes: the keys heard, the controller's buttons
-- pressed, the rows and list entries the pointer came onto, the entries clicked, the frames the mouse moved in. The log
-- alone then tells what reached the mod: after 0.1.0's trial, only the panel key and C were said to work, and nothing
-- in the log told whether the other keys had reached it (D56). The pointer comes onto a row also when the row scrolls
-- under it: the mouse's moves tell the two apart (D100).

local Names = require("mod_panel_pad_names")

local M = {}

-- The keys of the open panel, by their count in the presses (mod_panel_keys.lua), and their name in the log.
local KEYS = { { "up", "Up" }, { "down", "Down" }, { "left", "Left" }, { "right", "Right" }, { "enter", "Enter" },
	{ "prev", "Z" }, { "next", "C" }, { "restore", "R" }, { "descriptions", "X" }, { "favorite", "F" },
	{ "search", "Ctrl+F" } }

-- keys[count]: the presses heard; pad[name]: the controller's presses, in the order first pressed (order); rows,
-- entries: the times the pointer came onto one; row, entry: the one it was on at the last frame; moved: the frames the
-- mouse moved in; stick: the left stick's furthest push read, nil while its axes are not read (D86: the log then tells
-- whether they reach the mod); typed: the keys typed in the search field (D186), counted, never said one by one;
-- again: the writings of a key held there (D187), which the log alone tells from presses;
-- ends[cause]: the typings ended by it; field, cross: the clicks on the search field and on its cross.
local U = { keys = {}, pad = {}, order = {}, rows = 0, entries = 0, clicks = 0, row = nil, entry = nil, moved = 0,
	stick = nil, typed = 0, again = 0, ends = {}, field = 0, cross = 0 }

-- What ends a typing (mod_panel_typing.lua), by its name there, and its name in the log: the log tells how each typing
-- ended, which nothing told at the trial of 1.0.4, a click outside the panel leaving no other trace (audit of 1.0.4).
local ENDS = { { "enter", "Enter" }, { "escape", "Escape" }, { "press", "a press in the panel" },
	{ "click", "a click outside the panel" }, { "pad", "the controller" }, { "close", "the closing" } }

-- At each opening.
function M.start()
	for _, k in ipairs(KEYS) do U.keys[k[1]] = 0 end
	for _, e in ipairs(ENDS) do U.ends[e[1]] = 0 end
	U.pad, U.order = {}, {}
	U.rows, U.entries, U.clicks, U.row, U.entry, U.moved, U.stick, U.typed = 0, 0, 0, nil, nil, 0, nil, 0
	U.field, U.cross, U.again = 0, 0, 0
end

-- n keys typed in the search field, and again writings of a key held there.
function M.typed(n, again) U.typed, U.again = U.typed + n, U.again + (again or 0) end

-- A typing ended by cause, one of ENDS'.
function M.search_ended(cause)
	if U.ends[cause] ~= nil then U.ends[cause] = U.ends[cause] + 1 end
end

-- A click on the search field ("field") or on its cross ("cross").
function M.search_click(what)
	if what == "field" then U.field = U.field + 1 elseif what == "cross" then U.cross = U.cross + 1 end
end

-- "19 typed in the search, 12 written again by a key held, ended by Enter 1, a click outside the panel 1; the field
-- clicked 1, the cross 1; ", or "" while the search was not used.
local function searched()
	local ends = {}
	for _, e in ipairs(ENDS) do
		if U.ends[e[1]] > 0 then ends[#ends + 1] = string.format("%s %d", e[2], U.ends[e[1]]) end
	end
	if U.typed == 0 and #ends == 0 and U.field == 0 and U.cross == 0 then return "" end
	return string.format("%d typed in the search%s%s; %s", U.typed,
		U.again > 0 and string.format(", %d written again by a key held", U.again) or "",
		#ends > 0 and ", ended by " .. table.concat(ends, ", ") or "",
		(U.field > 0 or U.cross > 0) and string.format("the field clicked %d, the cross %d; ", U.field, U.cross) or "")
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
	if R.pick ~= nil or R.fav ~= nil or R.switch ~= nil then U.clicks = U.clicks + 1 end
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

-- "keys Down 3, C 1; 5 typed in the search, ended by Enter 1; controller Cross 2; left stick pushed up to 0.98; the
-- pointer came onto 12 rows and 4 mods, 1 clicked; the mouse moved in 40 frames", the search's and the left stick's
-- parts only when there is something to say.
function M.summary()
	local heard, pressed = {}, {}
	for _, k in ipairs(KEYS) do
		if U.keys[k[1]] > 0 then heard[#heard + 1] = string.format("%s %d", k[2], U.keys[k[1]]) end
	end
	for _, name in ipairs(U.order) do pressed[#pressed + 1] = string.format("%s %d", Names.label(name), U.pad[name]) end
	return string.format("keys %s; %scontroller %s; %sthe pointer came onto %d rows and %d mods, %d clicked; "
		.. "the mouse moved in %d frames", #heard > 0 and table.concat(heard, ", ") or "none",
		searched(),
		#pressed > 0 and table.concat(pressed, ", ") or "none",
		U.stick and string.format("left stick pushed up to %.2f; ", U.stick) or "", U.rows, U.entries, U.clicks, U.moved)
end

return M
