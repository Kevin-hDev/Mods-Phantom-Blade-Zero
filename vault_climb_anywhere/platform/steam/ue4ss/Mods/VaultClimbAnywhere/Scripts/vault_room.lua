-- Whether the character has room: on the top, on the way up, at his sides, and below whatever of the obstacle goes on
-- above; and whether the face starts above an opening he walks through. What would be in the way is read on the
-- visibility channel, which sees everything; what holds him up, on the vaulting's channel (vault_top.lua).

local Measure = require("vault_measure")
local Top = require("vault_top")

local M = {}

local ABOVE = 30                  -- cm over the top from which something ahead belongs to a taller obstacle
-- cm over a character standing on the top still counted as in his way. Higher, a roof or a branch does not stop the
-- climb: a 1.8 m step was refused for something 4 m above the character's feet.
local HEADROOM = 20
-- cm each side of the way in where the top must hold too: a post or a trunk does not, nor a corner taken too close.
local SIDE = 15
local LEVEL = 15                  -- cm: a side point this close in height to the top is on the same top
-- cm past the face's foot within which something met lower holds the face up: its own wall, a table's legs, a
-- railing's bars. Further, it is a room behind an opening.
local NEAR = 50

local function trace(scene, a, b)
	return Measure.trace(scene, a, b, Measure.VISIBILITY)
end

-- Why the character does not fit on the top or cannot get there, or nil: something just above it, or in the way
-- above its front.
function M.blocked(scene, front, dir, top)
	local room = trace(scene, Measure.along(front, dir, Measure.BEYOND, top + 2),
		Measure.along(front, dir, Measure.BEYOND, top + 2 * scene.half))
	if room == nil then return "a trace call failed" end
	if room then return "no room on top" end
	local clear = trace(scene, { X = scene.loc.x, Y = scene.loc.y, Z = top + scene.half },
		Measure.along(front, dir, Measure.BEYOND, top + scene.half))
	if clear == nil then return "a trace call failed" end
	if clear then return "blocked above the top" end
	return nil
end

-- Whether the face read as the obstacle (scene.first) starts above an opening the character walks through standing:
-- no horizontal trace lower than its foot meets anything within NEAR of it, on either channel, and the highest of
-- those traces is at his height or more (without this, a jump toward a door climbed onto the roof: the traces above
-- the door met the wall over it). A table, a counter or a railing, which he does not walk under
-- standing, stays an obstacle.
function M.opening(scene)
	local foot, highest = scene.first, nil
	for _, h in ipairs(Measure.HEIGHTS) do
		if h >= foot.h then break end
		highest = h
	end
	if highest == nil or highest < 2 * scene.half then return false end
	for _, hits in ipairs({ scene.ahead, scene.face }) do
		for _, hit in ipairs(hits) do
			if hit.h < foot.h and hit.dist <= foot.dist + NEAR then return false end
		end
	end
	return true
end

-- Whether the obstacle goes on above its top, over the way the character would take and within the height he needs
-- standing there: the eye's horizontal hits (vault_measure.lua) more than ABOVE cm over the top, up to his height and
-- HEADROOM over the top, nearer than reach.
function M.goes_on(scene, top, reach)
	local roof = top + 2 * scene.half + HEADROOM
	for _, hit in ipairs(scene.ahead or {}) do
		local z = scene.feet + hit.h
		if z > top + ABOVE and z <= roof and hit.dist < reach then return true end
	end
	return false
end

-- For a mantle, why the top cannot hold the character at his sides, or nil: SIDE cm left and right of the point where
-- the top was found, the top must be there at the same height, and nothing may stand across it at his middle (a
-- pillar, the walls of a narrow gap).
function M.narrow(scene, front, dir, top, probe)
	local at = Measure.along(front, dir, probe, top)
	local sx, sy = -dir.y * SIDE, dir.x * SIDE
	for _, sign in ipairs({ -1, 1 }) do
		local t = Top.surface(scene, { X = at.X + sx * sign, Y = at.Y + sy * sign }, top)
		if t == nil then return "a trace call failed" end
		if not t or t.z == nil or math.abs(t.z - top) > LEVEL then return "too narrow to stand on" end
	end
	local mid = top + scene.half
	local across = trace(scene, { X = at.X - sx, Y = at.Y - sy, Z = mid }, { X = at.X + sx, Y = at.Y + sy, Z = mid })
	if across == nil then return "a trace call failed" end
	if across then return "no room at the sides" end
	return nil
end

return M
