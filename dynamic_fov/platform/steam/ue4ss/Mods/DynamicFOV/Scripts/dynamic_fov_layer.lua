-- The view's distance, height and side (1.0.1), set through the camera's own additive layer, the only part of the mod
-- that writes it. Not through the modes' values like the field of view: there a new distance only counts from the
-- next change of mode, and the target offset follows the character, not the screen; the layer moves the view at once,
-- eased over BLEND seconds, along the screen (CameraProbe pass 4, 4 November 2026). The layer holds in every mode,
-- dialogues included (seen then): it is set only while the camera is in a managed mode, and taken away in any other
-- mode and while a cinematic camera has the view. During an execution, main.lua asks for none, in less time.
-- Since 1.0.11 each of five situations may have its own place (dynamic_fov_settings_place.lua gives them).

local U = require("dynamic_fov_unreal")
local Modes = require("dynamic_fov_modes")
local Situations = require("dynamic_fov_situations")
local Calls = require("dynamic_fov_calls")

local M = {}

-- The layer's name: another mod's layers add to ours, each under its own name.
M.NAME = "DynamicFOV"
-- Seconds. The game's own changes of mode take 0.5 to 0.8 s (CameraProbe pass 4): the layer follows in step.
M.BLEND = 0.5
local SAME = 0.05                 -- centimetres closer than this are the same
local NONE = { distance = 0, height = 0, side = 0 }
local SIGNATURES = {
	{ "SetAdditiveParameter_Distance", { "NameProperty", "number", "number" } },
	{ "SetAdditiveParameter_SocketOffset", { "NameProperty", "StructProperty<Vector>", "number" } },
	{ "GetCurrentCameraMode", {} },
	{ "IsCineCameraActive", {} },
}

-- Addresses only, compared at each use: no game object is kept from one tick to the next. place: the situation of
-- the mode the camera is in, nil for a mode the mod leaves alone; situation: the one the last tick placed the view
-- for, nil when it placed none; want: what that tick was asked (the settings' own table, no game object).
local L = { ready = nil, name = nil, camera = nil, mode = nil, place = nil, base = nil, tag = nil,
	applied = NONE, no_base = false, situation = nil, want = nil }

-- Named functions for pcall rather than a new closure at each tick.
local function get_mode(cam) return cam:GetCurrentCameraMode() end
local function get_cine(cam) return cam:IsCineCameraActive() end
local function get_base(mode) return mode.CameraModeSettings.LocationSettings.DefaultCameraDistance end
local function set_distance(cam, name, d, blend) cam:SetAdditiveParameter_Distance(name, d, blend) end
local function set_offset(cam, name, v, blend) cam:SetAdditiveParameter_SocketOffset(name, v, blend) end

local function ready(log)
	if L.ready ~= nil then return L.ready end
	L.ready = true
	for _, s in ipairs(SIGNATURES) do
		local ok, found = Calls.takes(Modes.CAMERA_CLASS, s[1], s[2])
		if not ok then
			L.ready = false
			log("camera position off: the camera's %s is not the one this version knows (%s)", s[1],
				found and table.concat(found, ", ") or "not found")
			return false
		end
	end
	local ok, name = pcall(FName, M.NAME)
	if ok and name ~= nil then
		L.name = name
	else
		L.ready = false
		log("camera position off: its layer cannot be named (%s)", tostring(name))
	end
	return L.ready
end

-- The mode the camera is in: tag and default distance read again only when it changes, or after recheck().
local function follow_mode(cam, log)
	local ok, mode = pcall(get_mode, cam)
	if not ok or not U.is_valid(mode) then
		L.mode, L.place, L.base, L.tag = nil, nil, nil, nil
		return
	end
	local addr = U.address(mode)
	if addr ~= nil and addr == L.mode then return end
	L.mode, L.tag = addr, Modes.tag_of(mode)
	L.place = Situations.place_of(L.tag)
	local okb, base = false, nil
	if L.place ~= nil then okb, base = pcall(get_base, mode) end
	L.base = okb and U.num(base) or nil
	if L.place ~= nil and L.base == nil and not L.no_base then
		L.no_base = true
		log("camera position: the distance of %s cannot be read; its distance stays the game's", tostring(L.tag))
	end
end

-- What the layer should hold now, and the situation it is for (nil: none, the game's view).
local function target(cam, want, log)
	if want == nil then return NONE end
	follow_mode(cam, log)
	if L.place == nil then return NONE end
	local ok, cine = pcall(get_cine, cam)
	-- A camera that cannot say counts as cinematic: the game's view rather than a wrong one.
	if not ok or cine ~= false then return NONE end
	local place = want.by[L.place]
	return { distance = (L.base or 0) * place.distance / 100, height = place.height, side = place.side }, L.place
end

local function differs(a, b)
	return math.abs(a.distance - b.distance) > SAME or math.abs(a.height - b.height) > SAME
		or math.abs(a.side - b.side) > SAME
end

local function is_none(t)
	return not differs(t, NONE)
end

-- At each tick. want: { by = { situation = { distance = % of the mode's own, height, side = cm } }, eased = the
-- seconds a change of situation takes, or nil }, or nil while the mod is off or every place is 0. Returns "idle"
-- when nothing was asked of the game, "kept", "set", "failed" or "off" (unknown functions);
-- report(fmt, ...) hears of each change of the layer. blend: the seconds a change takes; unless given, want.eased
-- from one situation to another, BLEND for anything else (a setting changed, the place given back or taken away).
function M.frame(cam, want, log, report, blend)
	if want == nil and L.applied == NONE then
		-- An execution begun where the view had no place of its own: its end is no change of situation.
		L.situation = nil
		return "idle"
	end
	if not U.is_valid(cam) then
		-- The layer went with its camera.
		L.camera, L.applied = nil, NONE
		return "idle"
	end
	local addr = U.address(cam)
	if addr ~= L.camera then
		-- A new camera starts without our layer.
		L.camera, L.applied, L.mode, L.situation = addr, NONE, nil, nil
		if want == nil then return "idle" end
	end
	if not ready(log) then return "off" end
	local t, situation = target(cam, want, log)
	-- Under the same settings as the tick before only: after a setting changed, an execution or a while with no
	-- place asked, the view is placed in the layer's own time.
	local eased = want == L.want and situation ~= nil and L.situation ~= nil and situation ~= L.situation
		and want.eased or nil
	L.want, L.situation = want, situation
	if not differs(t, L.applied) then return "kept" end
	local seconds = blend or eased or M.BLEND
	local ok1 = pcall(set_distance, cam, L.name, t.distance, seconds)
	local ok2 = pcall(set_offset, cam, L.name, { X = 0, Y = t.side, Z = t.height }, seconds)
	if not (ok1 and ok2) then return "failed" end
	L.applied = is_none(t) and NONE or t
	if is_none(t) then
		report("taken away in %s", tostring(L.tag or "no mode"))
	else
		report("distance %+.0f cm, height %+.0f cm, side %+.0f cm in %s", t.distance, t.height, t.side, tostring(L.tag))
	end
	return "set"
end

-- Whether a cinematic camera has the view: true, false, or nil when the camera cannot say (functions this version
-- does not know, or the call failed).
function M.cinematic(cam, log)
	if not U.is_valid(cam) or not ready(log) then return nil end
	local ok, cine = pcall(get_cine, cam)
	if not ok or type(cine) ~= "boolean" then return nil end
	return cine
end

-- Whether the view is one of the modes the mod manages, with no cinematic camera: the panel opens only then. Not, with
-- why when the camera cannot say (a game update that changed its functions, said once above): a cutscene would be a
-- wrong reason.
function M.playable(cam, log)
	local cine = M.cinematic(cam, log)
	if cine == nil then return false, "the camera cannot say whether a cutscene is on" end
	if cine then return false end
	local ok, mode = pcall(get_mode, cam)
	return ok and U.is_valid(mode) and Situations.place_of(Modes.tag_of(mode)) ~= nil
end

-- Reads the mode's tag and distance again at the next tick: the game may load a mode again at the same address.
function M.recheck()
	L.mode = nil
end

-- Nothing on the camera: with no place wanted, a tick has nothing to do.
function M.idle()
	return L.applied == NONE
end

return M
