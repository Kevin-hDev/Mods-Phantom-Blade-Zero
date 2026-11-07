-- The tap strafe itself, called only while the player is in the air: each frame the momentum turns by as much as the
-- camera turned since the last frame, its length and vertical part kept, and the body turns with it (in the air the
-- game never turns it, TapProbe, 16 jumps). The camera itself is never touched.
-- It never aims at a direction: letting go of the movement keys or the stick never changes the jump's direction, only a
-- camera turn does (design rule, 3 November 2026). One strength only, the jump turning exactly as much as the camera;
-- why the others were dropped is in the design notes.
-- Locked on an enemy: nothing. In free run the passive rotation target is always RotationTargetProvider_LastMoveInput
-- (2 052 samples in the air, probes of 3 November 2026); any other class counts as locked.

local U = require("tap_strafe_unreal")

local M = {}

local FREE_CLASS = "lastmoveinput"
local MIN_SPEED = 50              -- units/s: below it there is no momentum to turn (a jump on the spot)
local STILL = 0.01                -- degrees: a smaller camera turn counts as none
local MAX_CLASSES_LOGGED = 8

local lock = { addr = nil, free = false, logged = {}, count = 0 }
local last_cam = nil

-- Each jump or fall starts from the camera where it is: turns made before it are not carried into it.
function M.new_jump()
	last_cam = nil
end

-- New pawn: its rotation target is a new object.
function M.forget()
	lock.addr = nil
	M.new_jump()
end

local function wrap(a)
	return (a + 180) % 360 - 180
end

-- The class is read only when the rotation target object changes, not every frame. UE4SS's GetClass crashes the game
-- on an empty object, past any pcall: validity first. A class that could not be read is not remembered, so the next
-- frame tries again instead of staying locked for the life of that object.
local function free(cmc, log)
	local target = nil
	pcall(function() target = cmc.CurrentPassiveRotationTargetProvider end)
	if not U.is_valid(target) then
		lock.addr = nil
		return false
	end
	local addr = U.address(target)
	if addr ~= nil and addr == lock.addr then return lock.free end
	local name = nil
	pcall(function() name = target:GetClass():GetFName():ToString() end)
	if type(name) ~= "string" then
		lock.addr = nil
		return false
	end
	lock.addr, lock.free = addr, name:lower():find(FREE_CLASS, 1, true) ~= nil
	if lock.logged[name] == nil and lock.count < MAX_CLASSES_LOGGED then
		lock.logged[name], lock.count = true, lock.count + 1
		log("rotation target %s: %s", name, lock.free and "free run, turning on" or "counted as locked, turning off")
	end
	return lock.free
end

local function turn_body(pawn, step)
	pcall(function()
		local body = U.num(pawn:K2_GetActorRotation().Yaw)
		if body ~= nil then pawn:K2_SetActorRotation({ Pitch = 0, Yaw = body + step, Roll = 0 }, false) end
	end)
end

-- Returns "locked", "turned", or nil when nothing was turned.
function M.update(controller, pawn, cmc, log)
	if not free(cmc, log) then
		M.new_jump()
		return "locked"
	end
	local cam = nil
	pcall(function() cam = U.num(controller:GetControlRotation().Yaw) end)
	if cam == nil then return nil end
	local step = last_cam == nil and 0 or wrap(cam - last_cam)
	last_cam = cam
	if math.abs(step) < STILL then return nil end
	local vx, vy, vz = nil, nil, nil
	pcall(function()
		local v = cmc.Velocity
		vx, vy, vz = U.num(v.X), U.num(v.Y), U.num(v.Z)
	end)
	if vx == nil or vy == nil or vz == nil then return nil end
	local speed = math.sqrt(vx * vx + vy * vy)
	if speed < MIN_SPEED then return nil end
	local rad = math.rad(math.deg(math.atan(vy, vx)) + step)
	if not pcall(function() cmc.Velocity = { X = math.cos(rad) * speed, Y = math.sin(rad) * speed, Z = vz } end) then
		return nil
	end
	turn_body(pawn, step)
	return "turned"
end

return M
