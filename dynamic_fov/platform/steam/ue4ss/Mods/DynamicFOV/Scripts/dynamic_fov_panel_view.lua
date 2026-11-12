-- The panel on the screen (1.0.2): built once under the game instance (dynamic_fov_panel_build.lua), then hidden and
-- shown, never destroyed by the mod (PanelProbe pass 5). On the screen, even hidden, the engine keeps it; taken off the
-- screen by the game (a load) it may be freed at any time, so it is forgotten, never touched again, and built anew at
-- the next opening. It reads what the pointer does (the row under it, the buttons, the sliders) and shows what the
-- panel gives it, setting a text, a colour, a value, a scroll or an icon's visibility only when it changes. After the
-- build it hands the game no object: the chosen row only shows its own selected band, built in each row (pass 6, after
-- the crashes of passes 4 and 5), and a controller's icon is one built with the panel, shown or hidden (1.0.5).

local U = require("dynamic_fov_unreal")
local Make = require("dynamic_fov_panel_make")
local Backdrop = require("dynamic_fov_panel_backdrop")
local Build = require("dynamic_fov_panel_build")

local M = {}

local W = nil                     -- the built panel
local ICON_BUTTONS = { "restore", "close" }
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
local function offset_of(box) return box:GetScrollOffset() end
local function fraction_of(box) return box:GetViewFraction() end
local function set_offset(box, v) box:SetScrollOffset(v) end
local function full_name_of(w) return w:GetFullName() end

local function full_name(w)
	local ok, n = pcall(full_name_of, w)
	return ok and type(n) == "string" and n or nil
end

-- Builds the panel under outer, the game instance, for the panel's lines (dynamic_fov_panel_rows.lua), hidden.
-- Returns true, the names of the game's pieces not found and those of the controller's icons not found, or false and
-- why.
function M.build(outer, lines, log)
	W = nil
	local ok, w, missing, absent = pcall(Build.build, outer, lines, log)
	if not ok then return false, tostring(w) end
	W = w
	W.name = full_name(w.root)
	return true, missing, absent
end

-- Whether a built panel is on the screen. One the game took off it is forgotten, and so is one whose address
-- another object has taken since: UE4SS's IsValid answers for an address, and that object on the screen would pass
-- for the panel while the panel's pieces are destroyed ones (audit of 11 November 2026). The name is read only on an
-- object that exists: on a destroyed one the read crashes the game, and no pcall catches it.
function M.alive()
	if W == nil then return false end
	if U.is_valid(W.root) and full_name(W.root) == W.name then
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

-- Whether the button ("restore" or "close") has brand's icon: the game held its texture at the build.
function M.has_icon(which, brand)
	return W ~= nil and W[which].icons[brand] ~= nil
end

-- brand's icons shown before the two buttons, the others hidden; none for nil (1.0.5). Set again only when it
-- changes or the game refused one.
function M.icons(brand)
	if W == nil or W.icon_brand == (brand or false) then return end
	local ok = true
	for _, which in ipairs(ICON_BUTTONS) do
		for b, icon in pairs(W[which].icons) do
			local v = b == brand and Make.HIT_TEST_INVISIBLE or Make.COLLAPSED
			if not tried(pcall(set_visibility, icon, v)) then ok = false end
		end
	end
	if ok then W.icon_brand = brand or false end
end

-- Brings line i of n into the box's view, scrolling as little as it can (1.0.5):
-- every line is ROW_HEIGHT high, so the box's scroll offset and the share of its lines it shows tell which ones show.
-- A box that cannot say is left as it is.
function M.scroll_to(i, n)
	if W == nil or i == nil then return end
	local h = Make.ROW_HEIGHT
	local ok1, offset = pcall(offset_of, W.scroll)
	local ok2, fraction = pcall(fraction_of, W.scroll)
	offset, fraction = ok1 and U.num(offset), ok2 and U.num(fraction)
	if not offset or not fraction or fraction <= 0 then return end
	local view = fraction * n * h
	local top, bottom = (i - 1) * h, i * h
	if top < offset then
		tried(pcall(set_offset, W.scroll, top))
	elseif bottom > offset + view then
		tried(pcall(set_offset, W.scroll, bottom - view))
	end
end

-- Row i: its value's text and value; locked, it waits for another setting (grey, its slider or arrows off); selected,
-- it is the chosen row (the menu's selected band, dark text). A slider is moved only by more than half a step from
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
