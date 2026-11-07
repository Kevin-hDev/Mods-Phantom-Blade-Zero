-- Each slide in detail, for the trials in game: its start, a line every 0.1 s, its end and the lean's summary
-- (slide_run.lua, slide_tilt.lua and what they call). A trial build turns it on; a published build leaves it off, and
-- then nothing is read, built or written for it (optimisation.md, rule 8.2). Its lines have a limit of their own, so
-- the events main.lua writes are never crowded out (rule 9.1). The test turns it on to read the slides.

local M = { on = false, MAX_LINES = 20000 }

local T = { lines = 0, write = nil }

-- write(fmt, ...): main.lua's line writer.
function M.start(write)
	T.write = write
end

-- Whether a detail line may be written now: callers build its text, and gather what it sums up, only then.
function M.open()
	return M.on and T.lines < M.MAX_LINES and T.write ~= nil
end

function M.say(fmt, ...)
	if not M.open() then return end
	T.lines = T.lines + 1
	T.write(fmt, ...)
	if T.lines == M.MAX_LINES then
		T.write("detail limit reached (%d lines): the slides are no longer written in detail", M.MAX_LINES)
	end
end

return M
