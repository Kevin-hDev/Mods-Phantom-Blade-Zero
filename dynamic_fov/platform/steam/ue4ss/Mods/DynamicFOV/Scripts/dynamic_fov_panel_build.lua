-- Builds the panel (1.0.2), under the game instance, hidden: a frameless strip at the right over the backdrop, with
-- the title, the line saying what the view shows, the rows and their group titles in a box that scrolls (1.0.5: they no
-- longer fit at 1080 lines), the explanation, and the buttons Restore defaults and Close, each with the icon of its
-- controller button for a PlayStation and an Xbox controller, hidden until the controller is used (1.0.5). Every piece
-- and every texture it shows is handed to it here; the panel hands the game no object afterwards (PanelProbe passes 4
-- and 5). A controller's icon is only looked for in memory, never loaded, as the game's other pieces
-- (dynamic_fov_panel_pieces.lua).

local U = require("dynamic_fov_unreal")
local Pieces = require("dynamic_fov_panel_pieces")
local Make = require("dynamic_fov_panel_make")
local Backdrop = require("dynamic_fov_panel_backdrop")
local Names = require("dynamic_fov_panel_pad_names")

local M = {}

local Z_ORDER = 80
local TITLE_SIZE, SMALL_SIZE, BUTTON_SIZE = 24, 16, 18
-- The explanation's room is kept whether it has two lines or four, so nothing below it moves.
local HELP_HEIGHT, HELP_WRAP = 90, 600
-- From 6 % since the backdrop's row (1.0.3, 8 before), with the rows at 44 (dynamic_fov_panel_make.lua).
local TOP, BOTTOM, SIDE = 0.06, 0.95, 0.025

local built = 0                   -- panels built in this session, for names no other object has

local function wrap_at(tb, width) tb.WrapTextAt = width end

local function find(path)
	local ok, o = pcall(StaticFindObject, path)
	return ok and U.is_valid(o) and o or nil
end

-- The icons of button for each brand the game holds in memory; the names of those it does not go to absent.
local function textures(button, absent)
	local out = {}
	for _, brand in ipairs(Names.BRANDS) do
		local path = Names.icon(button, brand)
		out[brand] = find(path)
		if out[brand] == nil then absent[#absent + 1] = path:match("([^%.]+)$") end
	end
	return out
end

-- Builds the panel for lines (dynamic_fov_panel_rows.lua). Returns its pieces, the names of the game's pieces not
-- found and those of the controller's icons not found; throws when a step fails.
function M.build(outer, lines, log)
	built = built + 1
	local suffix = tostring(os.time()) .. "_" .. built
	local function named(class, owner, name)
		return StaticConstructObject(Make.class(class), owner, FName("DynamicFOV_" .. name .. "_" .. suffix))
	end
	local root = named("UserWidget", outer, "Panel")
	local tree = named("WidgetTree", root, "Tree")
	root.WidgetTree = tree
	local canvas = named("CanvasPanel", tree, "Canvas")
	tree.RootWidget = canvas
	local got, missing, found = Pieces.in_memory()
	log("panel: building, the game's %d pieces in memory", found)
	local B = Make.builder(tree, got)
	local bands = Backdrop.build(B, canvas)
	local box = B.new("VerticalBox")
	B.place(canvas, box, Make.LEFT + SIDE, TOP, 1 - SIDE, BOTTOM)
	local w = { root = root, rows = {}, labels = {}, shown = {}, down = {}, bands = bands }
	w.title = B.text("", "font_text", TITLE_SIZE, Make.WHITE)
	box:AddChildToVerticalBox(w.title):SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 2 })
	w.view_line = B.text("", "font_text", SMALL_SIZE, Make.SOFT)
	box:AddChildToVerticalBox(w.view_line):SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 6 })
	box:AddChildToVerticalBox(B.line())
	-- The rows take the room the other pieces leave, and scroll in it.
	w.scroll = B.new("ScrollBox")
	box:AddChildToVerticalBox(w.scroll):SetSize(Make.FILL_SIZE)
	local rows_box = B.new("VerticalBox")
	w.scroll:AddChild(rows_box)
	for i, line in ipairs(lines) do
		if line.kind then
			w.rows[i] = B.row(rows_box, line)
			w.labels[i] = w.rows[i].label
		else
			w.labels[i] = B.heading(rows_box)
		end
	end
	w.help = B.text("", "font_text", SMALL_SIZE, Make.SOFT)
	-- A property, not a function: set before the panel reaches the screen, where the engine reads it.
	local ok, err = pcall(wrap_at, w.help, HELP_WRAP)
	if not ok then log("panel: the explanation will not wrap (%s)", tostring(err)) end
	box:AddChildToVerticalBox(B.sized(w.help, nil, HELP_HEIGHT)):SetPadding({ Left = 0, Top = 16, Right = 0, Bottom = 0 })
	local bottom = B.new("HorizontalBox")
	box:AddChildToVerticalBox(bottom):SetPadding({ Left = 0, Top = 12, Right = 0, Bottom = 0 })
	local absent = {}
	w.restore = B.icon_button(BUTTON_SIZE, Make.SOFT, Names.BRANDS, textures(Names.TRIANGLE, absent))
	bottom:AddChildToHorizontalBox(w.restore.button)
	w.close = B.icon_button(BUTTON_SIZE, Make.SOFT, Names.BRANDS, textures(Names.CIRCLE, absent))
	local close_slot = bottom:AddChildToHorizontalBox(w.close.button)
	close_slot:SetSize(Make.FILL_SIZE)
	close_slot:SetHorizontalAlignment(Make.RIGHT)
	root:SetVisibility(Make.COLLAPSED)
	canvas:SetVisibility(Make.SELF_HIT_TEST_INVISIBLE)
	root:AddToViewport(Z_ORDER)
	return w, missing, absent
end

return M
