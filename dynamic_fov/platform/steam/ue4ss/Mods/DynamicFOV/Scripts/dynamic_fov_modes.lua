-- The player camera's modes. The camera (NBCameraComponent, Advanced Third Person Camera plugin) switches between 123
-- camera modes and eases itself towards the active mode's field of view, at the mode's transition speed (CameraProbe,
-- 3 November 2026). So for the field of view the mod never calls the camera: it writes the target field of view and
-- the transition speed of the modes it manages, and puts the game's values back when it is off. The view's place goes
-- through the camera itself (dynamic_fov_layer.lua).
--
-- The game may load the modes again as new objects (not seen with CameraProbe): the game's
-- values are kept by mode name, and every scan finds the new objects.

local U = require("dynamic_fov_unreal")

local M = {}

M.CAMERA_CLASS = "/Script/AdvancedThirdPersonCamera.ATPCCameraComponent"
-- The game's transition speed for a time in seconds: speed = SPEED_TIME / seconds, so the game's 1.5 is 1.5 s.
M.SPEED_TIME = 2.25
local MAX_MODES = 512             -- the game has 123; a bound against a camera that would keep adding modes
-- Values closer than this are the same. It covers the game keeping its numbers in 32 bits, and stays well under the
-- smallest gap between two speeds the menu gives (0.026, between 2.9 s and 3 s).
local SAME = 1e-3

-- Setting for each managed mode, by its gameplay tag. Seen in play with CameraProbe: ShoulderDefault (standing,
-- walking, running, climbing), Sprint, Crouch, Combat (an enemy near, none locked on: it stays after unlocking, until
-- the player walks away, seen in play on 5 November 2026; CameraProbe also saw it while sprinting) and Combat.Focus (enemy
-- locked on). Combat follows the normal view, so unlocking changes the view at once. One enemy's own combat view
-- (Custom) is seen in play, CameraType.Combat.Custom.PengMeng (the mod's first write to it, 4 November 2026); that
-- each is the view of its kind is not verified. Each follows its kind, so the view does not change from one boss to
-- the next. WeakLockNext is a combat view the game turns to now and then, no enemy locked on: left alone, the mod took
-- the camera's place away and the field of view went back to the game's 75 for one to three seconds, and the camera
-- jumped (seen in play on 5 November 2026); it follows the normal
-- view, as Combat. What brings it in play is not verified.
local EXACT = {
	["CameraType.ShoulderDefault"] = "normal",
	["CameraType.Sprint"] = "sprint",
	["CameraType.Crouch"] = "crouch",
	["CameraType.Combat"] = "normal",
	["CameraType.WeakLockNext"] = "normal",
	["CameraType.Combat.Focus"] = "lock_on",
}
-- { prefix, setting }: neither prefix starts the other.
local PREFIXES = { { "CameraType.Combat.Custom.", "normal" }, { "CameraType.Combat.Focus.Custom.", "lock_on" } }

function M.setting_of(tag)
	if tag == nil then return nil end
	if EXACT[tag] ~= nil then return EXACT[tag] end
	for _, p in ipairs(PREFIXES) do
		if tag:sub(1, #p[1]) == p[1] then return p[2] end
	end
	return nil
end

-- known[address] = false for a mode the mod leaves alone, or the managed mode's record. game[name] and last[name]: the
-- game's values and the mod's last written values of a managed mode, kept across loads; reported[name]: the mode's
-- first write is already in the log. All three hold only names that got a game's value, so at most MAX_MODES.
local K = { known = {}, game = {}, last = {}, reported = {}, names = 0 }

-- Named functions for pcall rather than a new closure at each call: a scan makes a few hundred calls.
local function settings_of(mode)
	local fov = mode.CameraModeSettings.FOVSettings
	return fov.CameraFOV, fov.FOVInterpolation.InterpSpeed
end

local function get_of(wrapped)
	return wrapped:get()
end

local function address_of(obj)
	return obj:GetAddress()
end

-- The mode's target field of view and transition speed, read in one go; nil for what cannot be read.
local function values_of(mode)
	local ok, fov, speed = pcall(settings_of, mode)
	if not ok then return nil, nil end
	return U.num(fov), U.num(speed)
end

-- The mode's gameplay tag, or nil.
function M.tag_of(mode)
	local ok, tag = pcall(function() return mode.CameraModeTag.TagName:ToString() end)
	return ok and type(tag) == "string" and tag or nil
end
local tag_of = M.tag_of

local function write(mode, fov, speed)
	local ok = pcall(function() mode.CameraModeSettings.FOVSettings.CameraFOV = fov end)
	local ok2 = pcall(function() mode.CameraModeSettings.FOVSettings.FOVInterpolation.InterpSpeed = speed end)
	return ok and ok2
end

local function holds(fov, speed, v)
	return v ~= nil and math.abs(fov - v.fov) < SAME and math.abs(speed - v.speed) < SAME
end

-- The game's values of a mode met for the first time under this name. A mode loaded again keeps the game's values
-- noted the first time, unless it now holds values that are neither those nor the mod's (the game changed them): a
-- copy of a mode the mod wrote to holds the last values written, even when the settings just changed.
local function note_game(name, mode)
	local fov, speed = values_of(mode)
	if fov == nil or speed == nil then return nil end
	local g = K.game[name]
	if g ~= nil and (holds(fov, speed, g) or holds(fov, speed, K.last[name])) then
		return g
	end
	if g == nil then
		if K.names >= MAX_MODES then return nil end
		K.names = K.names + 1
	end
	g = { fov = fov, speed = speed }
	K.game[name] = g
	return g
end

-- The camera component on the pawn, or nil.
local camera_class = nil
function M.camera(pawn)
	if not U.is_valid(camera_class) then
		pcall(function() camera_class = StaticFindObject(M.CAMERA_CLASS) end)
		if not U.is_valid(camera_class) then return nil end
	end
	local ok, c = pcall(function() return pawn:GetComponentByClass(camera_class) end)
	if ok and U.is_valid(c) then return c end
	return nil
end

-- Looks at every mode of the camera; returns the number of modes, the number managed, and how many are new.
-- Modes are known by address. A mode that leaves the map leaves this table at the next scan, long before the game
-- can free it and put another object there (Unreal frees unreferenced objects about once a minute by default); a
-- load frees at once, and the caller forgets every address at a new camera or when managed modes go missing
-- (M.forget). A managed record is still dropped as soon as the object at its address has another tag: a write meant
-- for the sprint never lands on another mode.
function M.scan(camera)
	local ok, map = pcall(function() return camera.SortedCameraModes end)
	if not ok or map == nil then return 0, 0, 0 end
	local seen, managed, fresh, total = {}, 0, 0, 0
	pcall(function()
		map:ForEach(function(_, v)
			if total >= MAX_MODES then return end
			local okm, mode = pcall(get_of, v)
			if not okm then mode = v end
			local oka, addr = pcall(address_of, mode)
			if not oka or addr == nil then return end
			local rec = K.known[addr]
			-- A mode the mod leaves alone is never written: nothing more to read about it.
			if rec == false then
				total = total + 1
				seen[addr] = true
				return
			end
			if not U.is_valid(mode) then return end
			total = total + 1
			if rec and tag_of(mode) ~= rec.tag then rec = nil end
			if rec == nil then
				local tag = tag_of(mode)
				local setting = M.setting_of(tag)
				rec = false
				if setting ~= nil then
					local okn, name = pcall(function() return mode:GetFullName() end)
					name = okn and name or tag
					local game = note_game(name, mode)
					if game ~= nil then rec = { mode = mode, name = name, tag = tag, setting = setting, game = game } end
				end
				K.known[addr] = rec
				fresh = fresh + 1
			end
			seen[addr] = true
			if rec then
				rec.mode = mode
				managed = managed + 1
			end
		end)
	end)
	for addr in pairs(K.known) do
		if not seen[addr] then K.known[addr] = nil end
	end
	return total, managed, fresh
end

-- One managed mode: "written", "failed", or nil when it already holds the values or is dropped.
local function apply_one(addr, rec, wanted, report)
	if not U.is_valid(rec.mode) then
		K.known[addr] = nil
		return nil
	end
	local w = wanted(rec.setting)
	-- Kept while off too: a copy of this mode made while the mod was on still holds these values.
	if w ~= nil then K.last[rec.name] = w end
	w = w or rec.game
	local fov, speed = values_of(rec.mode)
	if fov ~= nil and speed ~= nil and holds(fov, speed, w) then return nil end
	-- Between two scans the object at this address may have become another one: it is never written.
	if tag_of(rec.mode) ~= rec.tag then
		K.known[addr] = nil
		return nil
	end
	if not K.reported[rec.name] then
		K.reported[rec.name] = true
		report(rec.tag, fov, speed, w)
	end
	return write(rec.mode, w.fov, w.speed) and "written" or "failed"
end

-- Writes the wanted values (or the game's, while the mod is off) where they differ, in the managed modes the last
-- scan found. Returns the number of writes and of failed writes. A value the game put back on the same mode is
-- written again here. wanted(setting) gives the values the mod writes for a setting, or nil while it is off.
-- report(tag, fov, speed, w) hears of each mode's first write, with the values it held before.
function M.apply(wanted, report)
	local writes, failed = 0, 0
	for addr, rec in pairs(K.known) do
		if rec then
			local done = apply_one(addr, rec, wanted, report)
			if done == "written" then writes = writes + 1 elseif done == "failed" then failed = failed + 1 end
		end
	end
	return writes, failed
end

-- A new camera, or fewer managed modes than before: an address may now hold another mode, even one the mod knew as
-- unmanaged (only managed records check their tag). The game's values stay, kept by mode name.
function M.forget()
	K.known = {}
end

return M
