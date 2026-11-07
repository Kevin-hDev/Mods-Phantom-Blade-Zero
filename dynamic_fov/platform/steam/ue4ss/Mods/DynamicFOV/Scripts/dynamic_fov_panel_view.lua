-- The panel on the screen (1.0.2): built once under the game instance, then hidden and shown, never destroyed by the
-- mod (PanelProbe pass 5). On the screen, even hidden, the engine keeps it; taken off the screen by the game (a load)
-- it may be freed at any time, so it is forgotten, never touched again, and built anew at the next opening. It reads
-- what the pointer does (the row under it, the buttons, the sliders) and shows what the panel gives it, setting a text,
-- a colour or a value only when it changes. After the build it hands the game no object: the row under the pointer
-- only shows its own selected band, built in each row (pass 6, after the crashes of passes 4 and 5).

local U = require("dynamic_fov_unreal")
local Pieces = require("dynamic_fov_panel_pieces")
local Make = require("dynamic_fov_panel_make")
local Backdrop = require("dynamic_fov_panel_backdrop")

local M = {}

local Z_ORDER = 80
local TITLE_SIZE, SMALL_SIZE, BUTTON_SIZE = 24, 16, 18
-- The explanation's room is kept whether it has two lines or four, so nothing below it moves.
local HELP_HEIGHT, HELP_WRAP = 90, 600
-- From 6 % since the backdrop's row (1.0.3, 8 before), with the rows at 44 (dynamic_fov_panel_make.lua).
local TOP, BOTTOM, SIDE = 0.06, 0.95, 0.025

local W = nil                     -- the built panel
local built = 0                   -- panels built in this session, for names no other object has
-- What the last read found, one table used again at each frame.
local R = { over = nil, moved = {}, click = {}, restore = false, close = false }

-- Named functions for pcall rather than a new closure at each frame.
local function set_text(tb, s) tb:SetText(FText(s)) end
local function set_visibility(w, v) w:SetVisibility(v) end
local function set_enabled(w, on) w:SetIsEnabled(on) end
local function set_value(slider, v) slider:SetValue(v) end
local function in_viewport(w) return w:IsInViewport() end
local function hovered(w) return w:IsHovered() end
local function pressed(b) return b:IsPressed() end
local function value_of(slider) return slider:GetValue() end
local function wrap_at(tb, width) tb.WrapTextAt = width end

local function build(outer, lines, log)
	built = built + 1
	local suffix = tostring(os.time()) .. "_" .. built
	local function named(class, owner, name)
		return StaticConstructObject(Make.class(class), owner,
			FName("DynamicFOV_" .. name .. "_" .. suffix))
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
	for i, line in ipairs(lines) do
		if line.kind then
			w.rows[i] = B.row(box, line)
			w.labels[i] = w.rows[i].label
		else
			w.labels[i] = B.heading(box)
		end
	end
	w.help = B.text("", "font_text", SMALL_SIZE, Make.SOFT)
	-- A property, not a function: set before the panel reaches the screen, where the engine reads it.
	local ok, err = pcall(wrap_at, w.help, HELP_WRAP)
	if not ok then log("panel: the explanation will not wrap (%s)", tostring(err)) end
	box:AddChildToVerticalBox(B.sized(w.help, nil, HELP_HEIGHT)):SetPadding({ Left = 0, Top = 16, Right = 0, Bottom = 0 })
	local bottom = B.new("HorizontalBox")
	box:AddChildToVerticalBox(bottom):SetPadding({ Left = 0, Top = 12, Right = 0, Bottom = 0 })
	w.restore = B.text_button(BUTTON_SIZE, Make.SOFT)
	bottom:AddChildToHorizontalBox(w.restore.button)
	w.close = B.text_button(BUTTON_SIZE, Make.SOFT)
	local close_slot = bottom:AddChildToHorizontalBox(w.close.button)
	close_slot:SetSize({ SizeRule = 1, Value = 1.0 })
	close_slot:SetHorizontalAlignment(Make.RIGHT)
	root:SetVisibility(Make.COLLAPSED)
	canvas:SetVisibility(Make.SELF_HIT_TEST_INVISIBLE)
	root:AddToViewport(Z_ORDER)
	return w, missing
end

-- Builds the panel under outer, the game instance, for the panel's lines (dynamic_fov_panel_rows.lua), hidden.
-- Returns true and the names of the game's pieces not found, or false and why.
function M.build(outer, lines, log)
	W = nil
	local ok, w, missing = pcall(build, outer, lines, log)
	if not ok then return false, tostring(w) end
	W = w
	return true, missing
end

-- Whether a built panel is on the screen. One the game took off it is forgotten.
function M.alive()
	if W == nil then return false end
	if U.is_valid(W.root) then
		local ok, on = pcall(in_viewport, W.root)
		if ok and on == true then return true end
	end
	W = nil
	return false
end

-- Shows or hides the built panel; returns whether that worked, and why not.
function M.show(on)
	if not M.alive() then return false, "no panel on the screen" end
	return pcall(set_visibility, W.root, on and Make.SELF_HIT_TEST_INVISIBLE or Make.COLLAPSED)
end

-- Calls into the game the game refused, counted for the panel to say (dynamic_fov_panel.lua).
local refusals = 0
local function tried(ok)
	if not ok then refusals = refusals + 1 end
	return ok
end

function M.refusals() return refusals end

-- Sets a text only when it changes: each change is a call into the game. What the game refused is kept as not shown,
-- so the next time the panel gives it, it is set again: the memory of what shows never holds what does not.
local function text(tb, s)
	if tb == nil or W.shown[tb] == s then return end
	if tried(pcall(set_text, tb, s)) then W.shown[tb] = s end
end

function M.title(s) if W then text(W.title, s) end end

-- The backdrop opacity % dark, set again only when it changes or the game refused a band.
function M.backdrop(opacity)
	if W == nil or W.opacity == opacity then return end
	if Backdrop.paint(W.bands, opacity, tried) then W.opacity = opacity end
end

function M.label(i, s) if W then text(W.labels[i], s) end end
function M.view_line(s) if W then text(W.view_line, s) end end
function M.help(s) if W then text(W.help, s) end end

function M.buttons(restore, close)
	if W == nil then return end
	text(W.restore.text, restore)
	text(W.close.text, close)
end

-- Row i: its value's text and value; locked, it waits for another setting (grey, its slider or arrows off); selected,
-- the pointer is on it (the menu's selected band, dark text). A slider is moved only by more than half a step from
-- where it is, so a slider being dragged is never pulled back to the step.
function M.row(i, value_text, value, locked, selected)
	local r = W and W.rows[i]
	if r == nil then return end
	text(r.value, value_text)
	local look = (selected and "selected" or "normal") .. (locked and ", locked" or "")
	if r.look ~= look then
		local colour = selected and (locked and Make.DARK_GREY or Make.DARK) or (locked and Make.GREY or Make.WHITE)
		local ok1 = tried(pcall(Make.paint, r.label, colour))
		local ok2 = tried(pcall(Make.paint, r.value, colour))
		local ok3 = tried(pcall(set_visibility, r.band, selected and Make.HIT_TEST_INVISIBLE or Make.COLLAPSED))
		if ok1 and ok2 and ok3 then r.look = look end
	end
	if r.locked ~= locked then
		local ok = true
		for _, w in ipairs({ r.slider or false, r.left or false, r.right or false }) do
			if w and not tried(pcall(set_enabled, w, not locked)) then ok = false end
		end
		if ok then r.locked = locked end
	end
	-- Noted only once the slider holds it: a slider left at the engine's 0 would read as the player's move.
	if r.slider and (r.at == nil or math.abs(r.at - value) > r.half) and tried(pcall(set_value, r.slider, value)) then
		r.at = value
	end
end

-- A click: pressed at the last read and no longer, the pointer still on it. A press taken off the button and let go
-- elsewhere is no click, as with the engine's own buttons.
local function clicked(b)
	local okp, p = pcall(pressed, b)
	p = okp and p == true
	local was = W.down[b]
	W.down[b] = p
	if p or not was then return false end
	local okh, h = pcall(hovered, b)
	return okh and h == true
end

-- The text of a text button lights up under the pointer.
local function light(b)
	local ok, h = pcall(hovered, b.button)
	local on = ok and h == true
	if b.on == on then return end
	if tried(pcall(Make.paint, b.text, on and Make.WHITE or Make.SOFT)) then b.on = on end
end

-- What the pointer did since the last read: R.over, the row under it (nil for none); R.moved[i], the new value of a
-- slider the player moved; R.click[i], -1 or 1 for a left or right arrow clicked; R.restore and R.close, those
-- clicked. A slider not painted yet holds the engine's 0, no move of the player: read as such at the first opening, it
-- set every setting to 0 or its minimum (seen in play, 4 November 2026).
function M.read()
	R.over, R.restore, R.close = nil, false, false
	if W == nil then return R end
	for i, r in pairs(W.rows) do
		local ok, h = pcall(hovered, r.frame)
		if ok and h == true then R.over = i end
		R.moved[i], R.click[i] = nil, nil
		if r.slider then
			if r.at ~= nil then
				local okv, v = pcall(value_of, r.slider)
				v = okv and U.num(v) or nil
				if v ~= nil and v ~= r.at then R.moved[i], r.at = v, v end
			end
		else
			local left, right = clicked(r.left), clicked(r.right)
			R.click[i] = left and -1 or right and 1 or nil
		end
	end
	R.restore, R.close = clicked(W.restore.button), clicked(W.close.button)
	light(W.restore)
	light(W.close)
	return R
end

return M
