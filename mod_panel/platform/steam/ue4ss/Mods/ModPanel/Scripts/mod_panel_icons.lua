-- The controller's icons: whose (ButtonIcons: Auto, PlayStation, Xbox), a button's name, and its texture when the game
-- has it in memory. In Auto, the controller's name the game gives is read at each opening, the panel hidden (D73). A
-- texture is only looked for, never loaded (D74), in the very frame it is set, and never kept from one frame to another
-- (D75): passes 4 and 5 of PanelProbe crashed on a texture only Lua held. One not in memory is not looked for again
-- until the next opening, and said once in the game: the button's name shows in its place. Mod Panel's own drawings,
-- the favourites' diamond (D184) and the search's magnifier and cross (D186), are read from its files instead, and
-- each kept for its frame once an image of it holds it.

local U = require("mod_panel_unreal")
local L = require("mod_panel_layout")
local Names = require("mod_panel_pad_names")
local Device = require("mod_panel_device")
local Calls = require("mod_panel_calls")
local Folders = require("mod_panel_folders")

local M = {}

-- gamepad: the controller's name read at the last opening, nil when not read. brand: whose icons now. said: the paths
-- not in memory already said in the game, at most one per path of mod_panel_pad_names.lua and the favourites' one, and
-- each drawing's reading said. unread[key]: that drawing's file is not read again at this opening; reads[key]: the
-- times it was read at this opening.
local S = { gamepad = nil, brand = Names.XBOX, said = {}, report = nil, unread = {}, reads = {} }
-- Reads of one drawing at most per opening: one is enough while an image takes it, and an image the game refuses it
-- would have the file read and a new texture made at each frame (audit of 1.0.4).
local MAX_READS = 3
local found = U.finder()
local RENDERING = "/Script/Engine.Default__KismetRenderingLibrary"
-- Mod Panel's drawings, by key: their file, what they are in the log, and what shows when the file cannot be read.
local FILES = {
	favorite = { file = L.FAVORITE_FILE, what = "the favourites' icon", instead = "the game's used" },
	search = { file = L.SEARCH_FILE, what = "the search's magnifier", instead = "none shown" },
	clear = { file = L.CLEAR_FILE, what = "the search's cross", instead = "none shown" },
}
local HERE = Folders.paths(debug.getinfo(1, "S").source) or "."
for _, f in pairs(FILES) do f.path = HERE .. "/" .. f.file end
-- The drawings each frame shows, by the frame's memory of what shows, then by key: gone with the frame (weak keys).
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
	S.gamepad, S.report = Device.gamepad_name(), report
	if next(S.unread) ~= nil then S.unread = {} end
	if next(S.reads) ~= nil then S.reads = {} end
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

-- Once in the game: the line said under name, made by fmt and its values.
local function say_once(name, fmt, ...)
	if S.said[name] then return end
	S.said[name] = true
	if S.report then S.report(fmt, ...) end
end

-- Mod Panel's drawing key read from its file, or nil. One read failed is not tried again until the next opening: each
-- image would try it.
local function read_file(key)
	local f = FILES[key]
	if S.unread[key] then return nil end
	S.reads[key] = (S.reads[key] or 0) + 1
	if S.reads[key] > MAX_READS then
		S.unread[key] = true
		say_once("refused " .. key, "panel: %s read %d times, its image never took it; not read again until the "
			.. "next opening", f.what, MAX_READS)
		return nil
	end
	local lib = Calls.ok(Calls.IMPORT_TEXTURE) and found.find(RENDERING) or nil
	local began, ok, t = os.clock(), false, nil
	if lib ~= nil then ok, t = pcall(import, lib, f.path) end
	if ok and U.is_valid(t) then
		say_once("read " .. key, "panel: %s read from its file in %.1f ms", f.what, (os.clock() - began) * 1000)
		return t
	end
	S.unread[key] = true
	say_once("unread " .. key, "panel: %s not read from %s, %s", f.what, f.path, f.instead)
	return nil
end

-- Mod Panel's drawing key ("favorite", "search", "clear") for the frame whose memory of what shows is sh, or nil: read
-- from its file once per frame.
function M.from_file(sh, key)
	local m = made[sh]
	return m and m[key] or read_file(key)
end

-- The favourites' diamond (D178) for the frame whose memory of what shows is sh, or nil: Mod Panel's drawing, else the
-- game's texture when it is in memory (discovery 28). Without either, the list shows no diamond, the favourites still
-- first.
function M.favorite(sh)
	local t = M.from_file(sh, "favorite")
	if t ~= nil then return t end
	t = found.find(L.FAVORITE_ICON)
	if t == nil then
		say_once(L.FAVORITE_ICON, "panel: the favourites' icon not in memory, the list shows none: %s", L.FAVORITE_ICON)
	end
	return t
end

-- Texture t of drawing key, which M.from_file or M.favorite gave, now set on an image of sh's frame: kept for that
-- frame only, as that image holds it from now on and lives as long as the frame. Never kept before an image holds it:
-- only Lua would (D75).
function M.keep(sh, key, t)
	local m = made[sh]
	if m == nil then
		m = {}
		made[sh] = m
	end
	m[key] = t
end

return M
