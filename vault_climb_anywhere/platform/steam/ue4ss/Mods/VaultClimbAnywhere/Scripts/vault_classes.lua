-- The engine's classes the mod checks objects against, each found once by its path and checked with IsValid before
-- each use, as the trace library is (vault_measure.lua). UE4SS's IsA given a path looks the class up at each call
-- (StaticFindObject); given the class, it does not. Native classes only, always loaded: never a search for an absent
-- object.

local R = require("vault_reading")

local M = {}

local MAX_CLASSES = 8             -- the mod checks against 3; a bound all the same
local S = { found = {}, count = 0 }

local function find(path) return StaticFindObject(path) end

-- The class at path, or the path itself while it cannot be found: IsA takes both.
function M.get(path)
	local class = S.found[path]
	if R.is_valid(class) then return class end
	local ok, c = pcall(find, path)
	if not ok or not R.is_valid(c) then return path end
	if class == nil then
		if S.count >= MAX_CLASSES then S.found, S.count = {}, 0 end
		S.count = S.count + 1
	end
	S.found[path] = c
	return c
end

return M
