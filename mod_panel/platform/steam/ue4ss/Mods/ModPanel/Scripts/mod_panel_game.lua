-- What the panel asks the game: its game instance (the panel's owner), whether it is paused (one of its menus open),
-- its text language, and whether the player is in play. Taken from Dynamic FOV 1.0.4 (dynamic_fov_panel_game.lua),
-- in_play added. Each library is found once by path and checked before each use: StaticFindObject can take
-- milliseconds in a loaded game (PanelProbe). FindFirstOf walks every object: it is asked once a session, for the
-- engine, which holds the game instance (under 1.1 ms in game, 5 November 2026).

local U = require("mod_panel_unreal")
local Calls = require("mod_panel_calls")
local Text = require("mod_panel_text")

local M = {}

local STATICS = "/Script/Engine.Default__GameplayStatics"
local GAME_LIBRARY = "/Script/ProjectPBZ.Default__PBZBlueprintFunctionLibrary"
local ENGINE_LIBRARY = "/Script/Engine.Default__KismetInternationalizationLibrary"
-- The character's camera: the class whose IsCineCameraActive says whether a cinematic camera has the view.
local CAMERA_CLASS = Calls.CINE[1]

local S = { engine = nil, found = {} }

local function find(path)
	if U.is_valid(S.found[path]) then return S.found[path] end
	local ok, o = pcall(StaticFindObject, path)
	S.found[path] = ok and U.is_valid(o) and o or nil
	return S.found[path]
end

-- Named functions for pcall.
local function instance_of(engine) return engine.GameInstance end
local function is_paused(lib, pc) return lib:IsGamePaused(pc) end
local function game_culture(lib, gi) return lib:GetCurrentCulture(gi) end
local function engine_culture(lib) return lib:GetCurrentCulture() end
local function pawn_of(pc) return pc.Pawn end
local function camera_of(pawn, class) return pawn:GetComponentByClass(class) end
local function cine_on(camera) return camera:IsCineCameraActive() end

-- The game instance, or nil. A function library has only its default object, which FindFirstOf skips, but the engine
-- is an ordinary object.
function M.instance()
	if not U.is_valid(S.engine) then
		local ok, e = pcall(FindFirstOf, "GameEngine")
		S.engine = ok and e or nil
		if not U.is_valid(S.engine) then return nil end
	end
	local ok, gi = pcall(instance_of, S.engine)
	return ok and U.is_valid(gi) and gi or nil
end

-- true or false, or nil when the game cannot say.
function M.paused(pc)
	local lib = find(STATICS)
	if lib == nil then return nil end
	local ok, p = pcall(is_paused, lib, pc)
	if not ok or type(p) ~= "boolean" then return nil end
	return p
end

-- The game's culture as Mods Menu asks it (the game's own library), else the engine's; nil without either.
local function culture(gi)
	local lib = gi and Calls.ok(Calls.GAME_CULTURE) and find(GAME_LIBRARY)
	if lib then
		local ok, v = pcall(game_culture, lib, gi)
		local c = ok and U.text(v) or nil
		if c ~= nil and c ~= "" then return c end
	end
	lib = Calls.ok(Calls.ENGINE_CULTURE) and find(ENGINE_LIBRARY)
	if lib then
		local ok, v = pcall(engine_culture, lib)
		return ok and U.text(v) or nil
	end
	return nil
end

-- The panel's language for the game's: one of the 15 of mod_panel_text.lua's LANGS.
function M.language(gi)
	return Text.lang_of(culture(gi))
end

-- Whether the player is in play: a character with its camera, no cinematic camera with the view, the game not paused,
-- unless ours: the pause is Mod Panel's own (mod_panel_freeze.lua, D95). Returns true and the character, or false, why,
-- and whether that is a failure rather than the game's way. Only once the panel's functions are checked
-- (Calls.check_step): IsGamePaused is one of them.
function M.in_play(pc, ours)
	local ok, pawn = pcall(pawn_of, pc)
	if not ok or not U.is_valid(pawn) then return false, "no character" end
	if not (Calls.ok(Calls.CAMERA) and Calls.ok(Calls.CINE)) then
		return false, "this game's camera functions are not the ones this version knows", true
	end
	local class = find(CAMERA_CLASS)
	local okc, camera = false, nil
	if class ~= nil then okc, camera = pcall(camera_of, pawn, class) end
	if not okc or not U.is_valid(camera) then return false, "no character camera" end
	local oki, cine = pcall(cine_on, camera)
	if not oki or type(cine) ~= "boolean" then return false, "the camera cannot say whether a cutscene plays", true end
	if cine then return false, "a cutscene plays" end
	if ours then return true, pawn end
	local paused = M.paused(pc)
	if paused == nil then return false, "the game cannot say whether it is paused", true end
	if paused then return false, "the game is paused (one of its menus is open)" end
	return true, pawn
end

return M
