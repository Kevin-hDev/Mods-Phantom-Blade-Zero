-- Each jump in detail, for trials in game: the jump's line, the traversals and animations as they change, Circle's
-- marks and the end of our actions (vault_jump.lua, vault_watch.lua). Off in a published build: then nothing is read,
-- built or written for it. Its lines have a limit of their own, so the events main.lua writes are never crowded out.
-- The test turns it on to read the jumps.

local M = { on = false, MAX_LINES = 5000 }

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
		T.write("detail limit reached (%d lines): the jumps are no longer written in detail", M.MAX_LINES)
	end
end

return M
