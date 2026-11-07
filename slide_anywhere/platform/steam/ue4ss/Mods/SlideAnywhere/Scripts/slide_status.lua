-- Slide Anywhere's status line, every EVERY s: the slides, how often the mod ran and what it cost, the cost at rest
-- apart from the cost while sliding (the lean easing back after a slide counts as sliding), the longest call, and the
-- errors when there are some. optimisation.md asks for the cost at rest: a trial full of slides hid it (0.2.0,
-- 5 November 2026: 237.7 microseconds a call, 123 s of sliding in 600); and for the longest task, a freeze that an
-- average hides. os.clock counts whole milliseconds on Windows: the longest call is read to the millisecond.
-- No word a mod manager takes for an error unless there is one: some paint red any line with error(s), failed,
-- failure, exception or fatal.

local M = {}

local EVERY = 600                 -- s

local C = { next = nil, slides = 0, calls = 0, busy = 0, slide_calls = 0, slide_busy = 0, errors = 0, longest = 0 }

-- One tick: the seconds it took; sliding, a slide under way at its end; failed, it raised an error.
function M.tick(spent, sliding, failed)
	C.calls, C.busy = C.calls + 1, C.busy + spent
	if spent > C.longest then C.longest = spent end
	if sliding then C.slide_calls, C.slide_busy = C.slide_calls + 1, C.slide_busy + spent end
	if failed then C.errors = C.errors + 1 end
end

function M.slide()
	C.slides = C.slides + 1
end

local function per_call(busy, calls)
	return string.format("%.1f", calls > 0 and busy / calls * 1e6 or 0)
end

-- Writes the line once every EVERY s, the first one EVERY s after the first call, then counts again from zero.
function M.write(now, log)
	if C.next == nil then C.next = now + EVERY end
	if now < C.next then return end
	C.next = now + EVERY
	log("status: %d slides in the last %d minutes; %d calls (%.0f a second), %s microseconds a call on average: %s at "
		.. "rest, %s while sliding (%d calls); longest call %.0f ms%s", C.slides, EVERY // 60, C.calls, C.calls / EVERY,
		per_call(C.busy, C.calls), per_call(C.busy - C.slide_busy, C.calls - C.slide_calls),
		per_call(C.slide_busy, C.slide_calls), C.slide_calls, C.longest * 1000,
		C.errors > 0 and string.format(", %d errors", C.errors) or "")
	C.slides, C.calls, C.busy, C.slide_calls, C.slide_busy, C.errors, C.longest = 0, 0, 0, 0, 0, 0, 0
end

return M
