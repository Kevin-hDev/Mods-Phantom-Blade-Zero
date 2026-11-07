-- The mod's own lines in UE4SS.log, settings apart: bounded kinds of lines, errors written a few times then counted,
-- and a status line with the mod's cost. os.clock counts whole milliseconds with Windows' C runtime: an average over
-- many calls holds, one call does not.

local M = {}

local MAX_ERROR_LINES = 5        -- a repeated error is written a few times, then only counted
-- Camera, write, position, image, image problem, panel and panel problem lines, then only counted: each kind has its own bound, so one
-- cannot silence another (the panel's openings and closings never silence its failures).
local MAX_LINES = { camera = 20, write = 40, position = 40, image = 40, ["image problem"] = 20, panel = 60,
	["panel problem"] = 40,
	["panel save"] = 10 }

local function slot()
	return { calls = 0, busy = 0, longest = 0 }
end

local function average_us(s)
	return math.floor((s.calls > 0 and s.busy / s.calls or 0) * 1e6 + 0.5)
end

local function longest_ms(s)
	return math.floor(s.longest * 1000 + 0.5) + 1
end

function M.new(log)
	local T = { lines = {}, errors = 0, new_errors = 0, slots = { looks = slot(), ticks = slot(), frames = slot(), panel = slot() },
		writes = 0, failed = 0, sets = 0, set_failed = 0, image_writes = 0, image_failed = 0 }
	for kind in pairs(MAX_LINES) do T.lines[kind] = 0 end

	function T.bounded(kind, fmt, ...)
		local n = T.lines[kind] + 1
		T.lines[kind] = n
		if n <= MAX_LINES[kind] then log(fmt, ...) end
		if n == MAX_LINES[kind] then log("further %s lines are not written", kind) end
	end

	-- Runs fn(...), its time counted under name ("looks", "ticks", "frames" or "panel"); an error is written, then
	-- only counted.
	function T.run(name, fn, ...)
		local s = T.slots[name]
		local start = os.clock()
		local ok, err = pcall(fn, ...)
		local spent = os.clock() - start
		s.calls, s.busy, s.longest = s.calls + 1, s.busy + spent, math.max(s.longest, spent)
		if not ok then
			T.errors, T.new_errors = T.errors + 1, T.new_errors + 1
			if T.errors <= MAX_ERROR_LINES then
				log("error #%d: %s%s", T.errors, tostring(err),
					T.errors == MAX_ERROR_LINES and " (further errors are only counted in the status line)" or "")
			end
		end
	end

	-- The cost since the last status line. Ticks at work are those with a camera position to hold or to take away;
	-- frames are every call of the player controller's tick hook, the rest within them; the panel's calls are its
	-- frames while open, its openings, closings and refusals, and its changes written at the next tick.
	-- No word a mod manager takes for an error unless there is one: this game's mod manager on Nexus paints
	-- red any line with error(s), failed, failure, exception or fatal, and yellow warn(ing)(s); "failed 0" and "errors
	-- since start 0" made every status line red (5 November 2026). Refused writes are said in other words, and only
	-- when there were some; the errors are those since the last line, so one old error does not keep every line red.
	function T.line(modes, managed, minutes)
		local l, t, f, p = T.slots.looks, T.slots.ticks, T.slots.frames, T.slots.panel
		-- What a frame costs outside the looks, the ticks and the panel: mostly frames with nothing to do.
		local rest = { calls = f.calls, busy = math.max(f.busy - l.busy - t.busy - p.busy, 0) }
		log("status: %d camera modes, %d managed; in the last %d minutes: %d looks, about %d microseconds a look on "
			.. "average, the longest under %d ms, mode writes %d%s%s; camera position: "
			.. "%d ticks at work, about %d microseconds each, the longest under %d ms, layer set %d%s; "
			.. "image values written %d%s; "
			.. "frames %d (%d a second), about %d microseconds each (about %d outside the looks, ticks and panel), the "
			.. "longest under %d ms; panel: %d calls, about %d microseconds each, the longest under %d ms",
			math.max(modes, 0), math.max(managed, 0), minutes, l.calls, average_us(l), longest_ms(l), T.writes,
			T.failed > 0 and string.format(", could not be written %d", T.failed) or "",
			T.new_errors > 0 and string.format("; %d errors", T.new_errors) or "",
			t.calls, average_us(t), longest_ms(t), T.sets,
			T.set_failed > 0 and string.format(", could not be set %d", T.set_failed) or "", T.image_writes,
			T.image_failed > 0 and string.format(", could not be written %d", T.image_failed) or "", f.calls,
			math.floor(f.calls / math.max(minutes * 60, 1) + 0.5), average_us(f), average_us(rest), longest_ms(f),
			p.calls, average_us(p), longest_ms(p))
		T.slots.looks, T.slots.ticks, T.slots.frames, T.slots.panel = slot(), slot(), slot(), slot()
		T.writes, T.failed, T.sets, T.set_failed, T.new_errors = 0, 0, 0, 0, 0
		T.image_writes, T.image_failed = 0, 0
	end

	return T
end

return M
