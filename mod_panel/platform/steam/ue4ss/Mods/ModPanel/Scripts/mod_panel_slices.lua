-- Work cut in slices, so that no frame does more of it than a budget (optimisation.md, 7.1; D38): a step at least,
-- then the next one only while it would still fit, its cost guessed from the longest step seen so far. The reading of
-- the mods, the frame's build and the reserve's all go through here.

local M = {}

-- step() does the next step and returns true once no step is left. s keeps the longest step from one slice to the
-- next ({ longest = 0 } to begin with). Returns whether all is done.
function M.run(step, budget, s)
	local start = os.clock()
	repeat
		local before = os.clock()
		if step() then return true end
		s.longest = math.max(s.longest, os.clock() - before)
	until os.clock() - start + s.longest > budget
	return false
end

return M
