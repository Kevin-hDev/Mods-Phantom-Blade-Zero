-- How the view sets what shows: a text, a colour, a visibility or a value is set in the game only when it changed, and
-- what the game refused is set again at the next frame, as the memory of what shows (shown, kept by the frame and gone
-- with it) never holds what does not. Taken out of mod_panel_view.lua, for mod_panel_view_head.lua too; forms of
-- Dynamic FOV 1.0.4's dynamic_fov_panel_view.lua.

local L = require("mod_panel_layout")
local Make = require("mod_panel_make")
local Icons = require("mod_panel_icons")
local Text = require("mod_panel_text")
local Written = require("mod_panel_written")

local M = {}

-- Calls the game refused, counted for the log.
local refusals = 0

-- Counts a call the game refused; returns ok.
function M.tried(ok)
	if not ok then refusals = refusals + 1 end
	return ok
end

function M.refusals() return refusals end

-- Named functions for pcall rather than a new closure at each frame. Every text Mod Panel shows goes through set_text,
-- made safe there whatever file or folder it came from (D106); the only other FText is the plain arrow's fixed "<" or
-- ">" (mod_panel_make.lua).
local function set_text(w, s) w:SetText(FText(Text.safe(s))) end
local function set_visibility(w, v) w:SetVisibility(v) end
local function set_colour(w, name) Make.paint(w, L[name]) end
M.set_brush = function(w, name) w:SetBrushColor(L[name]) end
M.set_width = function(w, v) w:SetWidthOverride(v) end
M.set_value = function(w, v) w:SetValue(v) end
M.set_opacity = function(w, v) w:SetRenderOpacity(v) end
M.set_tint = function(w, name) w:SetColorAndOpacity(L[name]) end
local function set_texture(w, t) w:SetBrushFromTexture(t, false) end

-- Sets what of w changed: prop names what fn(w, v) sets, and v is remembered once the game took it. shown: the frame's
-- memory of what shows.
function M.apply(shown, w, prop, v, fn)
	local s = shown[w]
	if s == nil then
		s = {}
		shown[w] = s
	end
	if s[prop] == v then return end
	if M.tried(pcall(fn, w, v)) then s[prop] = v end
end

-- The text s in w, in the font of the language its words come from (D159), asked at each call: the same words may
-- have been the panel's language's before, and borrowed now.
function M.text(sh, w, s)
	M.tried(Make.written(w, Written.from(s)))
	M.apply(sh, w, "text", s, set_text)
end
function M.visible(sh, w, v) M.apply(sh, w, "visibility", v, set_visibility) end
function M.colour(sh, w, name) M.apply(sh, w, "colour", name, set_colour) end
function M.on(yes, shows) return yes and shows or L.COLLAPSED end

-- Whether image w shows the texture at path, find(arg) giving it. It is looked for and set only when the texture w
-- shows changes, in this very frame (D75), and the image holds it from then on.
local function holds(sh, w, path, find, arg)
	if path == nil then return false end
	local s = sh[w]
	if s == nil then
		s = {}
		sh[w] = s
	end
	if s.icon == path then return true end
	local t = find(arg)
	if t == nil or not M.tried(pcall(set_texture, w, t)) then return false end
	s.icon = path
	return true
end

-- Whether image w shows the icon of the button name for the icons in use.
function M.icon(sh, w, name) return holds(sh, w, Icons.path(name), Icons.texture, name) end

-- Whether image w shows the favourites' diamond (D178).
function M.favorite(sh, w) return holds(sh, w, L.FAVORITE_ICON, Icons.favorite) end

return M
