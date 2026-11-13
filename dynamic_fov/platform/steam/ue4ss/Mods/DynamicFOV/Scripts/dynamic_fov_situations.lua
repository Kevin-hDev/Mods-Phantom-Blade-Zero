-- Which situation a camera mode is, by its gameplay tag: the setting its field of view takes (four) and the situation
-- its place takes (five, 1.0.11). The only file that says so: the modes' values (dynamic_fov_modes.lua) and the
-- camera's layer (dynamic_fov_layer.lua) both ask here.
--
-- Seen in play with CameraProbe: ShoulderDefault (standing, walking, running, climbing), Sprint, Crouch, Combat (an
-- enemy near, none locked on: it stays after unlocking, until the player walks away, seen in play on 5 November 2026;
-- CameraProbe also saw it while sprinting, but a sprint among enemies is Sprint in the trial of 13 November 2026)
-- and Combat.Focus (enemy locked on). For the field of view, Combat follows
-- the normal view, so unlocking changes the view at once; for the place it is a situation of its own (1.0.11: a
-- player who fights several enemies without locking on wants the camera farther then, and close when walking).
-- One enemy's own combat view (Custom) is seen in play, CameraType.Combat.Custom.PengMeng (the mod's first write to
-- it, 4 November 2026); that each is the view of its kind is not verified. Each follows its kind, so the view does
-- not change from one boss to the next. WeakLockNext is a combat view the game turns to now and then, no enemy locked
-- on: left alone, the mod took the camera's place away and the field of view went back to the game's 75 for one to
-- three seconds, and the camera jumped (seen in play on 5 November 2026); it follows Combat. What brings it in play
-- is not verified.

local M = {}

local NORMAL = { fov = "normal", place = "normal" }
local SPRINT = { fov = "sprint", place = "sprint" }
local CROUCH = { fov = "crouch", place = "crouch" }
local COMBAT = { fov = "normal", place = "combat" }
local LOCK_ON = { fov = "lock_on", place = "lock_on" }

local EXACT = {
	["CameraType.ShoulderDefault"] = NORMAL,
	["CameraType.Sprint"] = SPRINT,
	["CameraType.Crouch"] = CROUCH,
	["CameraType.Combat"] = COMBAT,
	["CameraType.WeakLockNext"] = COMBAT,
	["CameraType.Combat.Focus"] = LOCK_ON,
}
-- { prefix, situation }: neither prefix starts the other.
local PREFIXES = { { "CameraType.Combat.Custom.", COMBAT }, { "CameraType.Combat.Focus.Custom.", LOCK_ON } }

local function of(tag)
	if tag == nil then return nil end
	if EXACT[tag] ~= nil then return EXACT[tag] end
	for _, p in ipairs(PREFIXES) do
		if tag:sub(1, #p[1]) == p[1] then return p[2] end
	end
	return nil
end

-- The setting a mode's field of view takes, or nil for a mode the mod leaves alone.
function M.setting_of(tag)
	local situation = of(tag)
	return situation and situation.fov
end

-- The situation a mode's place takes, or nil for a mode the mod leaves alone: the same modes as above.
function M.place_of(tag)
	local situation = of(tag)
	return situation and situation.place
end

return M
