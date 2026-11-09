-- ModPanel.state.json, what the panel keeps by itself (D26): the list's filter, whether the descriptions show, the
-- last mod chosen, the mods All mods turned off (D163, mod_panel_all_mods.lua). Read leniently at start: a value
-- that cannot serve gives its default, and a file that cannot be read gives them all. Written at a closing, and at
-- once when All mods turns mods off, only when a value changed since the last writing (D96), to a temporary file
-- first (mod_panel_files.lua). The only module that writes it; its version is written from the first file on.

local Files = require("mod_panel_files")
local Json = require("mod_panel_json")
local JsonEdit = require("mod_panel_json_edit")
local Folders = require("mod_panel_folders")

local M = {}

M.VERSION = 1
-- Room for MAX_TURNED_OFF names of MAX_MOD characters, each with its quotes and comma.
local MAX_FILE_BYTES = 32 * 1024
local MAX_MOD = 64                -- a mod's name as long as a key may be
local MAX_TURNED_OFF = Folders.MAX_MODS   -- as many as Mod Panel lists: All mods may turn them all off
local FLAGS = { enabled = true, disabled = false, descriptions = true }   -- the switches and their defaults
local ORDER = { "enabled", "disabled", "descriptions" }
local WHY = { busy = "it cannot be read now", big = "it is larger than 32 KiB" }

local function name_ok(s)
	return type(s) == "string" and s ~= "" and #s <= MAX_MOD
end

local function same_list(a, b)
	if a == nil or b == nil or #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local function same(a, b)
	for _, name in ipairs(ORDER) do
		if a[name] ~= b[name] then return false end
	end
	return a.mod == b.mod and same_list(a.turned_off, b.turned_off)
end

local function copy(t)
	local list = {}
	for i, name in ipairs(t.turned_off or {}) do list[i] = name end
	return { enabled = t.enabled, disabled = t.disabled, descriptions = t.descriptions, mod = t.mod, turned_off = list }
end

-- The names of a JSON list that can serve, each once, MAX_TURNED_OFF at most; the rest left out.
local function names_of(list)
	local names, seen = {}, {}
	if not Json.is_array(list) then return names end
	for _, s in ipairs(list) do
		if #names >= MAX_TURNED_OFF then break end
		if name_ok(s) and not seen[s] then names[#names + 1], seen[s] = s, true end
	end
	return names
end

-- The values of the file's text, or nil and why it cannot serve.
local function decoded(text)
	local doc = Json.decode(text)
	if not Json.is_object(doc) then return nil, "it is not one JSON object" end
	local v = {}
	for _, name in ipairs(ORDER) do
		v[name] = doc[name]
		if type(v[name]) ~= "boolean" then v[name] = FLAGS[name] end
	end
	if name_ok(doc.mod) then v.mod = doc.mod end
	v.turned_off = names_of(doc.turned_off)
	return v
end

-- path: the state file. note(text): a line for the log.
function M.new(path, note)
	-- values: in use; written: as the file holds them, the defaults when it is missing (nothing to write until one
	-- changes), nil fields when it cannot serve (written again at the first closing); told: the last failure said.
	local S = { values = copy(FLAGS), written = copy(FLAGS), told = nil }

	local text, why = Files.read(path, MAX_FILE_BYTES)
	if text ~= nil then
		local v, bad = decoded(text)
		if v ~= nil then
			S.values, S.written = v, copy(v)
		else
			S.written = {}
			note(string.format("ModPanel.state.json: %s, the panel starts from its defaults", bad))
		end
	elseif why ~= "missing" then
		S.written = {}
		note(string.format("ModPanel.state.json: %s, the panel starts from its defaults", WHY[why]))
	end

	-- name: "enabled", "disabled", "descriptions" (booleans), "mod" (a mod's name, or nil) or "turned_off" (a list of
	-- mods' names, set as a whole).
	function S.get(name) return S.values[name] end
	function S.set(name, v) S.values[name] = v end

	-- At a closing: the file written when a value changed. A failure is said once until it changes, and the next
	-- closing tries again.
	function S.save()
		if same(S.values, S.written) then return true end
		local entries = { { "version", M.VERSION } }
		for _, name in ipairs(ORDER) do entries[#entries + 1] = { name, S.values[name] } end
		if S.values.mod ~= nil then entries[#entries + 1] = { "mod", S.values.mod } end
		local off = S.values.turned_off
		if #off > 0 then entries[#entries + 1] = { "turned_off", off } end
		local ok, put_why = Files.put(path, JsonEdit.flat_object(entries))
		if ok then
			S.written, S.told = copy(S.values), nil
			local v = S.values
			note(string.format("ModPanel.state.json written (enabled %s, disabled %s, descriptions %s, mod %s%s)",
				tostring(v.enabled), tostring(v.disabled), tostring(v.descriptions), tostring(v.mod),
				#off > 0 and ", turned off " .. table.concat(off, " ") or ""))
			return true
		end
		if put_why ~= S.told then
			S.told = put_why
			note(string.format("ModPanel.state.json could not be written (%s): tried again at the next closing", put_why))
		end
		return false
	end

	return S
end

return M
