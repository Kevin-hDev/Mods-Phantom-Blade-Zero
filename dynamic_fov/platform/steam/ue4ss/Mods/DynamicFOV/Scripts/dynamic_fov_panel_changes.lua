-- What the mouse, the controller and the keys do to the open panel (1.0.5; the mouse's part was dynamic_fov_panel.lua's
-- until 1.0.4): the chosen row, the settings changed, Restore defaults and its Undo, the scroll asked for. The chosen
-- row has the light band, its explanation and its preview. The last device wins: the pointer coming onto a row chooses
-- it, and the next press goes on from there; a still pointer never takes back a move of the keys, nor a row the box
-- scrolled under it; a slider moved or an arrow clicked chooses its row. A row the pointer chose is let go when the pointer leaves the rows, as until 1.0.4:
-- a field of view's preview would stay in the view while the player plays; one a key or the controller chose or
-- changed stays, as the controller needs. The first press of the controller or the keys chooses the row under the pointer,
-- else the first; up and down stop at the ends and pass over the group titles. Left and right step a number (held on
-- the controller: faster and faster), turn a switch over and go round a choice, once per press; held while the row
-- changes (up at once on the D-pad, the mouse), nothing until let go. Cross or Enter turns a switch over or takes the
-- next choice. A row that waits for another setting is
-- chosen, its explanation read, but does not change. Restore defaults, pressed again before any other change, gives
-- back the settings it replaced: an undo rather than a question, and nothing is lost to a press gone astray.

local Rows = require("dynamic_fov_panel_rows")
local Commands = require("dynamic_fov_panel_commands")

local M = {}

local HOLD_STEPS = { { 0, 1 }, { 1, 2 }, { 2, 5 } }   -- { seconds held, steps each time }
-- Frames after a move of the keys or the controller in which a row coming under the still pointer is not chosen: the
-- box may scroll under it, and the scroll shows a frame or two later.
local QUIET = 3

-- lines: the panel's (dynamic_fov_panel_rows.lua); warn(message): a settings line.
function M.new(lines, warn)
	-- chosen: the chosen row's place in lines (nil: none yet); over: the row under the pointer at the last frame;
	-- undo: the settings before Restore defaults; held: { row, dir, since, next } of the controller's side held;
	-- scroll: the row to bring into view; pad: the last press was the controller's; mouse: the pointer chose the row,
	-- and no key nor button acted on it since.
	local C = { chosen = nil, over = nil, undo = nil, held = nil, scroll = nil, quiet = 0, pad = false, mouse = false }

	local function choosable(i) return lines[i] ~= nil and lines[i].kind ~= nil end

	local function first()
		for i = 1, #lines do
			if choosable(i) then return i end
		end
	end

	-- At each opening: nothing chosen, nothing held, no Undo.
	function C.start()
		C.chosen, C.over, C.undo, C.held, C.scroll, C.quiet, C.pad, C.mouse = nil, nil, nil, nil, nil, 0, false, false
	end

	-- The first press with no row chosen chooses the first row, and does nothing else: a row under the pointer is
	-- chosen already, as the pointer came onto it. Returns whether it did.
	local function choose_first()
		if C.chosen ~= nil then return false end
		C.chosen = first()
		C.scroll, C.quiet = C.chosen, QUIET
		return true
	end

	local function move(step, n)
		if n == 0 then return end
		if choose_first() then n = n - 1 end
		if n == 0 then return end
		for _ = 1, n do
			local i = C.chosen + step
			while lines[i] ~= nil and not choosable(i) do i = i + step end
			if lines[i] ~= nil then C.chosen = i end
		end
		C.scroll, C.quiet = C.chosen, QUIET
	end

	-- s with line stepped n times towards dir (-1, 1): a number by n steps, a switch or a choice once a step.
	local function stepped(s, line, dir, n)
		if line == nil or n == 0 or Rows.waits_for(line, s) ~= nil then return s end
		if line.kind == "number" then
			local v = Rows.on_step(line, Rows.value(line, s) + dir * n * line.step)
			return v == Rows.value(line, s) and s or Rows.with(s, line, v, warn)
		end
		for _ = 1, n do s = Rows.with(s, line, Rows.next(line, s, dir), warn) end
		return s
	end

	-- The controller's side held (-1, 1 or nil) on the chosen row: a step at the press; on a number, more while it
	-- stays held, from HOLD_DELAY on. moved: up or down stepped in this frame.
	local function hold(s, side, now, moved)
		local h = C.held
		if side == nil then
			C.held = nil
			return s
		end
		if choose_first() then
			C.held = { row = C.chosen, dir = side, since = now, next = math.huge }
			return s
		end
		-- The row changed under the side still held, or in the frame of its press (up and left at once on the D-pad):
		-- each row passed would change too (audit of 1.0.5).
		if (h ~= nil and h.dir == side and h.row ~= C.chosen) or (h == nil and moved) then
			C.held = { row = C.chosen, dir = side, since = now, next = math.huge }
			return s
		end
		if h == nil or h.dir ~= side then
			C.held = { row = C.chosen, dir = side, since = now, next = now + Commands.HOLD_DELAY }
			return stepped(s, lines[C.chosen], side, 1)
		end
		if lines[C.chosen].kind ~= "number" or now < h.next then return s end
		local n = 1
		for _, step in ipairs(HOLD_STEPS) do
			if now - h.since >= step[1] then n = step[2] end
		end
		h.next = now + Commands.HOLD_EVERY
		return stepped(s, lines[C.chosen], side, n)
	end

	-- Cross or Enter n times on the chosen row: a switch turned over, the next choice.
	local function enter(s, n)
		local line = lines[C.chosen]
		if line == nil or line.kind == "number" then return s end
		return stepped(s, line, 1, n)
	end

	-- The commands t of the keys or the controller (nil: none) on s: the moves, the steps, Cross or Enter. Returns the
	-- settings and t's presses of Restore defaults.
	local function commands(s, t)
		if t == nil then return s, 0 end
		move(-1, t.up)
		move(1, t.down)
		if (t.left > 0 or t.right > 0 or t.enter > 0) and not choose_first() then
			s = stepped(s, lines[C.chosen], -1, t.left)
			s = stepped(s, lines[C.chosen], 1, t.right)
			s = enter(s, t.enter)
		end
		return s, t.restore
	end

	-- What the pointer did (R, dynamic_fov_panel_view.lua): the row it came onto chosen, a slider moved, an arrow
	-- clicked. Returns the settings and whether the pointer acted.
	local function pointer(s, R)
		local acted = false
		if R.over ~= C.over then
			if R.over ~= nil and C.quiet == 0 then
				C.chosen, C.mouse, acted = R.over, true, true
			elseif R.over == nil and C.mouse then
				C.chosen, C.mouse = nil, false
			end
			C.over = R.over
		end
		for i, line in ipairs(lines) do
			local v, dir = R.moved[i], R.click[i]
			if v ~= nil or dir ~= nil then C.chosen, C.mouse, acted = i, true, true end
			if v ~= nil then
				v = Rows.on_step(line, v)
				if v ~= Rows.value(line, s) and Rows.waits_for(line, s) == nil then s = Rows.with(s, line, v, warn) end
			elseif dir ~= nil then
				s = stepped(s, line, dir, 1)
			end
		end
		return s, acted or R.restore or R.close
	end

	-- At each frame: s the settings in use, R what the pointer did, k the keys' presses (or nil), c the controller's
	-- (or nil), side the controller's side held, pad whether a controller button acted, now the clock. Returns the
	-- settings after them.
	function C.frame(s, R, k, c, side, pad, now)
		local new, mouse = pointer(s, R)
		if C.quiet > 0 then C.quiet = C.quiet - 1 end
		local by_keys, by_pad
		new, by_keys = commands(new, k)
		new, by_pad = commands(new, c)
		local restore = (R.restore and 1 or 0) + by_keys + by_pad
		new = hold(new, side, now, c ~= nil and (c.up > 0 or c.down > 0))
		if k ~= nil or c ~= nil or side ~= nil then C.mouse = false end
		if pad then C.pad = true elseif mouse or k ~= nil then C.pad = false end
		if new ~= s then C.undo = nil end
		for _ = 1, restore do
			if C.undo ~= nil then new, C.undo = C.undo, nil else C.undo, new = new, Rows.defaults(new, warn) end
		end
		return new
	end

	function C.chosen_row() return C.chosen end

	-- The row to bring into view, once; nil when none was asked for since.
	function C.take_scroll()
		local i = C.scroll
		C.scroll = nil
		return i
	end

	-- Whether the last press was the controller's: its icons then show on the buttons.
	function C.by_pad() return C.pad end

	function C.undo_offered() return C.undo ~= nil end

	-- The settings file was read again while the panel is open: Undo would give back older settings.
	function C.forget_undo() C.undo = nil end

	return C
end

return M
