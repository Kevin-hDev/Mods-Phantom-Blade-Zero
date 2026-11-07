-- The air jumps and the landing, called only while the mod is on.
-- In the air, each new press of the chosen button plays the game's second dodge, then its third, then the second
-- again, each with a push up, as many times as the limit allows (DodgeProbe, 3 November 2026: these two dodges are
-- the jump-like ones of an R1 chain, and they play in the air). Only a press that starts in the air counts: a button
-- already held at takeoff waits for its release.
-- On landing, a dodge of ours still playing is stopped: it goes on 0.8 to 1.1 s on the ground (landing delay
-- enquiry, 3 November 2026), and nothing of it belongs on the ground.
-- The second dodge starts past its first 0.20 s: a crouch made for a character still on the ground, which showed in
-- the air (Kevin, 4 November 2026). DodgePoseProbe, same day, 9 double jumps: both feet stay at ground height while
-- the hips bend, and the first foot leaves it at 0.186 to 0.202 s; the montage blends in over 0.1 s from the pose in
-- the air. The third dodge has no ground stance to skip: in the air its hips stay at least 16 units above the
-- character's centre, and its feet are never both down.
-- Each air jump first turns the character to where the stick points, so the dodge's own movement goes that way: the
-- game does the same on the ground when its first dodge starts, and the chained ones follow the facing (DodgeDirProbe,
-- 4 November 2026, asked by a player on Nexus). Turned by the probe in the air, 8 jumps out of 8 went the stick's way.
-- Without a direction, nothing turns. The camera is never touched.
-- Each dodge plays at the speed setting's rate (1.0.5, asked by Kevin on 5 November 2026).
-- A dodge played by the mod has no timeline of the game's abilities to drive it, unlike the game's own dodges
-- (MoveProbe, 4 November 2026: a faster montage did not speed those up); here the montage's own motion carries the
-- character, and a faster montage covers its own ground sooner (traces of 5 November 2026: about 530 units for the
-- whole third dodge at 2, 2.5 and 3). The time in the air does not change, and what is left of it after the dodge
-- glides on: a faster jump goes farther. How the dodge ends: dodge_jump_exit.lua.

local U = require("dodge_jump_unreal")
local Keys = require("dodge_jump_keys")
local Objects = require("dodge_jump_objects")
local Sound = require("dodge_jump_sound")
local Exit = require("dodge_jump_exit")

local M = {}

M.DODGES = {
	"/HuaShira/Characters/Hero/Hero_Hun/Animation/Dash/Hun_TangBlade_Dash_F_Continuous_02_Montage.Hun_TangBlade_Dash_F_Continuous_02_Montage",
	"/HuaShira/Characters/Hero/Hero_Hun/Animation/Dash/Hun_TangBlade_Dash_F_Continuous_03_Montage.Hun_TangBlade_Dash_F_Continuous_03_Montage",
}
-- Seconds into each dodge where its air jump starts, in the order of M.DODGES.
M.START_AT = { 0.20, 0 }
-- Units/s up, the push tried and kept with the probe (session 2 of the dodge enquiry, 3 November 2026).
local LAUNCH_Z = 700
local MONTAGE_LENGTH = 0          -- EMontagePlayReturnType::MontageLength
local MIN_INPUT = 0.3             -- a stick barely pushed is not a direction (the input is 1 when fully pushed)

local A = { count = 0, down = {}, played = false, missing_logged = false, failed_logged = false,
	start_logged = false, turn_logged = false }

local function montage(i)
	return Objects.find(M.DODGES[i], Objects.MONTAGE)
end

-- The buttons held now are not new presses.
function M.hold(controller, keys)
	Keys.hold(controller, keys, A.down)
end

-- Takeoff: the count starts over.
function M.takeoff(controller, keys)
	A.count, A.played = 0, false
	Exit.reset()
	M.hold(controller, keys)
end

local function turn(pawn, yaw)
	return pcall(function() pawn:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false) end)
end

-- The movement input is the stick turned into a world direction, camera included. Returns the yaw the character was
-- turned from, or nil when it was not turned.
local function face_input(pawn, log)
	local yaw, before = nil, nil
	pcall(function()
		local v = pawn:GetLastMovementInputVector()
		local x, y = U.num(v.X), U.num(v.Y)
		if x ~= nil and y ~= nil and x * x + y * y >= MIN_INPUT * MIN_INPUT then yaw = math.deg(math.atan(y, x)) end
	end)
	if yaw == nil then return nil end
	pcall(function() before = U.num(pawn:K2_GetActorRotation().Yaw) end)
	if turn(pawn, yaw) then return before end
	if not A.turn_logged then
		A.turn_logged = true
		log("could not turn the character to the stick: the jump goes where it faces; said once")
	end
	return nil
end

-- Montage_Play is what PlayAnimMontage calls, with a start time; 0 back means the game did not play it.
local function play_from(pawn, m, start_at, rate)
	local anim, length = nil, nil
	pcall(function() anim = pawn.Mesh:GetAnimInstance() end)
	if U.is_valid(anim) then
		pcall(function() length = U.num(anim:Montage_Play(m, rate, MONTAGE_LENGTH, start_at, true)) end)
	end
	return length ~= nil and length > 0
end

-- A dodge that cannot start past its crouch still plays, from its start, as before 1.0.3.
local function play(pawn, m, start_at, rate, log)
	if start_at > 0 then
		if play_from(pawn, m, start_at, rate) then return true end
		if not A.start_logged then
			A.start_logged = true
			log("could not start the double jump at %.2f s: it plays from its start; said once", start_at)
		end
	end
	-- UE4SS reads whatever it is given for a name as a name, without checking: a nil there is a native crash (crash
	-- audit, 4 November 2026). FName does not fail in practice; the check costs nothing.
	local section = Keys.fname("None")
	return section ~= nil and pcall(function() pawn:PlayAnimMontage(m, rate, section) end)
end

local function air_jump(pawn, rate, share, log)
	local which = A.count % 2 + 1
	local m = montage(which)
	if m == nil then
		if not A.missing_logged then
			A.missing_logged = true
			log("dodge montage %d not found: no air jump until it is", which)
		end
		return false
	end
	local turned_from = face_input(pawn, log)
	local ok = play(pawn, m, M.START_AT[which], rate, log)
	if ok then Exit.start(pawn, m, which, rate, log) end
	-- A dodge the game refused: the character faces back the way it did, a turn without a jump reads as a glitch
	-- (audit of 1.0.4, 4 November 2026).
	if not ok and turned_from ~= nil then turn(pawn, turned_from) end
	ok = ok and pcall(function() pawn:LaunchCharacter({ X = 0, Y = 0, Z = LAUNCH_Z }, false, true) end)
	A.count, A.played = A.count + 1, true
	if ok then Sound.play(pawn, which, share, log) end
	if not ok and not A.failed_logged then
		A.failed_logged = true
		log("the game refused to play a dodge or push the character up; said once")
	end
	return ok
end

-- Each frame in the air, rate the dodges' speed and share their sound's volume (0 to 1). Returns the number of air
-- jumps made this frame.
function M.update(controller, pawn, keys, max_jumps, rate, share, now, log)
	Exit.frame(pawn, now, log)
	if not Keys.pressed(controller, keys, A.down) or A.count >= max_jumps then return 0 end
	return air_jump(pawn, rate, share, log) and 1 or 0
end

-- Landing: true when a dodge of ours was still playing and has been stopped.
function M.landed(pawn, now, log)
	Exit.landed(now, log)
	if not A.played then return false end
	A.played = false
	local active = nil
	pcall(function() active = pawn.Mesh:GetAnimInstance():GetCurrentActiveMontage() end)
	if not U.is_valid(active) then return false end
	local addr = U.address(active)
	for i = 1, #M.DODGES do
		local m = montage(i)
		if m ~= nil and U.address(m) == addr then
			return (pcall(function() pawn:StopAnimMontage(active) end))
		end
	end
	return false
end

return M
