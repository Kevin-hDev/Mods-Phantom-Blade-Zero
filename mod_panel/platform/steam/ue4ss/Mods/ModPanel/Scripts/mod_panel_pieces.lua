-- The game's own pieces for the panel, those of its settings menu (PanelProbe passes 2 and 3, 4 November 2026): the
-- row band (its brush, copied whole, margins included), the selected-row band, the slider's whole style, the arrow, the
-- line and the menu's two fonts. The menu's widget classes keep a template of the band and of the slider. Only what the
-- game holds in memory is taken; a piece it has not loaded (its settings menu not opened in this session) leaves a
-- plain piece in its place. Nothing is loaded here: all the mod's Lua runs inside UE4SS's lock, which UE4SS also
-- takes at each object the engine makes, on any thread (1ceefac, LuaMod.cpp, its StaticConstructObject callback), so a
-- load made there can wait for ever on the engine's loading thread. A LoadAsset in a controller tick froze the
-- game so on 4 November 2026. Taken from Dynamic FOV 1.0.4 (dynamic_fov_panel_pieces.lua). A piece is
-- looked for when a widget takes it: the panel is built in slices, over several frames, and the game may free a piece
-- in between. One not in memory is not looked for again until M.forget, at the start of a build: each miss walks
-- every object of the game (D174). The text font follows the panel's language (D154): each script the menu's font
-- lacks has the game's own font for it; a font not in memory leaves the menu's, said once.

local U = require("mod_panel_unreal")

local M = {}

local SETTINGS = "/Game/PBZContent/UI/Settings/"
local FONTS = "/Game/PBZContent/UI/Fonts/"
local ROW_CLASS = SETTINGS .. "Editors/W_SettingEntryBackground.W_SettingEntryBackground_C"
local SCALAR_CLASS = SETTINGS .. "Editors/W_SettingsListEntry_Scalar.W_SettingsListEntry_Scalar_C"
-- { name, path }, in the order a missing one is said.
local PIECES = {
	{ "row", ROW_CLASS .. ":WidgetTree.AnimBoundEntryBorder" },
	{ "slider", SCALAR_CLASS .. ":WidgetTree.Slider_SettingValue" },
	{ "selected_bar", SETTINGS .. "Texture/T_SettingsSelectedBar.T_SettingsSelectedBar" },
	{ "arrow", SETTINGS .. "Texture/T_SettingArrow.T_SettingArrow" },
	{ "line", "/Game/PBZContent/UI/UINew/HUD/T_Line_V2.T_Line_V2" },
	{ "font_text", FONTS .. "EN_Chaco-Light_Font.EN_Chaco-Light_Font" },
	{ "font_number", FONTS .. "YingNum_Font.YingNum_Font" },
}
local PATHS = {}
for _, p in ipairs(PIECES) do PATHS[p[1]] = p[2] end

-- The text font of the languages the menu's font does not show (EN_Chaco-Light_Font: no Hangul nor Thai, Cyrillic
-- only in its Chinese face, Mods Menu 0.9.2, source unique), each among the fonts the game holds in memory even in
-- English (PanelProbe, 4 November 2026, verified in game). Vietnamese: no font of the game says it is; Inter is one
-- that has its letters (verified in game, trial of 0.6.0). Traditional Chinese: the menu's font lacks some of its
-- characters (遊, 啟, 說: trial of 0.6.2, verified in game), TC_Body_Font lacks those only Simplified Chinese has
-- (trial of 0.6.0): each text takes the font of its own language (D159, D162).
local OWN_FONTS = { ja = "JP_zhuan_SMotoyaSinkaiPro-W3_Font", ko = "KR_FZCW_XZM_Body_Font",
	ru = "RU/AdelleSansCYR-Light_Font", th = "BreeTHA_Light_Font", vi = "Inter-Light-BETA_Font",
	["zh-Hant"] = "TC_Body_Font" }
-- The languages whose font draws a no-break space (U+00A0) as nothing: TC_Body_Font (trial of 0.6.1, verified in game).
local NO_BREAK_SPACE_LOST = { ["zh-Hant"] = true }
local S = { lang = "en", said = {} }
local found = U.finder()

local function font_path(file)
	return FONTS .. file .. "." .. file:match("([^/]+)$")
end

-- The pieces not in memory looked for again from now on: at the start of a build, and when the texts' fonts are.
function M.forget() found.forget() end

-- The texts' language from now on; whether it changed. report(fmt, ...) is told once a font not in memory.
function M.language(lang, report)
	if lang == S.lang then return false end
	S.lang, S.report = lang, report
	return true
end

-- Whether the text font of lang draws a no-break space (D160).
function M.no_break_space(lang)
	return not NO_BREAK_SPACE_LOST[lang]
end

-- The text font of lang (nil: the texts' language): the file of its own font, or "menu" for the menu's.
function M.text_font(lang)
	return OWN_FONTS[lang or S.lang] or "menu"
end

-- The piece name in memory now, or nil, and for the text font the key of the font it is (M.text_font's): the own font
-- of lang (nil: the texts' language, D159), else the menu's.
function M.find(name, lang)
	lang = lang or S.lang
	local own = name == "font_text" and OWN_FONTS[lang]
	if own then
		local o = found.find(font_path(own))
		if o ~= nil then return o, own end
		if not S.said[own] and S.report then
			S.said[own] = true
			S.report("pieces: %s not in memory, the %s texts in the menu's font", own, lang)
		end
	end
	return found.find(PATHS[name]), "menu"
end

-- The names of the pieces not in memory now, and how many are, for the log at the start of a build.
function M.missing()
	local missing = {}
	for _, p in ipairs(PIECES) do
		if M.find(p[1]) == nil then missing[#missing + 1] = p[1] end
	end
	return missing, #PIECES - #missing
end

return M
