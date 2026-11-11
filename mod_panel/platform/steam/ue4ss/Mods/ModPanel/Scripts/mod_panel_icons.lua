-- The controller's icons: whose (ButtonIcons: Auto, PlayStation, Xbox), a button's name, and its texture when the game
-- has it in memory. In Auto, the controller's name the game gives is read at each opening, the panel hidden (D73). A
-- texture is only looked for, never loaded (D74), in the very frame it is set, and never kept from one frame to another
-- (D75): passes 4 and 5 of PanelProbe crashed on a texture only Lua held. One not in memory is not looked for again
-- until the next opening, and said once in the game: the button's name shows in its place. The favourites' diamond is
-- read from Mod Panel's own file instead (D184), and kept for its frame once an image of it holds it.

local U = require("mod_panel_unreal")
local L = require("mod_panel_layout")
local Names = require("mod_panel_pad_names")
local Device = require("mod_panel_device")
local Calls = require("mod_panel_calls")
local Folders = require("mod_panel_folders")

local M = {}

-- gamepad: the controller's name read at the last opening, nil when not read. brand: whose icons now. said: the paths
-- not in memory already said in the game, at most one per path of mod_panel_pad_names.lua and the favourites' one.
-- unread: the diamond's file could not be read at this opening.
local S = { gamepad = nil, brand = Names.XBOX, said = {}, report = nil, unread = false }
local found = U.finder()
local RENDERING = "/Script/Engine.Default__KismetRenderingLibrary"
local FAVORITE_FILE = (Folders.paths(debug.getinfo(1, "S").source) or ".") .. "/" .. L.FAVORITE_FILE
-- The diamond each frame shows, by the frame's memory of what shows: gone with the frame (weak keys).
local made = setmetatable({}, { __mode = "k" })

local function import(lib, path) return lib:ImportFileAsTexture2D(lib, path) end

-- Whose icons for the setting ButtonIcons and the controller's name gamepad (nil or "" when unknown).
function M.brand_of(setting, gamepad)
	if setting == Names.PLAYSTATION or setting == Names.XBOX then return setting end
	if type(gamepad) == "string" and gamepad:sub(1, 2) == "PS" then return Names.PLAYSTATION end
	return Names.XBOX
end

-- At each opening, the panel hidden, once mod_panel_device.lua has started: the controller's name read, the textures
-- not found looked for again. report(fmt, ...) says a texture not in memory.
function M.start(report)
	S.gamepad, S.report, S.unread = Device.gamepad_name(), report, false
	found.forget()
end

-- At each paint: setting, ButtonIcons in use.
function M.use(setting)
	S.brand = M.brand_of(setting, S.gamepad)
end

function M.brand() return S.brand end

-- The path of a button's icon for the icons in use, or nil when there is none: what tells two icons apart.
function M.path(name)
	return Names.icon(name, S.brand)
end

-- The button's name on the controller in use, in lang.
function M.label(name, lang)
	return Names.label(name, S.brand, lang)
end

-- The texture of a button's icon, looked for now, or nil: no icon for it, or not in memory.
function M.texture(name)
	local path = M.path(name)
	if path == nil then return nil end
	local t = found.find(path)
	if t ~= nil then return t end
	if not S.said[path] then
		S.said[path] = true
		if S.report then S.report("panel: icon not in memory, the button's name in its place: %s", path) end
	end
	return nil
end

-- The diamond read from Mod Panel's file (D184), or nil and why. One read failed is not tried again until the next
-- opening: each image of the list would try it.
local function read_file()
	if S.unread then return nil end
	local lib = Calls.ok(Calls.IMPORT_TEXTURE) and found.find(RENDERING) or nil
	local began, ok, t = os.clock(), false, nil
	if lib ~= nil then ok, t = pcall(import, lib, FAVORITE_FILE) end
	if ok and U.is_valid(t) then
		if not S.said.read then
			S.said.read = true
			local ms = (os.clock() - began) * 1000
			if S.report then S.report("panel: the favourites' icon read from its file in %.1f ms", ms) end
		end
		return t
	end
	S.unread = true
	if not S.said.unread then
		S.said.unread = true
		if S.report then S.report("panel: the favourites' icon not read from %s, the game's used", FAVORITE_FILE) end
	end
	return nil
end

-- The favourites' diamond (D178) for the frame whose memory of what shows is sh, or nil: read from Mod Panel's file
-- once per frame, else the game's texture when it is in memory (discovery 28). Without either, the list shows no
-- diamond, the favourites still first.
function M.favorite(sh)
	local t = made[sh] or read_file()
	if t ~= nil then return t end
	t = found.find(L.FAVORITE_ICON)
	if t == nil and not S.said[L.FAVORITE_ICON] then
		S.said[L.FAVORITE_ICON] = true
		if S.report then S.report("panel: the favourites' icon not in memory, the list shows none: %s", L.FAVORITE_ICON) end
	end
	return t
end

-- Texture t, which M.favorite(sh) gave, now set on an image of sh's frame: kept for that frame only, as that image
-- holds it from now on and lives as long as the frame. Never kept before an image holds it: only Lua would (D75).
function M.kept(sh, t)
	made[sh] = t
end

return M
