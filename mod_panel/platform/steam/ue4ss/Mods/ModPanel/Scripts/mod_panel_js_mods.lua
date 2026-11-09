-- The JavaScript mods Mods Menu runs (D173): their settings are only in the game's script memory, so Mod Panel's own
-- script mod, AAModPanelLink (ProjectPBZ/Content/JavaScript/PBZModsMenu/Mods), copies what each mod registers with
-- Mods Menu into <Mod Panel's folder>/ModPanel-jsmods.json. Read here, checked at this border once: the rows then go
-- through the same checks as a UE4SS mod's descriptor. A mod's name in Mod Panel is "js:" and its id, which no UE4SS
-- folder name can be. Its settings file is a Key=Value text (mod_panel_txt.lua) at the path Mods Menu gave.

local Files = require("mod_panel_files")
local Json = require("mod_panel_json")
local Descriptor = require("mod_panel_descriptor")
local Values = require("mod_panel_values")
local Txt = require("mod_panel_txt")

local M = {}

M.FILE = "ModPanel-jsmods.json"
M.PREFIX = "js:"
local MAX_BYTES = 1024 * 1024     -- the link writes at most 64 mods within this
local MAX_MODS = 64
local MAX_PATH = 520
-- A settings file as Mods Menu takes it (one dot, .txt or .ini), in one of its two places: <game>\ProjectPBZ\
-- Content\Paks\~mods, or the Saved folder's PBZModsMenu\Settings (store: "saved").
local FILE_NAME = "^[A-Za-z0-9_][A-Za-z0-9_ %-]*%.[tTiI][xXnN][tTiI]$"
local PLACES = { "[\\/]Paks[\\/]~mods[\\/][^\\/]+$", "[\\/]Saved[\\/]PBZModsMenu[\\/]Settings[\\/][^\\/]+$" }

function M.is_js(name)
	return name:sub(1, #M.PREFIX) == M.PREFIX
end

local function valid_path(path)
	if type(path) ~= "string" or #path > MAX_PATH or path:find("%.%.") or path:find("[%c\"*?<>|]") then return false end
	local file = path:match("([^\\/]+)$")
	if file == nil or #file > 84 or not file:match(FILE_NAME) then return false end
	for _, place in ipairs(PLACES) do
		if path:find(place) then return true end
	end
	return false
end

-- A JavaScript mod's rows as Mod Panel can serve them: an action runs a function in the game's scripts, out of Mod
-- Panel's reach, so it is left out rather than shown and broken; so is an option holding ; or #, which a text file
-- would read as a comment, as Mods Menu leaves it out.
local function commented(r)
	if not Json.is_array(r.options) then return false end
	for _, o in ipairs(r.options) do
		local v = Json.is_object(o) and o.value or o
		if type(v) == "string" and v:find("[;#]") then return true end
	end
	return false
end

-- Taken out of the decoded array itself, which stays an array for the descriptor's checks.
local function serveable(settings, note)
	for i = #settings, 1, -1 do
		local r = settings[i]
		if Json.is_object(r) and r.type == "action" then
			note("setting " .. tostring(r.key) .. ": an action of a JavaScript mod, left out")
			table.remove(settings, i)
		elseif Json.is_object(r) and commented(r) then
			note("setting " .. tostring(r.key) .. ": a value with ; or #, left out")
			table.remove(settings, i)
		end
	end
	return settings
end

-- A JavaScript mod as the catalog keeps it, from its descriptor and its Key=Value file's text (nil: no file yet), or
-- nil and why it is not shown. As in Mods Menu: a key absent from the file is the row's missing value, every
-- row its default while the file is not there.
function M.mod(name, doc, text, note)
	local mod, refused = Descriptor.check(name, doc, {}, note)
	if mod == nil then return nil, refused end
	mod.values, mod.off, mod.js = {}, false, true
	for _, row in ipairs(mod.rows) do
		if row.key ~= nil and row.type ~= "action" then
			local v = nil
			if text ~= nil then v = Values.from_raw(row, Txt.read_key(text, row.key), false) end
			-- Spelled out: "text and row.missing or row.default" would take a missing value of false for none.
			if v == nil then
				if text ~= nil then v = row.missing else v = row.default end
			end
			mod.values[row.key] = v
			if row.key == "Enabled" and row.type == "toggle" then mod.off = v == false end
		end
	end
	return mod
end

-- The mods of the file at path: a list of { name, id, doc (a descriptor, as a .modsmenu.json holds it), path }, in the
-- file's order, and a reason when the file cannot serve (nil for a missing file: Mods Menu or the link is not there).
function M.read(path, note)
	local text, why = Files.read(path, MAX_BYTES)
	if why == "missing" then return {} end
	if text == nil then return {}, "the JavaScript mods' list cannot be read (" .. why .. ")" end
	local doc, bad = Json.decode(text)
	if not Json.is_object(doc) or doc.version ~= 1 or not Json.is_array(doc.mods) then
		return {}, "the JavaScript mods' list is not one it knows (" .. (bad or "version or mods") .. ")"
	end
	local list, seen = {}, {}
	for i = 1, math.min(#doc.mods, MAX_MODS) do
		local m = doc.mods[i]
		local id = Json.is_object(m) and m.id
		if type(id) ~= "string" or not id:match("^[A-Za-z0-9_]+$") or #id > 64 or seen[id] then
			note("the JavaScript mods' list: an entry without a valid id, left out")
		elseif not valid_path(m.path) then
			note(M.PREFIX .. id .. ": its settings file is not where Mods Menu keeps them, not shown")
		elseif not Json.is_array(m.settings) then
			note(M.PREFIX .. id .. ": no settings, not shown")
		else
			seen[id] = true
			local name = M.PREFIX .. id
			local described = { title = m.title, description = m.description, version = m.version,
				greyedUnless = m.greyedUnless,
				settings = serveable(m.settings, function(line) note(name .. ": " .. line) end) }
			list[#list + 1] = { name = name, id = id, doc = described, path = m.path }
		end
	end
	return list
end

return M
