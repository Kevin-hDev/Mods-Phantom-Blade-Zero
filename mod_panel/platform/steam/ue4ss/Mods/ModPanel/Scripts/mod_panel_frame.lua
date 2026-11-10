-- The panel's frame, built once under the game instance: the backdrop, then three columns. The list of mods: a title,
-- the count, the head of the list (mod_panel_frame_head.lua), a box that scrolls. The chosen mod's settings: its
-- title, a line under it for its state ("Settings not saved"), Show at its right end, a box that scrolls for the rows,
-- Restore defaults and Close below, then the help. The descriptions: Hide, then a text that wraps by itself. The places
-- of the columns and of the backdrop's bands are kept, to slide them when the descriptions hide (mod_panel_columns.lua,
-- D90). Never destroyed by the mod: only hidden or shown. On the screen,
-- even hidden, the engine keeps it; taken off the screen by the game (a load), it may be freed at any time, so it is
-- forgotten, never touched again, and built anew. Built in slices (D38): its root goes on the screen at once, hidden,
-- so the engine holds every piece made after it. Taken from Dynamic FOV 1.0.4 (build, alive and show of
-- dynamic_fov_panel_view.lua).

local U = require("mod_panel_unreal")
local L = require("mod_panel_layout")
local Make = require("mod_panel_make")
local Pieces = require("mod_panel_pieces")
local Backdrop = require("mod_panel_backdrop")
local Slices = require("mod_panel_slices")
local FrameHints = require("mod_panel_frame_hints")
local FrameHead = require("mod_panel_frame_head")
local Columns = require("mod_panel_columns")

local M = {}

local W = nil                     -- the frame, being built or built
local begun = 0                   -- frames begun in this session, for names no other object has
local said = {}                   -- the lines about the game's pieces already said
-- Builds that failed in this session, and the last reason. Each leaves its pieces on the screen, hidden, for ever, so
-- after MAX_FAILURES none is begun.
local MAX_FAILURES = 3
local failures, last_failure = 0, nil

local function failed(why)
	failures, last_failure = failures + 1, why
	return why
end

local function set_visibility(w, v) w:SetVisibility(v) end
local function in_viewport(w) return w:IsInViewport() end
local function name_of(w) return w:GetFName():ToString() end

-- The steps of frame F after its root, each making one object.
local function steps_of(F)
	local s = {}
	local function add(fn) s[#s + 1] = fn end
	for i = 1, Backdrop.BANDS do add(function() F.bands[i] = Backdrop.band(F.B, F.canvas, i, F.max) end) end
	-- A column's head, from TOP: its title, and a smaller line under it.
	local function head(x, title, sub, place)
		local box
		add(function()
			box = F.B.new("VerticalBox")
			F.slots[place] = F.B.place(F.canvas, box, x[1], L.TOP, x[2], L.TOP + L.HEADER)
		end)
		add(function()
			F[title] = F.B.text("font_text", L.TITLE_SIZE, L.WHITE, true)
			box:AddChildToVerticalBox(F[title]):SetPadding(L.TITLE_PADDING)
		end)
		add(function()
			F[sub] = F.B.text("font_text", L.SMALL_SIZE, L.SOFT, true)
			box:AddChildToVerticalBox(F[sub])
		end)
	end
	-- A column's body, from under the heads to BOTTOM, so the three start at the same height whatever their texts.
	local function body(x, name)
		add(function()
			F[name] = F.B.new("VerticalBox")
			F.slots[name] = F.B.place(F.canvas, F[name], x[1], L.TOP + L.HEADER, x[2], L.BOTTOM)
		end)
	end
	-- The game's line, then a box that scrolls with the room left.
	local function scroll(into, name)
		local size
		add(function()
			size = F.B.sized(nil, L.LINE_HEIGHT)
			F[into]:AddChildToVerticalBox(size)
		end)
		add(function() size:SetContent(F.B.image("line")) end)
		add(function()
			F[name] = F.B.new("ScrollBox")
			F[into]:AddChildToVerticalBox(F[name]):SetSize(L.FILL_SIZE)
		end)
	end
	head(L.LIST, "list_title", "list_sub", "list_head")
	body(L.LIST, "list_body")
	FrameHead.add(F, add)
	scroll("list_body", "list")
	FrameHead.add_phrase(F, add)
	head(L.SETTINGS, "title", "sub", "settings_head")
	Columns.add_corner(F, add, L.SETTINGS, "settings_bar", "show_button", "show_text")
	body(L.SETTINGS, "settings_body")
	scroll("settings_body", "rows")
	local footer
	add(function()
		footer = F.B.new("HorizontalBox")
		F.settings_body:AddChildToVerticalBox(footer):SetPadding(L.TEXT_PADDING)
	end)
	add(function()
		F.restore_button = F.B.button()
		footer:AddChildToHorizontalBox(F.restore_button):SetVerticalAlignment(L.CENTRE)
	end)
	add(function()
		F.restore_text = F.B.text("font_text", L.TEXT_SIZE, L.SOFT)
		F.restore_button:SetContent(F.restore_text)
	end)
	add(function()
		F.close_button = F.B.button()
		local slot = footer:AddChildToHorizontalBox(F.close_button)
		slot:SetSize(L.FILL_SIZE)
		slot:SetHorizontalAlignment(L.END)
	end)
	add(function()
		F.close_text = F.B.text("font_text", L.TEXT_SIZE, L.SOFT)
		F.close_button:SetContent(F.close_text)
	end)
	FrameHints.add(F, add)
	Columns.add_corner(F, add, L.DESCRIPTIONS, "descriptions_bar", "hide_button", "hide_text")
	body(L.DESCRIPTIONS, "descriptions_body")
	add(function()
		F.descriptions = F.B.text("font_text", L.SMALL_SIZE, L.SOFT)
		F.descriptions:SetAutoWrapText(true)
		F.descriptions_body:AddChildToVerticalBox(F.descriptions):SetPadding(L.TEXT_PADDING)
	end)
	return s
end

-- Begins a new frame under gi, the game instance: its root, tree and canvas, put on the screen hidden. A frame still on
-- the screen is kept: a new one would leave it there, hidden, for ever. max: the darkest backdrop the player may
-- choose, in %. report(line) is told which of the game's pieces are in memory, once for each different line. Returns
-- true, or false and why.
function M.start(gi, max, report)
	if M.alive() then return true end
	if failures >= MAX_FAILURES then
		return false, string.format("not built again after %d failures (%s)", failures, last_failure)
	end
	begun = begun + 1
	local suffix = tostring(os.time()) .. "_" .. begun
	-- columns: whether the places are those of the three columns (D90), as the frame is built.
	local F = { max = max, bands = {}, slots = {}, shown = {}, next = 1, done = false, visible = false,
		slices = {}, columns = true }
	F.name = "ModPanel_Panel_" .. suffix
	local ok, err = pcall(function()
		local function named(class, outer, name)
			return StaticConstructObject(Make.class(class), outer, FName("ModPanel_" .. name .. "_" .. suffix))
		end
		F.root = named("UserWidget", gi, "Panel")
		F.tree = named("WidgetTree", F.root, "Tree")
		F.root.WidgetTree = F.tree
		F.canvas = named("CanvasPanel", F.tree, "Canvas")
		F.tree.RootWidget = F.canvas
		F.root:SetVisibility(L.COLLAPSED)
		F.canvas:SetVisibility(L.SELF_HIT_TEST_INVISIBLE)
		F.root:AddToViewport(L.Z_ORDER)
	end)
	if not ok then return false, failed(tostring(err)) end
	F.B = Make.builder(F.tree)
	F.steps = steps_of(F)
	W = F
	Pieces.forget()
	local missing, found = Pieces.missing()
	local line = #missing == 0 and string.format("panel: the game's %d pieces in memory", found)
		or string.format("panel: not in memory, plain pieces in their place: %s", table.concat(missing, ", "))
	if not said[line] then
		said[line] = true
		report(line)
	end
	return true
end

-- Whether a frame is on the screen, whole or being built. One the game took off it is forgotten. Its name too (D103):
-- UE4SS's IsValid only looks its address up, and after a load another object may live at that address.
function M.alive()
	if W == nil then return false end
	if U.is_valid(W.root) then
		local named, name = pcall(name_of, W.root)
		local ok, on = false, nil
		if named and name == W.name then ok, on = pcall(in_viewport, W.root) end
		if ok and on == true then return true end
	end
	W = nil
	return false
end

-- Makes the frame's next pieces in a slice of budget seconds. Returns true once it is whole, false while pieces are
-- left, or nil and why: the build failed, or the game took the frame off the screen, and it is forgotten.
function M.build_step(budget)
	if W == nil then return nil, "no frame begun" end
	if W.done then return true end
	if not M.alive() then return nil, "taken off the screen while it was built" end
	local F = W
	local ok, done = pcall(Slices.run, function()
		F.steps[F.next]()
		F.next = F.next + 1
		return F.steps[F.next] == nil
	end, budget, F.slices)
	if not ok then
		W = nil
		return nil, failed(tostring(done))
	end
	if done then F.done, F.steps = true, nil end
	return done
end

-- Shows or hides the whole frame; returns whether that worked, and why not.
function M.show(on)
	if not M.alive() or not W.done then return false, "no panel on the screen" end
	local ok, err = pcall(set_visibility, W.root, on and L.SELF_HIT_TEST_INVISIBLE or L.COLLAPSED)
	if ok then W.visible = on end
	return ok, err
end

-- Whether the frame shows: then it takes no new piece.
function M.shows()
	return W ~= nil and W.visible
end

-- The whole frame's pieces, or nil. It does not ask the game: at each frame, the caller asks alive() before it, as a
-- frame the game took off the screen may be freed.
function M.get()
	return W ~= nil and W.done and W or nil
end

return M
