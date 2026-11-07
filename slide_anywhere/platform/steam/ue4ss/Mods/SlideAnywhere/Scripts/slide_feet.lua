-- The player's two feet and their toes, for the tilt (slide_tilt.lua): their bones, found once per character by name,
-- and where they are in the actor's space as if the mesh were not tilted. The pose is read in the mesh's own space
-- (our tilt does not change it), then placed by the mesh's untilted place in the actor. This game's feet are foot_l
-- and foot_r (sixth trial, seen in game), its toes ball_l and ball_r (essai-glissade-14 onward, seen in game).

local R = require("slide_reading")
local Math = require("slide_tilt_math")

local M = {}

local RTS_COMPONENT = 2           -- ERelativeTransformSpace: the mesh's own space
local MAX_BONES = 1024
local MAX_NAMES_SAID = 16
local MIN_APART = 1               -- cm: two feet read at the same point were not read
-- Bones that follow a foot without being it: IK targets, twist and roll helpers, toes, end points.
local NOT_A_FOOT = { ik = true, twist = true, roll = true, ball = true, toe = true, toes = true, ["end"] = true,
	nub = true, socket = true, target = true, pole = true, ctrl = true }

local function words(name)
	local list = {}
	for w in name:lower():gsub("[_%.%-]", " "):gmatch("%S+") do list[#list + 1] = w end
	return list
end

-- "l" or "r" when the name is a plain foot bone (foot_l, Bip001 R Foot, LeftFoot, foot.R), else nil; with toe, a
-- plain toe bone instead (ball_l, Bip001 L Toe0).
function M.side(name, toe)
	local lower = name:lower()
	if toe then
		if lower:find("foot") or not (lower:find("ball") or lower:find("toe")) then return nil end
	elseif not lower:find("foot") then
		return nil
	end
	local side = nil
	for _, w in ipairs(words(name)) do
		if NOT_A_FOOT[w] and not (toe and (w == "ball" or w:find("^toe"))) then return nil end
		if w == "l" or w:find("^left") then side = "l" end
		if w == "r" or w:find("^right") then side = "r" end
	end
	return side
end

-- Returns { l, r, l_name, r_name, lt, rt } (bones as FNames, names as text, toes as FNames or nil), or nil when the
-- two feet are not both found.
function M.find(say, mesh)
	local count = 0
	pcall(function() count = R.num(mesh:GetNumBones(), 0) end)
	local best, toes, seen = {}, {}, {}
	for i = 0, math.min(count, MAX_BONES) - 1 do
		local name = nil
		pcall(function() name = mesh:GetBoneName(i):ToString() end)
		if type(name) == "string" and name:lower():find("foot") then
			if #seen < MAX_NAMES_SAID then seen[#seen + 1] = name end
			local side = M.side(name)
			if side ~= nil and (best[side] == nil or #name < #best[side]) then best[side] = name end
		end
		local toe = type(name) == "string" and M.side(name, true) or nil
		if toe ~= nil and (toes[toe] == nil or #name < #toes[toe]) then toes[toe] = name end
	end
	if best.l ~= nil and best.r ~= nil then
		say("feet: %s and %s, toes %s and %s (of %d bones)", best.l, best.r, toes.l or "none", toes.r or "none", count)
		return { l = FName(best.l), r = FName(best.r), l_name = best.l, r_name = best.r,
			lt = toes.l and FName(toes.l), rt = toes.r and FName(toes.r) }
	end
	say("feet not found among %d bones (foot names: %s): no tilt", count,
		#seen > 0 and table.concat(seen, ", ") or "none")
	return nil
end

-- base: the mesh's untilted place in the actor, { loc, scale, m } (slide_mesh.lua).
function M.to_actor(c, base)
	local v = Math.apply({ x = c.x * base.scale.x, y = c.y * base.scale.y, z = c.z * base.scale.z }, base.m)
	return Math.add(v, base.loc)
end

local function own_space(mesh, bone)
	local v = nil
	pcall(function() v = R.vec(mesh:GetSocketTransform(bone, RTS_COMPONENT).Translation) end)
	return v
end

-- Both feet in the actor's space without the tilt, or nil when they cannot be read; then their toes, each nil when
-- not found or not read.
function M.read(mesh, feet, base)
	local l, r = own_space(mesh, feet.l), own_space(mesh, feet.r)
	if l == nil or r == nil then return nil end
	local gap = Math.sub(l, r)
	if Math.dot(gap, gap) < MIN_APART * MIN_APART then return nil end
	local lt, rt = feet.lt and own_space(mesh, feet.lt), feet.rt and own_space(mesh, feet.rt)
	return M.to_actor(l, base), M.to_actor(r, base), lt and M.to_actor(lt, base), rt and M.to_actor(rt, base)
end

-- A foot in the world, tilt included: what the player sees.
function M.world(mesh, bone)
	local v = nil
	pcall(function() v = R.vec(mesh:GetSocketLocation(bone)) end)
	return v
end

return M
