-- The colours and the clean image (1.0.3), the only part of the mod that writes a camera's image settings. The engine
-- views through the view target's first active camera component (Unreal 5.7, AActor::CalcCamera), whose settings come
-- after the places' own: there the general saturation is the camera's own times the profile (it replaces the places'
-- general one, their ranges stay theirs), and the five effects set at 0 (dynamic_fov_image_values.lua). A cinematic
-- look (1.0.9) multiplies four more values and the saturation (dynamic_fov_looks.lua). In play that
-- camera is a cinema camera on the player's character; in a scene, each shot has its own, on a camera actor the game
-- makes as the shot starts or as the view starts to fade towards it (SceneCameraProbe, 11 November 2026).
-- The camera seen through is looked at once a second (a value the game put back is written again) and at once after
-- a change. A camera actor's camera gets the image in the frame the game makes it (1.0.8): found at the next look
-- only, each shot started with the game's colours and the mod's cut in up to a second later. Each camera's own values
-- are kept at its first write and given back when the setting goes back to the game's, or the mod is off
-- (dynamic_fov_image_held.lua). While the colours are the game's and the image is not cleaned, nothing is asked of
-- the game and no camera made is kept.

local U = require("dynamic_fov_unreal")
local V = require("dynamic_fov_image_values")
local Held = require("dynamic_fov_image_held")
local Looks = require("dynamic_fov_looks")
local Made = require("dynamic_fov_made")

local M = {}

local CAMERA_CLASS = "/Script/Engine.CameraComponent"
-- The engine's actor that only films, cinema cameras included: what a scene's shot is seen through.
local CAMERA_ACTOR_CLASS = "/Script/Engine.CameraActor"

local New = Made.new(CAMERA_CLASS)

-- want: { factor = number or nil, clean = boolean, look = name or nil }, nil for the game's image. classes[path]:
-- the engine's classes found. dirty: a change waits for the next look.
local I = { want = nil, classes = {}, dirty = false, class_said = false }

local function class(path)
	local c = I.classes[path]
	if U.is_valid(c) then return c end
	local ok, found = pcall(StaticFindObject, path)
	c = ok and U.is_valid(found) and found or nil
	I.classes[path] = c
	return c
end

local function view_camera(pc)
	local c = class(CAMERA_CLASS)
	if c == nil then return nil end
	local ok, cam = pcall(function() return pc.PlayerCameraManager.ViewTarget.Target:GetComponentByClass(c) end)
	return ok and U.is_valid(cam) and cam or nil
end

-- The name of cam's actor when cam films in a level, on an actor that only films; else nil. A scene's file also
-- holds a model of each of its cameras, a camera actor in no level, made as the file loads: written, it handed the
-- mod's image on to the shot's camera, made from it, as that camera's own, and the colours were applied twice
-- (trial of 11 November 2026).
local function films_on(cam, actor_class)
	local ok, owner = pcall(function() return cam:GetOwner() end)
	if not ok or not U.is_valid(owner) then return nil end
	local is_one, yes = pcall(function() return owner:IsA(actor_class) end)
	if not is_one or yes ~= true then return nil end
	local named, name = pcall(function() return cam:GetFullName() end)
	return named and type(name) == "string" and name:match(":PersistentLevel%.([^.:]+)%.[^.:]+$") or nil
end

-- The colours' factor (nil: the game's), whether the image is cleaned, and the cinematic look's name (nil: none);
-- the mod off gives (nil, false, nil).
function M.want(factor, clean, look)
	local w = nil
	if factor ~= nil or clean or look ~= nil then w = { factor = factor, clean = clean == true, look = look } end
	local before = I.want
	if (w == nil) ~= (before == nil)
		or (w and (w.factor ~= before.factor or w.clean ~= before.clean or w.look ~= before.look)) then
		I.want, I.dirty = w, true
		New.set_on(w ~= nil)
	end
end

-- Whether a change waits for the next look.
function M.pending()
	return I.dirty
end

-- Whether cameras the game just made wait for M.born: asks nothing of the game.
M.waiting = New.waiting

-- At start. What cannot be watched is said in the log.
function M.watch(log)
	local ok, err = New.watch()
	if not ok then
		log("new cameras cannot be watched (%s): a scene's camera gets the image at the next look", tostring(err))
	end
end

-- The values the camera of rec gets now, by field.
local function targets(rec)
	local t = {}
	if I.want == nil then return t end
	local look = I.want.look and Looks.get(I.want.look) or nil
	local factor = I.want.factor
	if look ~= nil and look.saturation ~= nil then factor = (factor or 1) * look.saturation end
	local own = rec.saved[V.SATURATION]
	if factor ~= nil and own ~= nil then
		local base = own.on and own.value or V.NEUTRAL
		t[V.SATURATION] = { X = base.X, Y = base.Y, Z = base.Z, W = base.W * factor }
	end
	for field, by in pairs(look and look.values or {}) do
		local saved = rec.saved[field]
		if saved ~= nil then
			local base = saved.on and saved.value or V.NEUTRAL
			t[field] = { X = base.X * by.X, Y = base.Y * by.Y, Z = base.Z * by.Z, W = base.W * by.W }
		end
	end
	if I.want.clean then
		for _, f in ipairs(V.EFFECTS) do
			if rec.saved[f] ~= nil then t[f] = 0 end
		end
	end
	return t
end

-- Brings one camera held to what is wanted, and says it when something was written or could not be; how: said after
-- the count. Returns the values written and those that could not be.
local function bring(rec, report, problem, how)
	local w, f = Held.apply(rec, targets(rec))
	if w > 0 or f > 0 then
		(f > 0 and problem or report)("image: %s (%s, %d written%s%s)", I.want == nil and "the game's back"
			or string.format("colours %s, clean image %s%s", I.want.factor and string.format("x%.1f", I.want.factor)
				or "the game's", I.want.clean and "on" or "off", I.want.look and ", look " .. I.want.look or ""),
			Held.name(rec), w,
			f > 0 and string.format(", %d could not be", f) or "", how or "")
	end
	return w, f
end

-- Once a second, and at the tick after a change. pc: the player controller. report(fmt, ...) hears of each camera
-- brought to a new image, problem(fmt, ...) of what went wrong: values refused, settings unreadable, too many cameras.
-- Returns the values written and those that could not be.
function M.look(pc, report, problem)
	problem = problem or report
	I.dirty = false
	if I.want == nil and Held.count() == 0 then return 0, 0 end
	Held.prune()
	local writes, failed = 0, 0
	if I.want ~= nil then
		local cam = view_camera(pc)
		if cam ~= nil and select(2, Held.take(cam, problem)) then failed = failed + 1 end
	end
	for addr, rec in Held.each() do
		local w, f = bring(rec, report, problem)
		writes, failed = writes + w, failed + f
		if I.want == nil and next(rec.written) == nil then Held.drop(addr) end
	end
	return writes, failed
end

-- In a frame that has cameras the game just made (M.waiting), before anything else: a camera actor's, in a level,
-- gets the image at once, so a shot is never seen with the game's. Any other camera waits for the look that sees
-- through it.
-- report, problem: as for M.look. Returns the values written and those that could not be.
function M.born(report, problem)
	problem = problem or report
	local list, n = New.take()
	if list == nil or I.want == nil then return 0, 0 end
	local actor_class = class(CAMERA_ACTOR_CLASS)
	if actor_class == nil then
		if not I.class_said then
			I.class_said = true
			problem("image: the engine's camera actor cannot be found; a scene's camera gets the image at the next look")
		end
		return 0, 0
	end
	local writes, failed = 0, 0
	for i = 1, n do
		local cam = list[i]
		local actor = U.is_valid(cam) and films_on(cam, actor_class) or nil
		if actor ~= nil then
			local rec, unreadable = Held.take(cam, problem, true)
			if unreadable then failed = failed + 1 end
			if rec ~= nil then
				local w, f = bring(rec, report, problem, ", at its making on " .. actor)
				writes, failed = writes + w, failed + f
			end
		end
	end
	return writes, failed
end

return M
