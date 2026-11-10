-- ModPanel.state.json, what the panel keeps by itself (D26): the list's filter, whether the descriptions show, the
-- last mod chosen, the mods All mods turned off (D163, mod_panel_all_mods.lua), the sections the player folded or
-- opened otherwise than their author (D175, mod_panel_folds.lua). Read leniently at start: a value that cannot serve
-- gives its default, and a file that cannot be read gives them all. Written at a closing, and at once when All mods
-- turns mods off, only when a value changed since the last writing (D96), to a temporary file first
-- (mod_panel_files.lua). The only module that writes it; its version is written from the first file on.

local Files = require("mod_panel_files")
local Json = require("mod_panel_json")
local JsonEdit = require("mod_panel_json_edit")
local Folders = require("mod_panel_folders")
local Folds = require("mod_panel_folds")

local M = {}

M.VERSION = 1
-- Past this, a file is not read: the mods' names turned off take 17 KiB at most (256 names of 64 ASCII signs), the
-- sections the rest; a file that would be larger is written without its sections kept the longest.
local MAX_FILE_BYTES = 128 * 1024
local MAX_MOD = 64                -- a mod's name as long as a key may be
local MAX_TURNED_OFF = Folders.MAX_MODS   -- as many as Mod Panel lists: All mods may turn them all off
local MAX_SECTIONS = Folds.MAX_KEPT
local FLAGS = { enabled = true, disabled = false, descriptions = true }   -- the switches and their defaults
local ORDER = { "enabled", "disabled", "descriptions" }
local WHY = { busy = "it cannot be read now", big = string.format("it is larger than %d KiB", MAX_FILE_BYTES // 1024) }

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

local function same_sections(a, b)
	if a == nil or b == nil or #a ~= #b then return false end
	for i = 1, #a do
		if not same_list(a[i], b[i]) then return false end
	end
	return true
end

local function same(a, b)
	for _, name in ipairs(ORDER) do
		if a[name] ~= b[name] then return false end
	end
	return a.mod == b.mod and same_list(a.turned_off, b.turned_off) and same_sections(a.sections, b.sections)
end

local function copy(t)
	local list, sections = {}, {}
	for i, name in ipairs(t.turned_off or {}) do list[i] = name end
	for i, s in ipairs(t.sections or {}) do sections[i] = { s[1], s[2], s[3] } end
	return { enabled = t.enabled, disabled = t.disabled, descriptions = t.descriptions, mod = t.mod, turned_off = list,
		sections = sections }
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

-- The sections of a JSON list that can serve, each a list of a mod's name, a heading's name and whether it is folded,
-- each section once, MAX_SECTIONS at most; the rest left out.
local function sections_of(list)
	local found, seen = {}, {}
	if not Json.is_array(list) then return found end
	for _, s in ipairs(list) do
		if #found >= MAX_SECTIONS then break end
		if Json.is_array(s) and #s == 3 and name_ok(s[1]) and type(s[2]) == "string" and s[2] ~= ""
			and type(s[3]) == "boolean" then
			seen[s[1]] = seen[s[1]] or {}
			if not seen[s[1]][s[2]] then
				found[#found + 1], seen[s[1]][s[2]] = { s[1], s[2], s[3] }, true
			end
		end
	end
	return found
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
	v.sections = sections_of(doc.sections)
	return v
end

-- The file's text for values v, with only its first n sections.
local function text_of(v, n)
	local entries = { { "version", M.VERSION } }
	for _, name in ipairs(ORDER) do entries[#entries + 1] = { name, v[name] } end
	if v.mod ~= nil then entries[#entries + 1] = { "mod", v.mod } end
	if #v.turned_off > 0 then entries[#entries + 1] = { "turned_off", v.turned_off } end
	if n > 0 then entries[#entries + 1] = { "sections", table.move(v.sections, 1, n, 1, {}) } end
	return JsonEdit.flat_object(entries)
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

	-- name: "enabled", "disabled", "descriptions" (booleans), "mod" (a mod's name, or nil), "turned_off" (a list of
	-- mods' names, set as a whole) or "sections" (a list of { mod's name, heading's name, folded }, set as a whole).
	function S.get(name) return S.values[name] end
	function S.set(name, v) S.values[name] = v end

	-- At a closing: the file written when a value changed. A failure is said once until it changes, and the next
	-- closing tries again.
	function S.save()
		if same(S.values, S.written) then return true end
		local v = S.values
		local n = #v.sections
		local body = text_of(v, n)
		while #body > MAX_FILE_BYTES and n > 0 do
			n = n - 1
			body = text_of(v, n)
		end
		if n < #v.sections then
			note(string.format("ModPanel.state.json: %d sections kept the longest left out, to stay under %d KiB",
				#v.sections - n, MAX_FILE_BYTES // 1024))
			v.sections = table.move(v.sections, 1, n, 1, {})
		end
		local ok, put_why = Files.put(path, body)
		if ok then
			S.written, S.told = copy(v), nil
			local off = v.turned_off
			note(string.format("ModPanel.state.json written (enabled %s, disabled %s, descriptions %s, mod %s%s%s)",
				tostring(v.enabled), tostring(v.disabled), tostring(v.descriptions), tostring(v.mod),
				#off > 0 and ", turned off " .. table.concat(off, " ") or "",
				n > 0 and string.format(", %d sections folded or opened by the player", n) or ""))
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
