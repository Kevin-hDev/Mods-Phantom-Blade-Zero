-- When a row is greyed (D147): greyedUnless on a row, or on the mod, is
-- { "<key>": value } or { "<key>": [values] }; the row is greyed while one of the keys named has none of its values.
-- The mod's condition greys every row but its headings, its read-only rows, the rows it names and those marked
-- neverGreyed. Checked when the mod is read: a key no toggle, choice or number of the mod has (a key row is none,
-- D155), or a value that row cannot take, drops that key's condition, said once. A greyed row is still chosen,
-- nothing changes it (D148). A condition names MAX_KEYS keys and MAX_VALUES values at most, as many as a mod has
-- rows and a list options: past them it is a fault, and each row checks its conditions at each frame (audit of
-- 0.7.0: 20 000 values made a frame last 266 ms).

local Json = require("mod_panel_json")
local Values = require("mod_panel_values")
local Text = require("mod_panel_text")

local M = {}

local VALUED = { toggle = true, number = true, choice = true }
local MAX_KEYS, MAX_VALUES = 100, 64

-- The value raw for row, or nil where row cannot take it: a toggle's true or false, one of a choice's values, a
-- number within the row's ends.
local function possible(row, raw)
	if row.type == "toggle" then
		if type(raw) == "boolean" then return raw end
		return nil
	end
	if row.type == "number" then
		if type(raw) ~= "number" or raw ~= raw or raw == math.huge or raw == -math.huge then return nil end
		if (row.min ~= nil and raw < row.min) or (row.max ~= nil and raw > row.max) then return nil end
		return raw
	end
	if type(raw) ~= "string" and type(raw) ~= "number" and type(raw) ~= "boolean" then return nil end
	local i = Values.option_index(row.options, raw)
	if i == nil then return nil end
	return row.options[i].value
end

-- The checked conditions of raw, a list of { row, values }, or nil for none; why(reason) is told each one dropped,
-- where naming the row or the mod. A row's condition on itself is dropped: once changed, nothing could make it
-- changeable again.
local function conditions(raw, by_key, why, own, where)
	if raw == nil then return nil end
	if not Json.is_object(raw) then
		why(where .. ": greyedUnless is not an object")
		return nil
	end
	local list, keys = {}, Json.keys(raw)
	if #keys > MAX_KEYS then
		why(where .. ": greyedUnless names more than " .. MAX_KEYS .. " settings")
		return nil
	end
	for _, key in ipairs(keys) do
		local row, wanted = by_key[key], raw[key]
		local values, named = {}, Text.cited(key)
		if row == nil then
			why(where .. ": greyedUnless " .. named .. ", no such setting")
		elseif row == own then
			why(where .. ": greyedUnless on itself")
		else
			local raws = Json.is_array(wanted) and wanted or { wanted }
			if #raws == 0 then
				why(where .. ": greyedUnless " .. named .. ", no value")
				values = nil
			elseif #raws > MAX_VALUES then
				why(where .. ": greyedUnless " .. named .. ", more than " .. MAX_VALUES .. " values")
				values, raws = nil, {}
			end
			for i, v in ipairs(raws) do
				values[i] = possible(row, v)
				if values[i] == nil then
					why(where .. ": greyedUnless " .. named .. ", a value it cannot take")
					values = nil
					break
				end
			end
			if values ~= nil then list[#list + 1] = { row = row, values = values } end
		end
	end
	return #list > 0 and list or nil
end

-- Reads the conditions of mod (its rows checked, each with its raw greyedUnless as row.greyed_raw) and of doc, its
-- decoded descriptor: mod.greyed and each row's greyed, the conditions kept. note(reason) is told each one dropped.
function M.read(mod, doc, note)
	local by_key = {}
	for _, row in ipairs(mod.rows) do
		if row.key ~= nil and VALUED[row.type] and not row.key_row and by_key[row.key] == nil then by_key[row.key] = row end
	end
	local function why(reason) note("setting " .. reason) end
	mod.greyed = conditions(Json.is_object(doc) and doc.greyedUnless or nil, by_key, why, nil, "the mod")
	local named = {}
	for _, c in ipairs(mod.greyed or {}) do named[c.row.key] = true end
	for _, row in ipairs(mod.rows) do
		row.greyed = row.type ~= "heading" and conditions(row.greyed_raw, by_key, why, row, Text.cited(row.key or "?"))
			or nil
		row.greyed_raw = nil
		row.by_mod = mod.greyed ~= nil and row.type ~= "heading" and row.type ~= "readonly" and not row.never_greyed
			and not named[row.key]
	end
end

-- Whether the value v of row is one of values.
local function one_of(row, v, values)
	for _, w in ipairs(values) do
		if row.type == "choice" then
			if Values.option_index(row.options, v) == Values.option_index(row.options, w) and v ~= nil then return true end
		elseif v == w then
			return true
		end
	end
	return false
end

-- No table made for a row without a condition: it is asked at each frame for each row shown (audit of 0.7.0).
local function first_missing(list, entry, value)
	if list == nil then return nil end
	for _, c in ipairs(list) do
		if not one_of(c.row, value(entry, c.row), c.values) then return c.row, c.values[1] end
	end
	return nil
end

-- What row of entry waits for: the row whose value is missing and the first value it asks, the mod's condition
-- first, then the row's; nil when row is not greyed. value(entry, row) gives a row's value now, changes waiting
-- included.
function M.missing(entry, row, value)
	if row == nil then return nil end
	if row.by_mod then
		local r, v = first_missing(entry.greyed, entry, value)
		if r ~= nil then return r, v end
	end
	return first_missing(row.greyed, entry, value)
end

return M
