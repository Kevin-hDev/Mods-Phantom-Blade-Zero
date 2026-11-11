-- Every value of the panel's look, and nothing else holds one: places on the screen, sizes, colours, font sizes, and
-- how fast an arrow held with the mouse steps. The three columns are the layout chosen among the mock-ups (A), the list
-- and the settings widened after the 0.3.0 trial so that our mods' texts fit on one line (D87); the rows' height, the
-- margins, the font sizes and the colours are those of Dynamic FOV 1.0.4's panel (dynamic_fov_panel_make.lua and
-- dynamic_fov_panel_view.lua), whose look was tried in play.

local M = {}

-- ESlateVisibility.
M.VISIBLE, M.COLLAPSED, M.HIDDEN, M.HIT_TEST_INVISIBLE, M.SELF_HIT_TEST_INVISIBLE = 0, 1, 2, 3, 4
-- HIDDEN keeps its room, which COLLAPSED gives up: an overlay is as wide as its widest child that is not collapsed,
-- and only a collapsed child goes unmeasured (SOverlay::ComputeDesiredSize and SWidget::Prepass_ChildLoop, Unreal 5.7,
-- source unique), so a word hidden there still widens its box.
M.FILL, M.START, M.CENTRE, M.END = 0, 1, 2, 3   -- EHorizontalAlignment and EVerticalAlignment: left or top first
-- ETextOverflowPolicy: a text too long for its room ends with "…". The engine cuts a text at its clipping area, not at
-- its own room (TextBlock.h, "doesn't fit within the clip rect"; SlateTextLayout.cpp line 194): without ClipToBounds
-- (EWidgetClipping) a label ran under its value and a mod's title under "Off" in 0.2.0 and 0.3.0 (captures of the
-- trials).
M.ELLIPSIS, M.CLIP_TO_BOUNDS = 1, 1
M.FILL_SIZE = { SizeRule = 1, Value = 1.0 }   -- a box's child that takes the room left
M.Z_ORDER = 80

-- Places, in fractions of the screen. The columns stick to the right edge: the list, the settings, the descriptions.
M.TOP, M.BOTTOM = 0.06, 0.95
M.HEADER = 0.075                  -- a column's head: its title and a smaller text under it; its body starts below
M.SIDE, M.GAP = 0.025, 0.02       -- the right margin; between two columns
-- 12.5 and 25 % until 0.3.0. The list holds "Vault & Climb Anywhere" (244 units) and "Mod Panel 示例模组" with "已关闭" (209
-- and 64); the settings, "Air jump: keyboard and mouse" (305) beside the arrows and "Middle mouse button" (216). Widths
-- measured on a capture of 7 November 2026: the game's text is Segoe UI's at 22.45 points or less for a font size of
-- 18; Chinese, one em (24) a sign. The list widened from 17.5 to 21 % in 0.7.0 (D156, D163), to the left, the settings
-- kept: the head's names, beside their arrows, were cut (trial of 0.6.0), and the longest, "Sfondo del pannello" and
-- "Tạm Dừng Trò Chơi", filled their room. A quarter wider in 1.0.3 (D183), to the left again: each mod's line takes its
-- On/Off switch, and without it nearly every mod's title would be cut.
local LIST_WIDTH, SETTINGS_WIDTH, DESCRIPTIONS_WIDTH = 0.2625, 0.345, 0.165
M.DESCRIPTIONS = { 1 - M.SIDE - DESCRIPTIONS_WIDTH, 1 - M.SIDE }
M.SETTINGS = { M.DESCRIPTIONS[1] - M.GAP - SETTINGS_WIDTH, M.DESCRIPTIONS[1] - M.GAP }
M.LIST = { M.SETTINGS[1] - M.GAP - LIST_WIDTH, M.SETTINGS[1] - M.GAP }
M.STRIP = M.LIST[1] - M.SIDE      -- the backdrop is full from here to the right edge
-- The descriptions hidden (D90): the list and the settings slid to the right edge, the backdrop narrowed with them.
M.NARROW_SETTINGS = { 1 - M.SIDE - SETTINGS_WIDTH, 1 - M.SIDE }
M.NARROW_LIST = { M.NARROW_SETTINGS[1] - M.GAP - LIST_WIDTH, M.NARROW_SETTINGS[1] - M.GAP }
M.NARROW_STRIP = M.NARROW_LIST[1] - M.SIDE

-- Sizes, in the screen's units (a 1080 screen is 1080 high). A row of the settings and an entry of the list are as high
-- as the game's own settings rows. In a column of 34.5 % (662), two arrows and their value leave the label 320 after
-- its gap, a bar and its value 344. The list's entry (26.25 %, D183) leaves its title what its diamond and its switch
-- leave, the switch as wide as the language's longer On or Off (not measured in game). The value beside a bar holds
-- "游戏原有" (96); between the arrows, "Middle mouse button".
M.ROW_HEIGHT, M.ENTRY_HEIGHT, M.LINE_HEIGHT = 44, 40, 2
M.SLIDER_WIDTH, M.VALUE_WIDTH, M.CHOICE_WIDTH, M.ARROW_SIZE = 150, 104, 230, 24
M.TITLE_SIZE, M.TEXT_SIZE, M.SMALL_SIZE = 24, 18, 16
M.NO_PADDING = { Left = 0, Top = 0, Right = 0, Bottom = 0 }
M.ROW_PADDING = { Left = 24, Top = 0, Right = 24, Bottom = 0 }
M.ENTRY_PADDING = { Left = 16, Top = 0, Right = 12, Bottom = 0 }
M.EMPTY_PADDING = { Left = 16, Top = 12, Right = 12, Bottom = 0 }   -- the phrase of an empty list, under the line
M.LABEL_PADDING = { Left = 0, Top = 0, Right = 16, Bottom = 0 }   -- after a label or a title cut: never touching
M.TITLE_PADDING = { Left = 0, Top = 0, Right = 0, Bottom = 2 }
M.TEXT_PADDING = { Left = 0, Top = 12, Right = 0, Bottom = 0 }   -- the descriptions, and Close under the rows
M.FOOTER_GAP = "   "              -- between Close and its keys
-- The help under Close: two lines high whichever device's line shows, so the rows above never move (a line of the
-- small font is about 21 high); its commands apart by HINT_GAP.
M.HINTS_HEIGHT, M.HINT_GAP = 44, "   "
-- Between a command's keys and its word: a space no line breaks at (U+00A0), so a key never ends a line apart from
-- its word, as "X" did before "설명" in Korean (trial of 0.6.0).
M.HINT_JOIN = "\194\160"
M.HINTS_PADDING = { Left = 0, Top = 8, Right = 0, Bottom = 0 }
-- A controller button's icon: in the help, about the small font's height; as a row's value, a little above the text's.
M.HINT_ICON_SIZE, M.ICON_SIZE = 22, 28
-- The favourites' icon (D178), left of a mod's title in the list: the game's tracking diamond of the main quest. Read
-- from Mod Panel's copy of it, beside the scripts (D184); the game's own texture when that file cannot be read, though
-- it is not always in memory (discovery 28).
M.FAVORITE_FILE = "Icons/favorite.png"
M.FAVORITE_ICON = "/Game/PBZContent/UI/InGame/Quest/T_Track_Story.T_Track_Story"
M.FAVORITE_SIZE = 24
M.FAVORITE_PADDING = { Left = 0, Top = 0, Right = 10, Bottom = 0 }
-- The head of the list (D92), its items as high as a mod of the list. Between its arrows, a value of 52 at least holds
-- "90 %" (49) and "开启" (48), with the model of D87, and as much as the language's On and Off take: "Encendido" ran
-- over its right arrow (captures of 10 November 2026, D183). "Panel background", measured to fit, was cut in the game
-- at 0.7.0: the item is named "Background" since 0.7.1. A box CHECK_SIZE wide, pale, its mark CHECK_INSET inside when
-- checked.
M.HEAD_VALUE_WIDTH, M.CHECK_SIZE = 52, 18
M.CHECK_INSET = { Left = 4, Top = 4, Right = 4, Bottom = 4 }
M.CHECK_EDGE = { R = 1, G = 1, B = 1, A = 0.35 }
M.CHECK_EDGE_DARK = { R = 0.0212, G = 0.0212, B = 0.0212, A = 0.35 }   -- on the chosen band
-- The bar runs from 0 to 1: a value's place on it (Values.fraction), whatever the row.
M.SLIDER_STEP = 0.01
-- An arrow held with the mouse on a number: a step at the press, then one every HOLD_EVERY seconds from HOLD_DELAY on,
-- of 1 step, then 2 after a second held, then 5 after two.
M.HOLD_DELAY, M.HOLD_EVERY = 0.4, 0.1
M.HOLD_STEPS = { { 0, 1 }, { 1, 2 }, { 2, 5 } }   -- { seconds held, steps each time }
-- The controller's combination: its two buttons pressed at most this far apart open or close the panel (D136).
M.COMBO_WINDOW = 0.25
-- After the panel lets go of the keys held, a button read let go is still held for this long: longer than the
-- engine's first repeat, 0.2 s (mod_panel_flush.lua, D142).
M.FLUSH_QUIET = 0.3

-- Interface colours are linear, not sRGB. The menu's row text is white, dark on the selected band (PanelProbe pass 2).
M.WHITE = { R = 1, G = 1, B = 1, A = 1 }
M.DARK = { R = 0.0212, G = 0.0212, B = 0.0212, A = 1 }
M.GREY = { R = 1, G = 1, B = 1, A = 0.4 }
M.DARK_GREY = { R = 0.0212, G = 0.0212, B = 0.0212, A = 0.45 }
M.SOFT = { R = 1, G = 1, B = 1, A = 0.65 }
M.CLEAR = { R = 0, G = 0, B = 0, A = 0 }
M.LIGHT = { R = 0.8, G = 0.8, B = 0.8, A = 0.9 }   -- the selected band when the menu's is not in memory
M.BAND = { R = 1, G = 1, B = 1, A = 1 }       -- a row's band as the game draws it; CLEAR hides it, under a title
-- The favourites' icon: gold as the game draws it on a favourite, darkened on the others (mock-up B chosen by Kevin, 10
-- November 2026: 30 % of its brightness, 0.3 in sRGB, 0.073 in linear).
M.FAVORITE_ON = M.WHITE
M.FAVORITE_OFF = { R = 0.073, G = 0.073, B = 0.073, A = 1 }
-- A mod's switch in the list (D183, mock-up C chosen by Kevin, 10 November 2026): On in the diamond's gold (its most
-- frequent colour, 224, 184, 112 in sRGB), darker on the chosen band (128, 90, 22), as that band's text is; Off as
-- GREY. Gold on every backdrop: Kevin found Dark gold and Beige readable.
M.SWITCH_ON = { R = 0.745, G = 0.479, B = 0.162, A = 1 }
M.SWITCH_ON_DARK = { R = 0.216, G = 0.102, B = 0.008, A = 1 }
M.SWITCH_WORD_PADDING = { Left = 6, Top = 0, Right = 6, Bottom = 0 }   -- between the switch's word and its arrows
-- The chosen band, faint, on the list's entry under the pointer: lit enough to follow the mouse, never mistaken for the
-- chosen mod, whose band is whole (D55).
M.HOVER_OPACITY = 0.3
-- The backdrop's colours, by the values of the Background color row (D177): all dark, so that white text stays
-- readable over them. DarkGrey is the backdrop of every version before 1.0.2.
M.BACKDROPS = {
	DarkGrey = { R = 0.01, G = 0.011, B = 0.014 },
	Black = { R = 0, G = 0, B = 0 },
	Navy = { R = 0.005, G = 0.009, B = 0.034 },
	Crimson = { R = 0.045, G = 0.004, B = 0.005 },
	Forest = { R = 0.004, G = 0.021, B = 0.008 },
	Plum = { R = 0.023, G = 0.005, B = 0.032 },
	Slate = { R = 0.016, G = 0.023, B = 0.037 },
	Sepia = { R = 0.032, G = 0.016, B = 0.007 },
	-- Lighter than the others, still about 7 to 1 against white text (Dark gold about 9 to 1).
	Beige = { R = 0.117, G = 0.091, B = 0.058 },
	DarkGold = { R = 0.107, G = 0.065, B = 0.007 },
}
M.BACKDROP = "DarkGrey"   -- when Mod Panel's descriptor has no Background color row to give its default
-- The backdrop's fade: look C of Dynamic FOV, 55 % dark over 6 % of the width, in 96 bands (8 showed as columns).
M.FADE_ALPHA, M.FADE_WIDTH, M.FADE_STEPS = 0.55, 0.06, 96

return M
