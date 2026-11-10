-- The mods read: the only keeper of their rows and values. Each descriptor is read once at start, so the largest of
-- ours (Movement Tuning's, 51 KiB) is not decoded in play; at each opening, every mod is read again, a few at a time
-- (refresh_step): its config, and its descriptor's text, decoded again only when it changed. A mod whose config
-- cannot serve is not shown, its reason said once in the log (D24); one without a config is not shown, as in Mods Menu.
-- The JavaScript mods (D173) come from the list their link writes, read again at each opening: their rows from it,
-- their values from their Key=Value file; one whose file is not there yet shows its defaults, as in Mods Menu.

local Files = require("mod_panel_files")
local Json = require("mod_panel_json")
local Descriptor = require("mod_panel_descriptor")
local Values = require("mod_panel_values")
local Slices = require("mod_panel_slices")
local JsMods = require("mod_panel_js_mods")

local M = {}

local MAX_FILE_BYTES = 256 * 1024
local MAX_SAID = 200

local function quiet() end

-- d: { mods_dir, names (the mods UE4SS runs), own (Mod Panel's folder name), note(text) for a line said once,
-- js_list (the JavaScript mods' list's path, nil for none) }.
function M.new(d)
	local C = { decodes = 0 }

	-- Mod Panel first, then by English title whatever the case of its letters, then by folder name (D25).
	local function before(a, b)
		if (a.name == d.own) ~= (b.name == d.own) then return a.name == d.own end
		local ta, tb = a.title.en:lower(), b.title.en:lower()
		if ta ~= tb then return ta < tb end
		return a.name < b.name
	end
	local described = {}          -- by name: { text, doc } of the descriptor last read
	local entries = {}            -- by name: the mod as last read, nil when not shown
	local sorted, counted = {}, false
	local next_name = nil         -- in a refresh, the place in d.names of the next mod to read
	local slices = {}
	local said, said_count = {}, 0  -- the lines said, MAX_SAID at most kept (audit of 0.4.3); the log bounds the rest
	local js = {}                 -- by name: a JavaScript mod of the list last read (mod_panel_js_mods.lua)
	local names = d.names         -- the UE4SS mods, then the JavaScript mods

	local function once(name, reason)
		local line = name .. ": " .. reason
		if said[line] then return end
		if said_count < MAX_SAID then said[line], said_count = true, said_count + 1 end
		d.note(line)
	end

	local function path(name, ending)
		return d.mods_dir .. "/" .. name .. "/" .. name .. ending
	end

	-- Reads the JavaScript mods' list again: the names grow or shrink with it.
	local function load_js()
		if d.js_list == nil then return end
		local list, why = JsMods.read(d.js_list, function(line) once("ModPanel-jsmods", line) end)
		if why then once("ModPanel-jsmods", why) end
		js, names = {}, {}
		for _, name in ipairs(d.names) do names[#names + 1] = name end
		for _, m in ipairs(list) do
			js[m.name] = m
			names[#names + 1] = m.name
		end
	end

	-- The descriptor's tree, or nil without a usable one: the config's keys then give the rows. A descriptor another
	-- program holds for a moment keeps the tree last read.
	local function descriptor(name)
		if js[name] then return js[name].doc end
		local text, why = Files.read(path(name, ".modsmenu.json"), MAX_FILE_BYTES)
		local known = described[name]
		if text == nil then
			if why == "busy" and known then return known.doc end
			if why == "big" then once(name, "the descriptor is larger than 256 KiB, rows from the settings file instead") end
			described[name] = nil
			return nil
		end
		if known and known.text == text then return known.doc end
		C.decodes = C.decodes + 1
		local doc, bad = Json.decode(text)
		if doc == nil then once(name, "the descriptor is not JSON (" .. bad .. "), rows from the settings file instead") end
		described[name] = { text = text, doc = doc }
		return doc
	end

	-- A JavaScript mod from its Key=Value file's text (nil: no file yet, its defaults, as in Mods Menu).
	local function from_txt(name, text)
		local mod, refused = JsMods.mod(name, js[name].doc, text, function(r) once(name, r .. ", left out") end)
		if mod == nil then once(name, refused .. ", not shown") end
		return mod
	end

	-- The mod from its settings file's text, or nil when it is not shown.
	local function from_text(name, text)
		if js[name] then return from_txt(name, text) end
		local config, bad = Json.decode(text)
		if config == nil then
			once(name, "the settings file is not JSON (" .. bad .. "), not shown")
			return nil
		end
		if not Json.is_object(config) then
			once(name, "the settings file is not one JSON object, not shown")
			return nil
		end
		local mod, refused = Descriptor.check(name, descriptor(name), config, function(r) once(name, r .. ", left out") end)
		if mod == nil then
			once(name, refused .. ", not shown")
			return nil
		end
		-- As in Mods Menu: a value absent or unusable in the file is the row's missing value.
		mod.values, mod.off = {}, false
		for _, row in ipairs(mod.rows) do
			if row.key ~= nil and row.type ~= "action" then
				local v = Values.from_raw(row, config[row.key], true)
				if v == nil then v = row.missing end
				mod.values[row.key] = v
				if row.key == "Enabled" and row.type == "toggle" then mod.off = v == false end
			end
		end
		return mod
	end

	local function read(name)
		if js[name] then
			local text, why = Files.read(js[name].path, MAX_FILE_BYTES)
			if why == "missing" then return from_txt(name, nil) end
			if why == "busy" then once(name, "the settings file cannot be read now (another program holds it), not shown") end
			if why == "big" then once(name, "the settings file is larger than 256 KiB, not shown") end
			return text and from_txt(name, text)
		end
		local text, why = Files.read(path(name, ".config.json"), MAX_FILE_BYTES)
		if why == "busy" then once(name, "the settings file cannot be read now (another program holds it), not shown") end
		if why == "big" then once(name, "the settings file is larger than 256 KiB, not shown") end
		if text == nil then return nil end
		return from_text(name, text)
	end

	local function sort()
		sorted = {}
		for _, name in ipairs(names) do
			if entries[name] then sorted[#sorted + 1] = entries[name] end
		end
		table.sort(sorted, before)
	end

	function C.start()
		load_js()
		for _, name in ipairs(names) do descriptor(name) end
	end

	-- The settings file of name: a UE4SS mod's config, or a JavaScript mod's Key=Value file.
	function C.file(name)
		if js[name] then return js[name].path end
		return path(name, ".config.json")
	end

	-- One mod read again now; returns it, or nil when it is not shown.
	function C.refresh_mod(name)
		entries[name] = read(name)
		sort()
		return entries[name]
	end

	-- The text Mod Panel just wrote to name's settings file (mod_panel_edits.lua): taken as read, without reading the
	-- file back.
	function C.written(name, text)
		entries[name] = from_text(name, text)
		sort()
		return entries[name]
	end

	local function read_next()
		local name = names[next_name]
		if name ~= nil then
			entries[name] = read(name)
			next_name = next_name + 1
		end
		return names[next_name] == nil
	end

	-- Reads mods again in a slice of budget seconds (mod_panel_slices.lua). True once every mod is read again; the
	-- call after starts a new reading.
	function C.refresh_step(budget)
		if next_name == nil then
			load_js()
			-- A JavaScript mod gone from the list is not shown any more.
			for name in pairs(entries) do
				if JsMods.is_js(name) and not js[name] then entries[name] = nil end
			end
		end
		next_name = next_name or 1
		if not Slices.run(read_next, budget, slices) then return false end
		next_name, counted = nil, true
		sort()
		return true
	end

	function C.list()
		return sorted
	end

	function C.get(name)
		return entries[name]
	end

	function C.value(entry, row)
		return entry.values[row.key]
	end

	function C.off(entry)
		return entry.off
	end

	-- The mods shown and those left out, once every mod has been read; nil before.
	function C.counts()
		if not counted then return nil end
		return #sorted, #names - #sorted
	end

	-- A mod's rows from its descriptor alone, with their defaults; nil when its descriptor gives none.
	function C.rows(name)
		local mod = Descriptor.check(name, (described[name] or {}).doc, {}, quiet)
		return mod and mod.rows or nil
	end

	return C
end

return M
