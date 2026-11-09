-- Mod Panel's own lines in UE4SS.log: bounded kinds of lines, errors written a few times then counted, and a status
-- line with the mod's cost. Taken from Dynamic FOV 1.0.4 (dynamic_fov_status.lua). os.clock counts whole milliseconds
-- with Windows' C runtime: an average over many calls holds, one call does not.

local M = {}

local MAX_ERROR_LINES = 5         -- errors written, then only counted, a new error's text excepted
local MAX_ERROR_TEXTS = 20        -- different errors' texts written in all
-- Lines of each kind, then only counted: each kind has its own bound, so one cannot silence another (the panel's
-- openings and closings never silence its problems, nor a mod refused the panel's own lines). The openings' and
-- closings' own bound (D104): at the trial of 0.4.0 the routine lines reached theirs at the seventh opening.
local MAX_LINES = { panel = 60, openings = 200, ["panel problem"] = 40, catalog = 100, edits = 100,
	["edits problem"] = 40, signal = 40, state = 40 }
-- Where the time goes: frames with the panel closed, frames with it open, the pieces of an opening (D38).
local SLOTS = { "closed", "open", "opening" }

local function slot()
	return { calls = 0, busy = 0, longest = 0 }
end

local function average_us(s)
	return math.floor((s.calls > 0 and s.busy / s.calls or 0) * 1e6 + 0.5)
end

local function longest_ms(s)
	return math.floor(s.longest * 1000 + 0.5) + 1
end

local function count(n, one, many)
	return string.format("%d %s", n, n == 1 and one or many)
end

function M.new(log)
	-- texts: the errors' texts written, so a second error, unlike the first that repeats, is still written.
	local T = { lines = {}, errors = 0, new_errors = 0, slots = {}, texts = {}, text_count = 0 }
	for kind in pairs(MAX_LINES) do T.lines[kind] = 0 end
	for _, name in ipairs(SLOTS) do T.slots[name] = slot() end

	local function failed(err)
		T.errors, T.new_errors = T.errors + 1, T.new_errors + 1
		local text = tostring(err)
		local new = T.texts[text] == nil and T.text_count < MAX_ERROR_TEXTS
		if new then T.texts[text], T.text_count = true, T.text_count + 1 end
		if T.errors <= MAX_ERROR_LINES or new then
			log("error #%d: %s%s", T.errors, text,
				T.errors == MAX_ERROR_LINES and " (further errors are only counted in the status line, a new one "
					.. "excepted)" or "")
		end
	end

	function T.bounded(kind, fmt, ...)
		local n = T.lines[kind] + 1
		T.lines[kind] = n
		if n <= MAX_LINES[kind] then log(fmt, ...) end
		if n == MAX_LINES[kind] then log("further %s lines are not written", kind) end
	end

	-- Runs fn(...), its time counted under the slot name; an error is written, then only counted.
	function T.run(name, fn, ...)
		local s = T.slots[name]
		local start = os.clock()
		local ok, err = pcall(fn, ...)
		local spent = os.clock() - start
		s.calls, s.busy, s.longest = s.calls + 1, s.busy + spent, math.max(s.longest, spent)
		if not ok then failed(err) end
	end

	-- Runs fn(...) inside a T.run, apart from the rest of it (D102): an error in one part of a frame leaves the others
	-- running.
	function T.guard(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then failed(err) end
	end

	-- The cost since the last status line, and facts from the other parts, each said when given: mods (listed) with
	-- left_out, openings. No word a mod manager takes for an error unless there is one: this game's mod manager on
	-- Nexus paints red any line with error(s), failed, failure, exception or fatal, and yellow warn(ing)(s). The
	-- errors are those since the last line, so one old error does not keep every line red.
	function T.line(minutes, facts)
		local closed, open, opening = T.slots.closed, T.slots.open, T.slots.opening
		local parts = {}
		if facts.mods ~= nil then
			parts[#parts + 1] = string.format("%s listed, %d left out", count(facts.mods, "mod", "mods"),
				facts.left_out or 0)
		end
		if facts.openings ~= nil then parts[#parts + 1] = "opened " .. count(facts.openings, "time", "times") end
		parts[#parts + 1] = string.format("frames with the panel closed %d (%d a second), about %d microseconds each, "
			.. "the longest under %d ms", closed.calls, math.floor(closed.calls / math.max(minutes * 60, 1) + 0.5),
			average_us(closed), longest_ms(closed))
		if open.calls > 0 then
			parts[#parts + 1] = string.format("frames with the panel open %d, about %d microseconds each, the longest "
				.. "under %d ms", open.calls, average_us(open), longest_ms(open))
		end
		if opening.calls > 0 then
			parts[#parts + 1] = string.format("pieces of openings %d, the longest under %d ms", opening.calls,
				longest_ms(opening))
		end
		if T.new_errors > 0 then parts[#parts + 1] = count(T.new_errors, "error", "errors") end
		log("status: in the last %d minutes: %s", minutes, table.concat(parts, "; "))
		for _, name in ipairs(SLOTS) do T.slots[name] = slot() end
		T.new_errors = 0
	end

	return T
end

return M
