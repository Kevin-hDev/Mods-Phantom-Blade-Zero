-- Vault & Climb Anywhere's status line, every EVERY s: the jumps followed and our traversals played, how often the
-- mod ran and what it cost, at rest apart from while busy (a jump followed or our traversal running), the longest call
-- and what it did, the calls over SLOW s, the frames of a press, and the errors when there are some. The cost at rest
-- is what every frame pays; the longest call shows a freeze that an average hides. os.clock counts whole milliseconds
-- on Windows: the longest call is read to the millisecond, and a share of the cost only on average, over many calls.
-- A trial build writes it every TRIAL_EVERY s, with the share of the cost at rest its detail takes (vault_watch.lua
-- and the reads made for it), so that a published build's cost reads from a trial.
-- No word a mod manager takes for an error unless there is one: some paint red any line with error(s), failed,
-- failure, exception or fatal.

local Trial = require("vault_trial")

local M = {}

local EVERY = 600                 -- s
local TRIAL_EVERY = 120           -- s
local SLOW = 0.002                -- s: a call longer than this is counted apart, with what it did
local MAX_KINDS = 8               -- kinds of slow calls told apart; the others are counted as "other"
local NOTHING = "no press, measure, traversal start, setup write, file, jump keys or jump line"

local C = { next = nil, jumps = 0, played = 0, calls = 0, busy = 0, busy_calls = 0, busy_time = 0, errors = 0,
	longest = 0, longest_what = nil, detail = 0, slow = 0, kinds = {}, kind_list = {}, press_calls = 0,
	press_time = 0, press_longest = 0 }
-- This call's: the detail's time, what it did, and whether it had a press.
local T = { detail = 0, what = {}, n = 0, press = false }

-- What this call did, in order: a press, a new measure, our traversal's start, the game's traversal setup, the Mods
-- Menu's file, the settings file, the game's jump keys, a jump's line. Each comes at most once a call.
function M.note(what)
	T.n = T.n + 1
	T.what[T.n] = what
end

-- Seconds this call spent on the trial's detail.
function M.detail(spent)
	T.detail = T.detail + spent
end

local function slow(what)
	C.slow = C.slow + 1
	if C.kinds[what] == nil then
		if #C.kind_list >= MAX_KINDS then what = "other" end
		if C.kinds[what] == nil then
			C.kinds[what] = 0
			C.kind_list[#C.kind_list + 1] = what
		end
	end
	C.kinds[what] = C.kinds[what] + 1
end

-- One tick: the seconds it took; busy, a jump followed or our traversal running at its end; failed, it raised an error.
function M.tick(spent, busy, failed)
	C.calls, C.busy = C.calls + 1, C.busy + spent
	local what = T.n > 0 and table.concat(T.what, " and ", 1, T.n) or NOTHING
	if spent > C.longest then C.longest, C.longest_what = spent, what end
	if spent > SLOW then slow(what) end
	if busy then
		C.busy_calls, C.busy_time = C.busy_calls + 1, C.busy_time + spent
	else
		C.detail = C.detail + T.detail
	end
	if T.press then
		C.press_calls, C.press_time = C.press_calls + 1, C.press_time + spent
		if spent > C.press_longest then C.press_longest = spent end
	end
	if failed then C.errors = C.errors + 1 end
	T.detail, T.n, T.press = 0, 0, false
end

function M.jump()
	C.jumps = C.jumps + 1
	T.press = true
end

function M.played()
	C.played = C.played + 1
end

local function per_call(busy, calls)
	return string.format("%.1f", calls > 0 and busy / calls * 1e6 or 0)
end

local function slow_text()
	if C.slow == 0 then return "no call over 2 ms" end
	local parts = {}
	for _, what in ipairs(C.kind_list) do parts[#parts + 1] = string.format("%d %s", C.kinds[what], what) end
	return string.format("%d calls over 2 ms (%s)", C.slow, table.concat(parts, "; "))
end

local function reset()
	C.jumps, C.played, C.calls, C.busy, C.busy_calls, C.busy_time, C.errors, C.longest = 0, 0, 0, 0, 0, 0, 0, 0
	C.longest_what, C.detail, C.slow, C.kinds, C.kind_list = nil, 0, 0, {}, {}
	C.press_calls, C.press_time, C.press_longest = 0, 0, 0
end

-- Writes the line once every EVERY s (TRIAL_EVERY in a trial build), the first one that long after the first call,
-- then counts again from zero.
function M.write(now, log)
	local every = Trial.on and TRIAL_EVERY or EVERY
	if C.next == nil then C.next = now + every end
	if now < C.next then return end
	C.next = now + every
	local rest_calls = C.calls - C.busy_calls
	local detail = Trial.on and string.format(" (%s of it for the trial's detail)", per_call(C.detail, rest_calls)) or ""
	log("status: %d jumps and %d of our traversals in the last %d minutes; %d calls (%.0f a second), %s microseconds "
		.. "a call on average: %s at rest%s, %s while busy (%d calls); longest call %.0f ms (%s); %s; press frames: "
		.. "%d, %s microseconds on average, longest %.0f ms%s", C.jumps, C.played, every // 60, C.calls,
		C.calls / every, per_call(C.busy, C.calls), per_call(C.busy - C.busy_time, rest_calls), detail,
		per_call(C.busy_time, C.busy_calls), C.busy_calls, C.longest * 1000, C.longest_what or NOTHING, slow_text(),
		C.press_calls, per_call(C.press_time, C.press_calls), C.press_longest * 1000,
		C.errors > 0 and string.format(", %d errors", C.errors) or "")
	reset()
end

return M
