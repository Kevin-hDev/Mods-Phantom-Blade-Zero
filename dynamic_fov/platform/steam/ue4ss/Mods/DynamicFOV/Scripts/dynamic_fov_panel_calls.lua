-- The engine functions the panel calls, and the kinds of their parameters, checked before the panel is first built
-- (dynamic_fov_calls.lua): a game update that changes one keeps the panel closed instead of crashing the game. Kinds
-- from Unreal 5.7's source; PanelProbe pass 7 read most of them in the game (4 November 2026).

local Calls = require("dynamic_fov_calls")

local M = {}

-- Where the engine's widget classes and functions are.
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
	{ UMG .. "ContentWidget", "SetContent", { OBJECT } },
	{ UMG .. "Border", "SetBrush", { "StructProperty<SlateBrush>" } },
	{ UMG .. "Border", "SetBrushColor", { COLOR } },
	{ UMG .. "Border", "SetPadding", { MARGIN } },
	{ UMG .. "Image", "SetBrush", { "StructProperty<SlateBrush>" } },
	{ UMG .. "Image", "SetBrushFromTexture", { OBJECT, BOOL } },
	{ UMG .. "Button", "IsPressed", {} },
	{ UMG .. "Button", "SetBackgroundColor", { COLOR } },
	{ UMG .. "TextBlock", "SetText", { "TextProperty" } },
	{ UMG .. "TextBlock", "SetFont", { "StructProperty<SlateFontInfo>" } },
	{ UMG .. "TextBlock", "SetColorAndOpacity", { "StructProperty<SlateColor>" } },
	{ UMG .. "Slider", "SetMinValue", { "number" } },
	{ UMG .. "Slider", "SetMaxValue", { "number" } },
	{ UMG .. "Slider", "SetStepSize", { "number" } },
	{ UMG .. "Slider", "SetValue", { "number" } },
	{ UMG .. "Slider", "GetValue", {} },
	{ UMG .. "SizeBox", "SetWidthOverride", { "number" } },
	{ UMG .. "SizeBox", "SetHeightOverride", { "number" } },
	{ UMG .. "CanvasPanel", "AddChildToCanvas", { OBJECT } },
	{ UMG .. "CanvasPanelSlot", "SetAnchors", { "StructProperty<Anchors>" } },
	{ UMG .. "CanvasPanelSlot", "SetOffsets", { MARGIN } },
	{ UMG .. "VerticalBox", "AddChildToVerticalBox", { OBJECT } },
	{ UMG .. "VerticalBoxSlot", "SetPadding", { MARGIN } },
	{ UMG .. "HorizontalBox", "AddChildToHorizontalBox", { OBJECT } },
	{ UMG .. "HorizontalBoxSlot", "SetSize", { "StructProperty<SlateChildSize>" } },
	{ UMG .. "HorizontalBoxSlot", "SetHorizontalAlignment", { "enum" } },
	{ UMG .. "HorizontalBoxSlot", "SetVerticalAlignment", { "enum" } },
	{ UMG .. "Overlay", "AddChildToOverlay", { OBJECT } },
	{ UMG .. "OverlaySlot", "SetPadding", { MARGIN } },
	{ UMG .. "OverlaySlot", "SetHorizontalAlignment", { "enum" } },
	{ UMG .. "OverlaySlot", "SetVerticalAlignment", { "enum" } },
}
-- The game's language: the game's own library as Mods Menu asks it, else the engine's; English without either.
M.GAME_CULTURE = { "/Script/ProjectPBZ.PBZBlueprintFunctionLibrary", "GetCurrentCulture", { OBJECT } }
M.ENGINE_CULTURE = { ENGINE .. "KismetInternationalizationLibrary", "GetCurrentCulture", {} }

local checked = {}                -- by "class:function": true when as here, else the kinds found for the log

local function check(f)
	local name = f[1] .. ":" .. f[2]
	if checked[name] == nil then
		local ok, found = Calls.takes(f[1], f[2], f[3])
		checked[name] = ok or (found and table.concat(found, ", ") or "not found")
	end
	return checked[name] == true, name
end

-- Whether every function the panel needs is as here; else the first that is not, and what was found instead.
function M.check()
	for _, f in ipairs(REQUIRED) do
		local ok, name = check(f)
		if not ok then return false, string.format("%s is not the one this version knows (%s)", name, checked[name]) end
	end
	return true
end

-- Whether one of the functions above (M.GAME_CULTURE, M.ENGINE_CULTURE) can be called.
function M.ok(f)
	return (check(f))
end

return M
