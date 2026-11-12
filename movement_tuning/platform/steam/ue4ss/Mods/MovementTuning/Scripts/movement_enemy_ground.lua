-- Each near enemy's walk at Enemy movement: its speed allowed (MaxWalkSpeed) and its legs (its mesh's
-- GlobalAnimRateScale) at the game's own times the speed, held over the game's values (movement_held.lua; the game
-- rewrites the speed allowed every frame, verified in game with EnemyProbe). The legs follow the speed both ways so that
-- the enemies never slide (Kevin, 12 November 2026), only on the ground, moving and without a montage (an attack or a
-- reaction plays at its own pace): EnemyProbe's way, tried in game the same day. An enemy standing still or far away,
-- or the setting back at 1, gets the game's values back.

local U = require("movement_unreal")
local Held = require("movement_held")

local M = {}

local MOVING = 30    -- cm/s: slower is standing

-- Enemy frames with the speed held, and with the legs held, since the last status line.
local C = { walks = 0, legs = 0 }

local function cmc_of(actor) return actor.CharacterMovement end
local function mesh_of(actor) return actor.Mesh end
local function mode_of(cmc) return cmc.MovementMode end

-- A component of the enemy, read once it is valid: an actor's components last as long as it does, and the actor is
-- checked valid each frame before they are read.
local function part(actor, read)
	local ok, v = pcall(read, actor)
	return ok and U.is_valid(v) and v or nil
end

-- Gives the enemy the game's values back where the mod's are still in place. Called for one standing still, far away,
-- let go by movement_enemy_list.lua, or as the part stops.
function M.release(e)
	local g = e.g
	if g == nil or not (Held.holding(g.speed) or Held.holding(g.legs)) then return end
	-- Gone, its components are not read: they are gone with it.
	local alive = U.is_valid(e.actor)
	Held.release(g.speed, alive and g.cmc or nil)
	Held.release(g.legs, alive and g.mesh or nil)
end

local function walk(e, rate)
	if not U.is_valid(e.actor) then return end
	local g = e.g
	if g == nil then
		g = { speed = Held.new(), legs = Held.new() }
		e.g = g
	end
	g.cmc = g.cmc or part(e.actor, cmc_of)
	g.mesh = g.mesh or part(e.actor, mesh_of)
	if g.cmc == nil then return end
	local _, _, moving = U.velocity(g.cmc)
	if moving == nil or moving < MOVING then return M.release(e) end
	if Held.hold(g.speed, g.cmc, "MaxWalkSpeed", rate) then C.walks = C.walks + 1 end
	local mode = nil
	pcall(function() mode = U.num(mode_of(g.cmc)) end)
	if g.mesh ~= nil and mode == U.WALKING and U.montage_plays(g.mesh) == false then
		if Held.hold(g.legs, g.mesh, "GlobalAnimRateScale", rate) then C.legs = C.legs + 1 end
	else
		Held.release(g.legs, g.mesh)
	end
end

-- list: the enemies kept (movement_enemy_list.lua), valid at the last look. rate: Enemy movement's speed.
function M.frame(list, rate)
	for _, e in pairs(list) do
		if e.near and rate ~= 1 then
			walk(e, rate)
		else
			M.release(e)
		end
	end
end

-- For the status line, since the last call.
function M.report()
	local walks, legs = C.walks, C.legs
	C.walks, C.legs = 0, 0
	return walks, legs
end

return M
