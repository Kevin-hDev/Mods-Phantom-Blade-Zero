-- The comfort options (1.0.5, chosen on 7 November 2026), written in the player camera's modes, each found by its
-- gameplay tag. 1.0.5's trial wrote each field and read it back (7 November 2026). Only switches and numbers are
-- written: an enum written through this UE4SS build is said to crash the game (not tried). The game's values are
-- kept by mode name before the first write and put back when an option or the mod is off. dynamic_fov_modes.lua
-- alone writes the modes' field of view and transition speed; this module alone these four fields. The camera reads
-- them when it changes mode (seen in play for the distance, CameraProbe pass 4).

local U = require("dynamic_fov_unreal")
local Modes = require("dynamic_fov_modes")

local M = {}

local SET = "CameraModeSettings."
local NORMAL, SPRINT = "CameraType.ShoulderDefault", "CameraType.Sprint"
local DISTANCE = SET .. "LocationSettings.DefaultCameraDistance"
local STEADY_MAX = 50             -- cm the camera trails the character at most (the game: up to 300)
local MAX_NAMES = 64              -- modes whose game values are kept; four tags, a few loads
-- Looks after a new camera or a change that scan all its modes, then one scan every SCAN_EVERY looks, for a mode the
-- game would load again: a camera fills in over a few seconds after a load (seen in game, dynamic_fov_camera.lua).
local EARLY_SCANS, SCAN_EVERY = 5, 10

-- want: the options on (nil while the mod is off). modes[tag]: { mode, name }. game[name][path], last[name][path]: the
-- game's values and the last ones written. broken[field]: the option cannot be used, said once a camera.
-- normal_distance: the normal view's own distance, noted at each pass, which the sprint takes. touched: a field may
-- hold another value than the game's; with it false and no option on, nothing is read (the mod's default, most
-- players' case).
local K = { want = nil, camera = nil, modes = {}, game = {}, last = {}, names = 0, broken = {}, scans = 0,
	scan_in = 0, dirty = false, restored = false, normal_distance = nil, touched = false }

-- { the setting's field, the modes' tags, the field's path, its value from the game's }: in this order, so the normal
-- view's distance is known before the sprint takes it.
local RULES = {
	{ "steady", { NORMAL, SPRINT, "CameraType.Crouch", "CameraType.ShoulderNear" },
		SET .. "LocationSettings.CameraLocationLagSettings.CameraLagMaxDistance",
		function(v) return math.min(v, STEADY_MAX) end },
	{ "no_recenter", { SPRINT }, SET .. "RotationSettings.bEnableViewRotationToActorRotation",
		function() return false end },
	{ "no_pull_back", { SPRINT }, DISTANCE, function() return K.normal_distance end },
	{ "no_shake", { SPRINT }, SET .. "bEnableCameraShakesSettings", function() return false end },
}
local TAGS = {}
for _, r in ipairs(RULES) do
	for _, tag in ipairs(r[2]) do TAGS[tag] = true end
end

local function get(obj, path)
	local v = obj
	for part in path:gmatch("[^%.]+") do v = v[part] end
	return v
end

local function set(obj, path, value)
	local parent, last = path:match("^(.*)%.([^%.]+)$")
	get(obj, parent)[last] = value
end

local function read(obj, path)
	local ok, v = pcall(get, obj, path)
	if not ok then return nil end
	if type(v) == "boolean" then return v end
	return U.num(v)
end

local function same(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < Modes.SAME end
	return a == b
end

local function alive(rec, tag)
	return rec ~= nil and U.is_valid(rec.mode) and Modes.tag_of(rec.mode) == tag
end

-- The modes with the tags above among the camera's. Its own scan: dynamic_fov_modes.lua keeps only the modes whose
-- field of view it manages, and CameraType.ShoulderNear is not one.
local function scan(camera)
	local ok, map = pcall(function() return camera.SortedCameraModes end)
	if not ok or map == nil then return end
	local found, total = {}, 0
	pcall(function()
		map:ForEach(function(_, v)
			if total >= Modes.MAX_MODES then return end
			total = total + 1
			local okm, mode = pcall(function() return v:get() end)
			if not okm then mode = v end
			if not U.is_valid(mode) then return end
			local tag = Modes.tag_of(mode)
			if tag == nil or not TAGS[tag] or found[tag] then return end
			local okn, name = pcall(function() return mode:GetFullName() end)
			found[tag] = { mode = mode, name = okn and type(name) == "string" and name or tag }
		end)
	end)
	K.modes = found
end

-- The game's value of path in rec's mode, noted the first time under its name, then the value now; nil, nil when the
-- field cannot be read. A mode loaded again keeps the value noted then, unless it now holds one that is neither that
-- nor the last written: the game changed it. Past MAX_NAMES names a new mode is left alone (nil, its value), its
-- option not cut: the field reads well.
local function note(rec, path)
	local v = read(rec.mode, path)
	if v == nil then return nil, nil end
	local g = K.game[rec.name]
	if g == nil then
		if K.names >= MAX_NAMES then return nil, v end
		K.names = K.names + 1
		g = {}
		K.game[rec.name], K.last[rec.name] = g, {}
	end
	if g[path] == nil or not (same(v, g[path]) or same(v, K.last[rec.name][path])) then g[path] = v end
	return g[path], v
end

-- Each field where it should be: the option's value while it is on, the game's else. Returns the writes, the failed
-- ones, and whether every field holds the game's value.
local function apply(problem)
	local writes, failed, home = 0, 0, true
	-- Never written by the mod: its value now is the game's.
	K.normal_distance = K.modes[NORMAL] and note(K.modes[NORMAL], DISTANCE)
	for _, r in ipairs(RULES) do
		local field, path, value = r[1], r[3], r[4]
		for _, tag in ipairs(r[2]) do
			local rec = K.modes[tag]
			local game, now = nil, nil
			if rec ~= nil then game, now = note(rec, path) end
			if rec ~= nil and now == nil and not K.broken[field] then
				K.broken[field] = true
				problem("comfort: %s cannot be used, %s is not readable in %s", field, path, tag)
			end
			if game ~= nil then
				local want = game
				if K.want ~= nil and K.want[field] and not K.broken[field] then want = value(game) end
				if want == nil then want = game end
				home = home and same(want, game)
				K.last[rec.name][path] = want
				if not same(now, want) then
					local ok = pcall(set, rec.mode, path, want)
					if ok and same(read(rec.mode, path), want) then writes = writes + 1 else failed = failed + 1 end
				end
			end
		end
	end
	return writes, failed, home
end

local function same_want(a, b)
	if a == nil or b == nil then return a == b end
	return a.steady == b.steady and a.no_recenter == b.no_recenter and a.no_pull_back == b.no_pull_back
		and a.no_shake == b.no_shake
end

-- The options settings s turn on, or none while the mod is off or all four are off; written at the next tick. A
-- change of another setting changes nothing here: it would scan the camera's modes again for nothing (audit of 1.0.5).
function M.want(s)
	local want = nil
	if s.enabled and (s.steady or s.no_recenter or s.no_pull_back or s.no_shake) then
		want = { steady = s.steady, no_recenter = s.no_recenter, no_pull_back = s.no_pull_back, no_shake = s.no_shake }
	end
	if same_want(want, K.want) then return end
	K.want, K.dirty, K.restored = want, true, false
	K.scans = EARLY_SCANS
end

-- Whether a change waits to be written.
function M.pending()
	return K.dirty
end

-- Once a second, and at the next tick after a change: the camera's modes found, the fields written where they
-- differ. report(fmt, ...) says the writes; problem(fmt, ...), under its own bound, a field that cannot be read and
-- the writes that failed, so routine lines never silence them (as the image's, audit of 1.0.3). Returns the writes
-- and the failed ones.
function M.look(camera, report, problem)
	if not U.is_valid(camera) then return 0, 0 end
	if camera ~= K.camera then
		-- A field unreadable on the last camera is tried again: a load may have brought it.
		K.camera, K.modes, K.restored, K.scans, K.broken = camera, {}, false, EARLY_SCANS, {}
	end
	if K.want == nil and not K.touched then
		K.dirty, K.restored = false, true
		return 0, 0
	end
	if K.restored and not K.dirty then return 0, 0 end
	for tag, rec in pairs(K.modes) do
		if not alive(rec, tag) then K.modes[tag], K.scans = nil, EARLY_SCANS end
	end
	K.scan_in = K.scan_in - 1
	if K.scans > 0 or K.scan_in <= 0 then
		K.scans = math.max(0, K.scans - 1)
		K.scan_in = SCAN_EVERY
		scan(camera)
	end
	K.dirty = false
	local writes, failed, home = apply(problem)
	-- A camera without these modes yet proves nothing: they may come.
	K.restored = home and failed == 0 and next(K.modes) ~= nil
	K.touched = not K.restored
	if writes > 0 then
		report("comfort: %s, %d written", home and "the game's values back" or "options applied", writes)
	end
	if failed > 0 then problem("comfort: %d field(s) could not be written", failed) end
	return writes, failed
end

return M
