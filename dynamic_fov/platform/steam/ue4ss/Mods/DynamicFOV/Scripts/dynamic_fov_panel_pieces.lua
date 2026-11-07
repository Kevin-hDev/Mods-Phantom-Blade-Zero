-- The game's own pieces for the panel, those of its settings menu (PanelProbe passes 2 and 3, 4 November 2026): the
-- row band (its brush, copied whole, margins included), the selected-row band, the slider's whole style, the arrow, the
-- line and the menu's two fonts. The menu's widget classes keep a template of the band and of the slider. Only what the
-- game holds in memory is taken; a piece it has not loaded (its settings menu not opened in this session) leaves a plain
-- piece in its place, said in the log. Nothing is loaded here: all the mod's Lua runs inside UE4SS's lock, which UE4SS
-- also takes at each object the engine makes, on any thread (1ceefac, LuaMod.cpp, its StaticConstructObject callback),
-- so a load made there can wait for ever on the engine's loading thread. Another mod's LoadAsset in its controller tick
-- froze the game so on 4 November 2026. Looked for again at each build: after a load the game may have freed them.

local U = require("dynamic_fov_unreal")

local M = {}

local SETTINGS = "/Game/PBZContent/UI/Settings/"
local ROW_CLASS = SETTINGS .. "Editors/W_SettingEntryBackground.W_SettingEntryBackground_C"
local SCALAR_CLASS = SETTINGS .. "Editors/W_SettingsListEntry_Scalar.W_SettingsListEntry_Scalar_C"
-- { name, path }, in the order a missing one is reported.
local PIECES = {
	{ "row", ROW_CLASS .. ":WidgetTree.AnimBoundEntryBorder" },
	{ "slider", SCALAR_CLASS .. ":WidgetTree.Slider_SettingValue" },
	{ "selected_bar", SETTINGS .. "Texture/T_SettingsSelectedBar.T_SettingsSelectedBar" },
	{ "arrow", SETTINGS .. "Texture/T_SettingArrow.T_SettingArrow" },
	{ "line", "/Game/PBZContent/UI/UINew/HUD/T_Line_V2.T_Line_V2" },
	{ "font_text", "/Game/PBZContent/UI/Fonts/EN_Chaco-Light_Font.EN_Chaco-Light_Font" },
	{ "font_number", "/Game/PBZContent/UI/Fonts/YingNum_Font.YingNum_Font" },
}

local function find(path)
	local ok, o = pcall(StaticFindObject, path)
	return ok and U.is_valid(o) and o or nil
end

-- The pieces in memory, by name, the names of the missing ones, and how many were found. Run on the game thread just
-- before a build; the table serves that build only, and the built panel holds what it shows.
function M.in_memory()
	local got, missing = {}, {}
	for _, p in ipairs(PIECES) do
		got[p[1]] = find(p[2])
		if got[p[1]] == nil then missing[#missing + 1] = p[1] end
	end
	return got, missing, #PIECES - #missing
end

return M
