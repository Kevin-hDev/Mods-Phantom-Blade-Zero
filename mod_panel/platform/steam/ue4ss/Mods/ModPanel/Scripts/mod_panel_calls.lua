-- The engine functions Mod Panel calls, the kinds of their parameters, and their check before the first call. UE4SS
-- converts each Lua value to the kind a function wants; a value of another kind, or a missing one, can crash the game
-- past any pcall (crash audit of 4 November 2026): a game update that changes one keeps the panel closed instead of
-- crashing the game. Taken from Dynamic FOV 1.0.4 (dynamic_fov_calls.lua and dynamic_fov_panel_calls.lua). Kinds from
-- Unreal 5.7's source; PanelProbe pass 7 read most of the widgets' in the game (4 November 2026).

local U = require("mod_panel_unreal")
local Slices = require("mod_panel_slices")

local M = {}

-- Kinds the engine may describe two ways: a float or a double; an enum as an enum or as a byte (PanelProbe pass 7: the
-- overlay's alignments are bytes, a widget's visibility an enum).
local ALIAS = {
	number = { FloatProperty = true, DoubleProperty = true },
	enum = { EnumProperty = true, ByteProperty = true },
}

local function kind(prop)
	local ok, t = pcall(function() return prop:GetClass():GetFName():ToString() end)
	if not ok or type(t) ~= "string" then return "?" end
	if t == "StructProperty" then
		local oks, s = pcall(function() return prop:GetStruct():GetFName():ToString() end)
		t = t .. "<" .. (oks and type(s) == "string" and s or "?") .. ">"
	end
	return t
end

-- The kinds of the function's parameters, its return value left out, or nil when the function is not found.
local function params(path)
	local f = nil
	pcall(function() f = StaticFindObject(path) end)
	if not U.is_valid(f) then return nil end
	local list = {}
	local ok = pcall(function()
		f:ForEachProperty(function(prop)
			local okn, name = pcall(function() return prop:GetFName():ToString() end)
			if not (okn and name == "ReturnValue") then list[#list + 1] = kind(prop) end
		end)
	end)
	return ok and list or nil
end

-- Whether the function takes exactly these kinds, in this order; "number" and "enum" stand for the two ways above.
-- Also returns the kinds found, for the log.
local function takes(path, kinds)
	local list = params(path)
	if list == nil or #list ~= #kinds then return false, list end
	for i, k in ipairs(kinds) do
		if not (list[i] == k or (ALIAS[k] and ALIAS[k][list[i]])) then return false, list end
	end
	return true, list
end

M.UMG = "/Script/UMG."
local UMG, ENGINE = M.UMG, "/Script/Engine."
local COLOR, MARGIN = "StructProperty<LinearColor>", "StructProperty<Margin>"
local OBJECT, BOOL = "ObjectProperty", "BoolProperty"
-- { class, function, kinds }: the panel opens only when every one is as here.
local REQUIRED = {
	{ UMG .. "WidgetBlueprintLibrary", "SetInputMode_UIOnlyEx", { OBJECT, OBJECT, "enum", BOOL } },
	{ UMG .. "WidgetBlueprintLibrary", "SetInputMode_GameOnly", { OBJECT, BOOL } },
	{ ENGINE .. "GameplayStatics", "IsGamePaused", { OBJECT } },
	{ UMG .. "UserWidget", "AddToViewport", { "IntProperty" } },
	{ UMG .. "Widget", "IsInViewport", {} },
	{ UMG .. "Widget", "SetVisibility", { "enum" } },
	{ UMG .. "Widget", "IsHovered", {} },
	{ UMG .. "Widget", "SetIsEnabled", { BOOL } },
	{ UMG .. "Widget", "SetRenderScale", { "StructProperty<Vector2D>" } },
	{ UMG .. "Widget", "SetRenderOpacity", { "number" } },
	-- A text cut where its own room ends (D87): Widget.h line 610 in Unreal 5.7.
	{ UMG .. "Widget", "SetClipping", { "enum" } },
	{ UMG .. "ContentWidget", "SetContent", { OBJECT } },
	{ UMG .. "ButtonSlot", "SetPadding", { MARGIN } },
	{ UMG .. "ButtonSlot", "SetHorizontalAlignment", { "enum" } },
	{ UMG .. "ButtonSlot", "SetVerticalAlignment", { "enum" } },
	{ UMG .. "PanelWidget", "AddChild", { OBJECT } },
	{ UMG .. "Border", "SetBrush", { "StructProperty<SlateBrush>" } },
	{ UMG .. "Border", "SetBrushColor", { COLOR } },
	{ UMG .. "Border", "SetPadding", { MARGIN } },
	{ UMG .. "Image", "SetBrush", { "StructProperty<SlateBrush>" } },
	{ UMG .. "Image", "SetBrushFromTexture", { OBJECT, BOOL } },
	-- The icons' tint: Image.h line 68 in Unreal 5.7.
	{ UMG .. "Image", "SetColorAndOpacity", { COLOR } },
	{ UMG .. "Button", "IsPressed", {} },
	{ UMG .. "Button", "SetBackgroundColor", { COLOR } },
	{ UMG .. "TextBlock", "SetText", { "TextProperty" } },
	{ UMG .. "TextBlock", "SetFont", { "StructProperty<SlateFontInfo>" } },
	{ UMG .. "TextBlock", "SetColorAndOpacity", { "StructProperty<SlateColor>" } },
	{ UMG .. "TextBlock", "SetTextOverflowPolicy", { "enum" } },
	{ UMG .. "TextBlock", "SetAutoWrapText", { BOOL } },
	{ UMG .. "Slider", "SetMinValue", { "number" } },
	{ UMG .. "Slider", "SetMaxValue", { "number" } },
	{ UMG .. "Slider", "SetStepSize", { "number" } },
	{ UMG .. "Slider", "SetValue", { "number" } },
	{ UMG .. "Slider", "GetValue", {} },
	{ UMG .. "SizeBox", "SetWidthOverride", { "number" } },
	{ UMG .. "SizeBox", "SetHeightOverride", { "number" } },
	{ UMG .. "ScrollBox", "SetScrollOffset", { "number" } },
	{ UMG .. "ScrollBox", "GetScrollOffset", {} },
	{ UMG .. "ScrollBox", "GetViewFraction", {} },
	{ UMG .. "CanvasPanel", "AddChildToCanvas", { OBJECT } },
	{ UMG .. "CanvasPanelSlot", "SetAnchors", { "StructProperty<Anchors>" } },
	{ UMG .. "CanvasPanelSlot", "SetOffsets", { MARGIN } },
	{ UMG .. "VerticalBox", "AddChildToVerticalBox", { OBJECT } },
	{ UMG .. "VerticalBoxSlot", "SetPadding", { MARGIN } },
	{ UMG .. "VerticalBoxSlot", "SetSize", { "StructProperty<SlateChildSize>" } },
	{ UMG .. "HorizontalBox", "AddChildToHorizontalBox", { OBJECT } },
	{ UMG .. "HorizontalBoxSlot", "SetSize", { "StructProperty<SlateChildSize>" } },
	{ UMG .. "HorizontalBoxSlot", "SetPadding", { MARGIN } },   -- HorizontalBoxSlot.h line 48 (D87)
	{ UMG .. "HorizontalBoxSlot", "SetHorizontalAlignment", { "enum" } },
	{ UMG .. "HorizontalBoxSlot", "SetVerticalAlignment", { "enum" } },
	{ UMG .. "Overlay", "AddChildToOverlay", { OBJECT } },
	{ UMG .. "OverlaySlot", "SetPadding", { MARGIN } },
	{ UMG .. "OverlaySlot", "SetHorizontalAlignment", { "enum" } },
	{ UMG .. "OverlaySlot", "SetVerticalAlignment", { "enum" } },
}
-- Without these, only what needs them is off: the character's camera, whether a cinematic camera has the view, the
-- game's language (the game's own library as Mods Menu asks it, else the engine's; English without either), the
-- signal's folder made when missing (the game's text saver: text, then path, as ModPanelProbe saw it in the game).
M.CAMERA = { ENGINE .. "Actor", "GetComponentByClass", { "ClassProperty" } }
M.CINE = { "/Script/AdvancedThirdPersonCamera.ATPCCameraComponent", "IsCineCameraActive", {} }
M.GAME_CULTURE = { "/Script/ProjectPBZ.PBZBlueprintFunctionLibrary", "GetCurrentCulture", { OBJECT } }
M.ENGINE_CULTURE = { ENGINE .. "KismetInternationalizationLibrary", "GetCurrentCulture", {} }
M.TEXT_SAVER = { "/Script/EasyCsv.EasyCsv", "SaveStringToFileWithFullPath", { "StrProperty", "StrProperty" } }
-- The controller (D66 to D68), Unreal 5.7: WidgetBlueprintLibrary.h line 56, EnhancedInputSubsystemInterface.h
-- lines 260 and 269, SubsystemBlueprintLibrary.h line 46, PlayerController.cpp line 5979; the mapping context's and
-- IsInputKeyDown's kinds as PadProbe found them in the game. Without one of them the panel opens as in 0.2.0, without
-- the controller.
local EI, KEY = "/Script/EnhancedInput.", "StructProperty<Key>"
M.GAME_AND_UI = { UMG .. "WidgetBlueprintLibrary", "SetInputMode_GameAndUIEx", { OBJECT, OBJECT, "enum", BOOL, BOOL } }
M.ADD_CONTEXT = { EI .. "EnhancedInputSubsystemInterface", "AddMappingContext",
	{ OBJECT, "IntProperty", "StructProperty<ModifyContextOptions>" } }
M.REMOVE_CONTEXT = { EI .. "EnhancedInputSubsystemInterface", "RemoveMappingContext",
	{ OBJECT, "StructProperty<ModifyContextOptions>" } }
M.MAP_KEY = { EI .. "InputMappingContext", "MapKey", { OBJECT, KEY } }
M.FROM_PC = { ENGINE .. "SubsystemBlueprintLibrary", "GetLocalPlayerSubSystemFromPlayerController",
	{ OBJECT, "ClassProperty" } }
M.KEY_DOWN = { ENGINE .. "PlayerController", "IsInputKeyDown", { KEY } }
M.JUST_PRESSED = { ENGINE .. "PlayerController", "WasInputKeyJustPressed", { KEY } }
-- The left stick's axes (D86): PlayerController.cpp line 5989, read so in the game by ResumeProbe. Without it, the
-- stick does nothing in the panel; the D-pad still does.
M.ANALOG = { ENGINE .. "PlayerController", "GetInputAnalogKeyState", { KEY } }
-- The controller's name, for its icons in Auto (D73; CommonInputSubsystem.h, verified by ModPanelIcons in the game).
-- Without it, Xbox's icons in Auto.
M.COMMON_INPUT = "/Script/CommonInput.CommonInputSubsystem"
M.GAMEPAD_NAME = { M.COMMON_INPUT, "GetCurrentGamepadName", {} }
-- The device in use, for the open panel's input mode (D128; CommonInputSubsystem.h line 52). Without it, the panel's
-- mode whatever the device, and the first Cross of an opening may do nothing.
M.INPUT_TYPE = { M.COMMON_INPUT, "GetCurrentInputType", {} }
-- Freeze game (D95; discovery 8, its kinds as ModPanelProbe called it in the game). Without it, Freeze game does not
-- show.
M.PAUSE = { ENGINE .. "GameplayStatics", "SetGamePaused", { OBJECT, BOOL } }
-- The mouse's place (D100; WidgetLayoutLibrary.h line 92, no parameter). Without it, the pointer chooses nothing by
-- passing over.
M.MOUSE = { UMG .. "WidgetLayoutLibrary", "GetMousePositionOnPlatform", {} }

-- Checked too in the opening's slices, but not needed: their first use is in the frame that shows the panel, the
-- heaviest of an opening (audit of 0.5.1).
local AHEAD = { M.GAMEPAD_NAME, M.INPUT_TYPE }
local checked = {}                -- by "class:function": true when as here, else the kinds found for the log
local next_check = 1              -- the place in REQUIRED of the next function to check
local slices = {}

-- The name is made once and kept in f: M.ok runs at each frame, and a name made each time was garbage (audit of 0.4.3).
local function check(f)
	local name = f.name
	if name == nil then
		name = f[1] .. ":" .. f[2]
		f.name = name
	end
	if checked[name] == nil then
		local ok, found = takes(name, f[3])
		checked[name] = ok or (found and table.concat(found, ", ") or "not found")
	end
	return checked[name] == true, name
end

-- Checks the functions the panel needs in a slice of budget seconds (mod_panel_slices.lua): each looks itself up, and
-- a lookup can take milliseconds in a loaded game (PanelProbe), so at the first opening of a session the whole list
-- would freeze a frame (D38). Returns true once every one is as here, false while some are left, or nil and why: the
-- first that is not, and what was found.
function M.check_step(budget)
	local failed = nil
	local done = Slices.run(function()
		local f = REQUIRED[next_check] or AHEAD[next_check - #REQUIRED]
		if f == nil then return true end
		local ok, name = check(f)
		if not ok and next_check <= #REQUIRED then
			failed = string.format("%s is not the one this version knows (%s)", name, checked[name])
			return true
		end
		next_check = next_check + 1
		return next_check > #REQUIRED + #AHEAD
	end, budget, slices)
	if failed ~= nil then return nil, failed end
	return done
end

-- Whether one of the functions above, outside REQUIRED, can be called.
function M.ok(f)
	return (check(f))
end

return M
