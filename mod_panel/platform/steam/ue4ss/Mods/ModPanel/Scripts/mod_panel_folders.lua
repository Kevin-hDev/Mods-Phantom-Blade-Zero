-- Where the mods are, and which ones UE4SS runs. Read at start only: UE4SS starts mods only when the game starts.
-- UE4SS 1ceefac (start_mods in UE4SSProgram.cpp) starts a mod named "Name : 1" in Mods/mods.txt, and any mod whose
-- folder holds an enabled.txt, even one set to 0 in mods.txt. Lua cannot list a folder: IterateGameDirectories does
-- (LuaMod.cpp), from the game's root, which holds 167 folders in this game (6 November 2026); a folder's table has
-- its subfolders under their names, and __name and __absolute_path.

local Files = require("mod_panel_files")

local M = {}

M.MAX_MODS = 256
local MAX_MODS = M.MAX_MODS
local MAX_FOLDERS = 2000          -- tables looked at on the way down to the Mods folder
local MAX_LIST_BYTES = 65536
M.BRIDGE = "PBZModsMenuBridge"
local BRIDGE = M.BRIDGE

-- The mod's folder and the Mods folder above it, from the script's path as UE4SS gives it
-- ("@W:\...\Mods\ModPanel\Scripts\main.lua"); nil when it is not of that form.
function M.paths(source)
	if type(source) ~= "string" then return nil end
	local mod_dir = source:gsub("^@", ""):match("^(.*)[/\\]Scripts[/\\][^/\\]+$")
	if mod_dir == nil then return nil end
	return mod_dir, mod_dir:match("^(.*)[/\\][^/\\]+$")
end

-- A folder name Mod Panel uses in a path: the rule Mods Menu keeps for UE4SS folders (letters, digits, _ - . space and
-- parentheses, 64 at most, not only dots).
function M.valid_name(name)
	return type(name) == "string" and #name <= 64 and name:match("^[A-Za-z0-9_%-%. %(%)]+$") ~= nil
		and name:match("^%.+$") == nil
end

-- mods.txt as UE4SS reads it: a line with ";" or of 4 characters at most is skipped, spaces are taken out, the name
-- is what comes before the first ":", and the mod starts when what follows the last ":" begins with 1. A name given
-- on several lines starts when one of them says so.
local function read_mods_txt(mods_dir)
	local text = Files.read(mods_dir .. "/mods.txt", MAX_LIST_BYTES)
	local on = {}
	for line in (text or ""):gsub("^\239\187\191", ""):gmatch("[^\n]+") do
		line = line:gsub("\r$", "")
		if not line:find(";", 1, true) and (utf8.len(line) or #line) > 4 then
			line = line:gsub(" ", "")
			local name, value = line:match("^([^:]*):"), line:match(":([^:]*)$")
			if name and name ~= "" then on[name] = on[name] or value:sub(1, 1) == "1" end
		end
	end
	return on, text ~= nil
end

local function norm(path)
	return (path:gsub("\\", "/"):gsub("/+", "/"):gsub("/$", ""):lower())
end

local function path_of(t)
	local ok, p = pcall(function() return t.__absolute_path end)
	return ok and type(p) == "string" and norm(p) or nil
end

-- The names of the folders in the Mods folder, found in IterateGameDirectories by its path; or nil and why.
local function folders_in(mods_dir)
	if type(IterateGameDirectories) ~= "function" then return nil, "this UE4SS cannot list folders" end
	local ok, here = pcall(IterateGameDirectories)
	if not ok or type(here) ~= "table" then
		return nil, "the game's folders cannot be listed (" .. tostring(here) .. ")"
	end
	local target, looked = norm(mods_dir), 0
	while path_of(here) ~= target do
		local below = nil
		for _, child in pairs(here) do
			looked = looked + 1
			if looked > MAX_FOLDERS then return nil, "the Mods folder is too deep among the game's folders" end
			local p = type(child) == "table" and path_of(child)
			if p and (p == target or target:sub(1, #p + 1) == p .. "/") then
				below = child
				break
			end
		end
		if below == nil then return nil, "the Mods folder is not among the game's folders" end
		here = below
	end
	local names = {}
	for _, child in pairs(here) do
		local okn, n = pcall(function() return type(child) == "table" and child.__name end)
		if okn and type(n) == "string" then names[#names + 1] = n end
	end
	return names
end

-- The names of the mods UE4SS runs, by name, 256 at most; note(text) is told what could not be done.
function M.started(mods_dir, note)
	local on, has_list = read_mods_txt(mods_dir)
	local folders, why = folders_in(mods_dir)
	if folders == nil then
		note(string.format("%s: only the mods %s are listed", why,
			has_list and "in mods.txt" or "in mods.txt, and there is no mods.txt"))
		folders = {}
		for name in pairs(on) do folders[#folders + 1] = name end
	end
	local names = {}
	for _, name in ipairs(folders) do
		-- Mods Menu's bridge has no settings of its own; UE4SS never starts a folder named shared.
		if name ~= BRIDGE and name:lower() ~= "shared" then
			local runs = on[name] or Files.exists(mods_dir .. "/" .. name .. "/enabled.txt")
			if runs and M.valid_name(name) then
				names[#names + 1] = name
			elseif runs then
				note(string.format("the folder name %q cannot be used in a path: that mod is not listed", name))
			end
		end
	end
	table.sort(names)
	if #names > MAX_MODS then
		note(string.format("%d mods run, only the first %d by name are listed", #names, MAX_MODS))
		for i = #names, MAX_MODS + 1, -1 do names[i] = nil end
	end
	return names
end

return M
