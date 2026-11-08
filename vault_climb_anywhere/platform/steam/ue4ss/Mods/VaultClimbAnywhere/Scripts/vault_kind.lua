-- What the obstacle is, when the engine says: a character, an enemy or a villager, is never climbed onto, and an
-- object the physics moves, a barrel that rolls, would slide away under the character. Read only when the hit's
-- component could be read: most first hits come back unreadable (vault_measure.lua), and refusing those would refuse
-- most climbs. The engine's UActorComponent::GetOwner() and FBodyInstanceCore::bSimulatePhysics are only read.

local R = require("vault_reading")
local Classes = require("vault_classes")

local M = {}

local PAWN = "/Script/Engine.Pawn"

-- Why the hit object cannot be climbed, or nil.
function M.why_not(obj)
	if not R.is_valid(obj) then return nil end
	local pawn = Classes.get(PAWN)
	if R.usable(obj, pawn) or R.usable(R.read(function() return obj:GetOwner() end), pawn) then
		return "a character"
	end
	if R.read(function() return obj.BodyInstance.bSimulatePhysics end) == true then return "an object that moves" end
	return nil
end

return M
