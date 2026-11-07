-- What the panel asks the game: its game instance (the panel's owner), whether it is paused (one of its menus open),
-- its text language, a subsystem of the player's and the controller's name. Each library or class is found once by
-- path (find) and checked before each use: StaticFindObject can take milliseconds in a loaded game (PanelProbe).
-- FindFirstOf walks every object: it is asked once a session, for the engine, which holds the game instance (under
-- 1.1 ms in game, 5 November 2026). Pass 7 read each answer in the game:
-- the pause while the game's menu is open, the culture "fr".

local U = require("dynamic_fov_unreal")
local PanelCalls = require("dynamic_fov_panel_calls")
local Texts = require("dynamic_fov_panel_texts")

local M = {}

local STATICS = "/Script/Engine.Default__GameplayStatics"
local GAME_LIBRARY = "/Script/ProjectPBZ.Default__PBZBlueprintFunctionLibrary"
local ENGINE_LIBRARY = "/Script/Engine.Default__KismetInternationalizationLibrary"
local SUBSYSTEMS = "/Script/Engine.Default__SubsystemBlueprintLibrary"

local S = { engine = nil, found = {} }

local function find(path)
	if U.is_valid(S.found[path]) then return S.found[path] end
	local ok, o = pcall(StaticFindObject, path)
	S.found[path] = ok and U.is_valid(o) and o or nil
	return S.found[path]
end
M.find = find

-- Named functions for pcall.
local function instance_of(engine) return engine.GameInstance end
local function is_paused(lib, pc) return lib:IsGamePaused(pc) end
local function game_culture(lib, gi) return lib:GetCurrentCulture(gi) end
local function engine_culture(lib) return lib:GetCurrentCulture() end
local function to_string(v) return v:ToString() end
local function subsystem_of(lib, pc, class) return lib:GetLocalPlayerSubSystemFromPlayerController(pc, class) end
local function gamepad_of(sub) return sub:GetCurrentGamepadName() end

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

local function text_of(v)
	if type(v) == "string" then return v end
	local ok, s = pcall(to_string, v)
	return ok and type(s) == "string" and s or nil
end

local function culture(gi)
	local lib = gi and PanelCalls.ok(PanelCalls.GAME_CULTURE) and find(GAME_LIBRARY)
	if lib then
		local ok, v = pcall(game_culture, lib, gi)
		local c = ok and text_of(v) or nil
		if c ~= nil and c ~= "" then return c end
	end
	lib = PanelCalls.ok(PanelCalls.ENGINE_CULTURE) and find(ENGINE_LIBRARY)
	if lib then
		local ok, v = pcall(engine_culture, lib)
		return ok and text_of(v) or nil
	end
	return nil
end

-- The panel's language for the game's: "en", "zh-Hans" or "zh-Hant" (dynamic_fov_panel_texts.lua).
function M.language(gi)
	return Texts.lang_of(culture(gi))
end

-- The local player's subsystem of the class at class_path, asked of the controller pc through the engine's library
-- (verified in game), never looked for among the objects; nil when not given.
function M.subsystem(pc, class_path)
	if not PanelCalls.ok(PanelCalls.FROM_PC) then return nil end
	local lib, class = find(SUBSYSTEMS), find(class_path)
	if lib == nil or class == nil then return nil end
	local ok, sub = pcall(subsystem_of, lib, pc, class)
	return ok and U.is_valid(sub) and sub or nil
end

-- The controller's name as the game gives it ("PS5" for a DualSense, seen in play), or nil.
function M.gamepad(pc)
	if not PanelCalls.ok(PanelCalls.GAMEPAD_NAME) then return nil end
	local sub = M.subsystem(pc, PanelCalls.COMMON_INPUT)
	if sub == nil then return nil end
	local ok, v = pcall(gamepad_of, sub)
	return ok and text_of(v) or nil
end

return M
