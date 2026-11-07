-- The jump pressed too early, kept until the game takes it.
-- Measured (landing delay enquiry, 3 November 2026, seen in game): the game refuses a jump for about 0.25 to 0.30 s
-- after each landing, and a press made then, or just before touching the ground, is lost. The player has to press
-- again, which feels like a wait of one or two seconds. The mod keeps such a press and presses the game's own jump
-- action (IA_Jump) for the player until the game takes it: in game (test of 0.2.0, 3 November 2026), 52 kept
-- presses out of 52 jumped, 0.25 to 0.27 s after landing, as soon as the game allows it.

local U = require("dodge_jump_unreal")
local Keys = require("dodge_jump_keys")
local Objects = require("dodge_jump_objects")

local M = {}

M.JUMP_ACTION = "/PBZInput/InputActions/IA_Jump.IA_Jump"
M.INPUT_SUBSYSTEM = "EnhancedInputLocalPlayerSubsystem"
local INPUT_ACTION = "/Script/EnhancedInput.InputAction"
local BEFORE = 0.2                -- s: a press this close before the landing is kept
local AFTER = 0.35                -- s: a press up to this long after the landing is kept (refused up to 0.25 s)
local GIVE_UP = 0.6               -- s after the landing: a kept press the game has not taken by then is dropped

local L = { down = {}, air_press = nil, landing = nil, kept = false, odd = false, broken = false }
-- Only called, never handed to the game: an object of another class in its place gives a Lua error, not a crash
-- (crash audit, 4 November 2026), so IsValid is enough here.
local subsystem

-- new_pawn: a loaded save or a respawn, after which the jump action may be pressable again.
function M.reset(new_pawn)
	L.air_press, L.landing, L.kept = nil, nil, false
	-- The subsystem is looked up again too: what the last level held may be gone.
	if new_pawn then L.broken, subsystem = false, nil end
end

-- The jump action, or nil when it or the input subsystem is missing.
local function found()
	if not U.is_valid(subsystem) then
		subsystem = nil
		pcall(function() subsystem = FindFirstOf(M.INPUT_SUBSYSTEM) end)
		if not U.is_valid(subsystem) then subsystem = nil end
	end
	if subsystem == nil then return nil end
	return Objects.find(M.JUMP_ACTION, INPUT_ACTION)
end

-- The game's jump action, as if its button had just been pressed. If it cannot be pressed (a game update that renames
-- it, say), presses are no longer kept until the next loaded save or respawn, and the game's jump is as it was.
-- The two lists (modifiers, triggers) stay empty: UE4SS never frees what it puts in them (crash audit).
local function press_jump(log)
	local ok, err = false, "jump action or input subsystem not found"
	local action = found()
	if action ~= nil then
		ok, err = pcall(function()
			subsystem:InjectInputVectorForAction(action, { X = 1.0, Y = 0.0, Z = 0.0 }, {}, {})
		end)
	end
	if ok then return end
	L.broken, L.kept = true, false
	log("cannot press the game's jump action (%s): jumps pressed early are no longer kept", tostring(err))
end

local function keep()
	L.kept, L.odd = not L.broken, false
end

-- The buttons held now are not new presses: at takeoff, and when the settings change (the jump button with them).
function M.hold(controller, keys)
	Keys.hold(controller, keys, L.down)
end

-- Takeoff. Returns true when the game took a kept press.
function M.takeoff(controller, keys)
	local taken = L.kept
	L.landing, L.kept, L.air_press = nil, false, nil
	M.hold(controller, keys)
	return taken
end

-- Each frame in the air. air_jumped: this frame's press made an air jump, so it is not a jump to keep.
function M.air(controller, keys, now, air_jumped)
	if Keys.pressed(controller, keys, L.down) and not air_jumped then L.air_press = now end
end

function M.landed(now)
	L.landing = now
	if L.air_press ~= nil and now - L.air_press <= BEFORE then keep() end
	L.air_press = nil
end

-- Each frame on the ground. Nothing is read once the landing is GIVE_UP seconds old.
function M.ground(controller, keys, now, log)
	if L.landing == nil then return end
	local since = now - L.landing
	if since > GIVE_UP then
		L.landing, L.kept = nil, false
		return
	end
	if Keys.pressed(controller, keys, L.down) and not L.kept and since <= AFTER then keep() end
	if not L.kept then return end
	-- Every other frame: a press held across frames would not be a new press for the game.
	L.odd = not L.odd
	if L.odd then press_jump(log) end
end

return M
