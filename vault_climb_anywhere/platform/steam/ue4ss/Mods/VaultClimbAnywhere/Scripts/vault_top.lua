-- The obstacle's top, its front edge, its depth and the shape of its face. Against a face that leans back, a trace
-- down a little past the face lands on the face itself, and the obstacle then reads as going on above. So the top is
-- followed forward, STEP cm at a time, while each step lands at least FACE_RISE cm higher: still the face. The top is
-- looked for past the face's highest hit, and the traces down start just above that hit (T.face); against a face
-- leaning over the character, past its foot instead; and from higher up when a trace down starts inside the obstacle
-- (first_down).

local Measure = require("vault_measure")
local Settings = require("vault_settings")

local T = {}

local THIN = 3                    -- cm past the face's highest hit where the top is looked for: a fence that thin
local STEP = 10                   -- cm between two traces down along the face or the top
-- cm higher per STEP, or more: still the face, leaning back up to 0.625 cm per cm (MAX_LEAN); less, the top or a
-- slope to walk.
local FACE_RISE = 16
local LEVEL = 3                   -- cm: two points of a top this close in height are on the same flat top
-- steps followed past the face's highest hit: a bound, since a walk cannot climb above the height its traces start at.
local MAX_WALK = 6
local MAX_BACK = 150              -- cm: a top edge deeper than this behind the face's foot is a slope's
local MAX_LEAN = 0.6              -- cm back per cm up: up to about 31° from upright, still a face to climb
local MAX_OVERHANG = 0.3          -- cm forward per cm up: a face leaning over the character more than about 17°
local JOIN = 10                   -- cm a face may step between two heights and still be one face (a rock)
local STEEP = 0.5                 -- a face met at one height counts as a wall when its normal's height is below this
local MAX_DEPTH = 200             -- cm: no back edge within this, the top is a platform
local EDGE = 30                   -- cm above and below the top that a trace down onto it covers
local INSIDE = 1                  -- cm: a trace down that hits within this of its start started inside the obstacle

-- Whether hit b, above hit a, is on the same face: no further back than MAX_LEAN allows, no further forward than
-- MAX_OVERHANG allows, give or take JOIN.
local function same_face(a, b)
	local dh, dd = b.h - a.h, b.dist - a.dist
	return dd <= MAX_LEAN * dh + JOIN and dd >= -MAX_OVERHANG * dh - JOIN
end

local function down(scene, d, from)
	return Measure.trace(scene, Measure.at(scene.loc, scene.dx, scene.dy, d, scene.feet + from),
		Measure.at(scene.loc, scene.dx, scene.dy, d, scene.feet + Measure.DROP_TO), scene.channel)
end

-- The first trace down at d, and the height it started from: from, or, while the trace starts inside the obstacle,
-- each measured height above it, then DROP_FROM. The engine then hits at the very start: under a face sticking out,
-- a platform's top was read at the height the trace started from. False when it starts inside all the way up.
local function first_down(scene, d, from)
	local starts = { from }
	for _, h in ipairs(Measure.HEIGHTS) do
		if h > from then starts[#starts + 1] = h end
	end
	if from < Measure.DROP_FROM then starts[#starts + 1] = Measure.DROP_FROM end
	for _, start in ipairs(starts) do
		local hit = down(scene, d, start)
		if not (hit and hit.dist < INSIDE) then return hit, start end
	end
	return false, from
end

-- The face from its foot up, as the horizontal traces met it: each next hit on the same face, with one height without
-- a hit allowed between two (between the bars of a railing). Returns its highest hit, and the first height above it
-- where the face was not met, which the traces down start from: from 5.5 m, they met a roof 4 to 5 m above railings
-- at a drop's edge and read it as the top.
function T.face(scene, foot)
	local by_h = {}
	for _, hit in ipairs(scene.face) do by_h[hit.h] = hit end
	local last, gap = foot, nil
	for _, h in ipairs(Measure.HEIGHTS) do
		if h > foot.h then
			local hit = by_h[h]
			if hit ~= nil and same_face(last, hit) then
				last, gap = hit, nil
			elseif hit == nil and gap == nil then
				gap = h
			else
				return last, gap or h
			end
		end
	end
	return last, gap or Measure.DROP_FROM
end

-- The top as { z, normal, hit, edge, probe, from }: hit, the trace down that found it (Measure.object says what it
-- touched); edge, the front edge's distance from the character along the facing; probe, how far past the edge the
-- top was found; from, the height the traces down started at. Else nil and why. A face leaning back more than
-- BEYOND cm is refused when the player does not climb those (vault_settings.lua). Against a face leaning over the
-- character, the top is looked for BEYOND cm past the face's foot, its edge there: past its highest hit, the traces
-- down met mouldings 6 to 20 cm under the top, and the climb was refused for no room on top.
function T.find(scene)
	local foot = scene.first
	local high, from = T.face(scene, foot)
	if not Settings.ClimbLeaning and high.dist - foot.dist > Measure.BEYOND then return nil, "front leans back" end
	local over = high.dist < foot.dist - JOIN
	local d = over and foot.dist + Measure.BEYOND or high.dist + THIN
	local hit
	hit, from = first_down(scene, d, from)
	if hit == nil then return nil, "a trace call failed" end
	if not hit or hit.z == nil or hit.z < scene.feet + high.h then return nil, "top not found" end
	local edge = over and foot.dist or high.dist
	for walked = 0, MAX_WALK do
		local n = down(scene, d + STEP, from)
		if n == nil then return nil, "a trace call failed" end
		local rise = n and n.z and n.z - hit.z or nil
		if rise == nil or rise < FACE_RISE then
			if rise ~= nil and rise > LEVEL then
				hit, edge, d = n, d + STEP / 2, d + STEP -- higher still: the top starts between the two points
			elseif rise ~= nil and rise >= -LEVEL then
				if walked > 0 then edge = d - STEP / 2 end -- level: the top started before this point
			elseif walked > 0 then
				edge = d -- down behind a thin top: its edge here
			end
			break
		end
		if walked == MAX_WALK then return nil, "top too far back" end
		hit, d = n, d + STEP
	end
	if edge - foot.dist > MAX_BACK then return nil, "top too far back" end
	return { z = hit.z, normal = hit.normal, hit = hit, edge = edge, probe = d - edge, from = from }
end

-- Why the face is not one to climb, or nil. Its lean comes from the plan channel's hits from the foot of the face up
-- to the top, while each next one stays on the same face: one point's normal says little on a rock (a face met at
-- 68 cm from every height between 15 cm and 2 m was refused as not a wall). Met at one height only, the face's
-- normal decides.
function T.wall(scene, top)
	local foot, last = nil, nil
	for _, hit in ipairs(scene.face or {}) do
		if scene.feet + hit.h >= top then break end
		if foot == nil then
			if hit == scene.first then foot, last = hit, hit end
		else
			if not same_face(last, hit) then break end
			last = hit
		end
	end
	if foot ~= nil and last ~= foot then
		local lean = (last.dist - foot.dist) / (last.h - foot.h)
		if lean > MAX_LEAN then return "front not a wall" end
		if lean < -MAX_OVERHANG then return "front leans over" end
		return nil
	end
	local n = scene.first.normal
	if n ~= nil and math.abs(n.z) > STEEP then return "front not a wall" end
	return nil
end

-- The obstacle's surface around height z at a point, on the plan's channel: a hit, false, or nil (call failed).
function T.surface(scene, p, z)
	return Measure.trace(scene, { X = p.X, Y = p.Y, Z = z + EDGE }, { X = p.X, Y = p.Y, Z = z - EDGE }, scene.channel)
end

-- Where the top ends, going in past the point where it was found: the back edge's distance from the front, or nil
-- (a platform); else nil and why.
function T.depth(scene, front, dir, top, probe)
	for s = probe + STEP, MAX_DEPTH, STEP do
		local t = T.surface(scene, Measure.along(front, dir, s, top), top)
		if t == nil then return nil, "a trace call failed" end
		if t == false then return s - STEP / 2 end
	end
	return nil
end

return T
