-- Where a leaning slide's planted foot goes (slide_tilt.lua), as heights along the floor's normal above the mesh's
-- origin. Above the origin, not the actor: crouching, the game moves the mesh in the actor (ACharacter::OnStartCrouch),
-- and the ground moves with it. A leaning slide turns the game's foot placement off (slide_placement.lua), so nothing
-- puts its feet on the ground any more: the eighth trial (essai-glissade-13) left the front leg in the ground.
-- The ankle goes PLANTED_ANKLE above the origin, whatever was read while running. The ninth version put it at the
-- lowest ankle of the last readings: that went from -9 to +9 cm from one slide to the next (essai-glissade-14 and -15),
-- lowest where the game put the running feet below the floor the character walks on (a ramp near x -59000 y 238000),
-- read about 5 m before the slide; Kevin saw about one slide in four sunk into the ground ("des fois ... plus enfoncé
-- dans le sol alors que 75% du temps c'est pas le cas").
-- The toe goes no lower below its ankle than it was read while running: the readings keep the lower foot of the two
-- every EVERY s while the player is on the ground and no slide leans, and the one whose ankle was lowest, the foot
-- flat on the floor, gives the drop. Ankle and toe come from the same reading, so the floor's height cancels out.

local R = require("slide_reading")
local Math = require("slide_tilt_math")
local Mesh = require("slide_mesh")
local Feet = require("slide_feet")

local M = {}

local EVERY = 0.1                 -- s
local SAMPLES = 6                 -- 0.6 s: a few running strides, so a stride's flight does not count
-- cm: the most frequent reading of the ninth and tenth versions (14 of the 62 slides of essai-glissade-14 and -15,
-- 23 between 7 and 9).
local PLANTED_ANKLE = 8

local G = { t = 0, seen = {} }

-- True once every EVERY s: the feet are read only then.
function M.due(dt)
	G.t = G.t + dt
	if G.t < EVERY then return false end
	G.t = 0
	return true
end

-- l, r, lt, rt: both feet and their toes (a toe nil when not found) in the actor's space, untilted; n: the floor's
-- normal in the actor's space; origin: the mesh's untilted place in the actor.
function M.add(l, r, lt, rt, n, origin)
	local function h(v) return Math.dot(Math.sub(v, origin), n) end
	local hl, hr = h(l), h(r)
	local ankle, toe = hr, rt
	if hl <= hr then ankle, toe = hl, lt end
	G.seen[#G.seen + 1] = { ankle = ankle, toe = toe and h(toe) or nil }
	if #G.seen > SAMPLES then table.remove(G.seen, 1) end
end

local function lowest()
	local m = nil
	for _, p in ipairs(G.seen) do
		if m == nil or p.ankle < m.ankle then m = p end
	end
	return m
end

-- The heights to put the planted ankle and toe at; the toe nil before any reading with a toe.
function M.level()
	local p = lowest()
	if p == nil or p.toe == nil then return PLANTED_ANKLE, nil end
	return PLANTED_ANKLE, PLANTED_ANKLE + p.toe - p.ankle
end

-- For the slide's summary: the planted ankle's height read while running and how far below it its toe was (nil
-- when not read).
function M.read()
	local p = lowest()
	if p == nil then return nil, nil end
	return p.ankle, p.toe and p.ankle - p.toe or nil
end

-- While no slide leans, every EVERY s on the ground: the feet, for where the game puts a planted foot. look(): the
-- player's state and the floor's normal in the world, read only then (it was every frame up to 0.1.0, for a cost of
-- 206 µs a frame with the rest, trial of 5 November 2026).
function M.watch(dt, mesh, feet, look)
	if feet == nil or not M.due(dt) or not R.is_valid(mesh) then return end
	local st, normal = look()
	-- No floor normal off the ground (slide_run.lua's floor): the ground is read only on it.
	if normal == nil or st.yaw == nil then return end
	local base = Mesh.base(mesh)
	if base == nil then return end
	local l, r, lt, rt = Feet.read(mesh, feet, base)
	if l ~= nil then M.add(l, r, lt, rt, Math.to_actor(normal, st.yaw), base.loc) end
end

function M.reset()
	G.t, G.seen = 0, {}
end

return M
