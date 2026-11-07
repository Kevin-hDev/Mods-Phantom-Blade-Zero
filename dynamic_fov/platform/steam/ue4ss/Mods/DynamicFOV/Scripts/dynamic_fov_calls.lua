-- Checks an engine function's parameters before the mod first calls it. UE4SS converts each Lua value to the kind the
-- function wants; a value of another kind, or a missing one, can crash it past any pcall (crash audit of Dodge Jump,
-- 4 November 2026). The kinds the camera's callers expect were read in the game by CameraProbe (pass 4, 4 November
-- 2026), the panel's are in dynamic_fov_panel_calls.lua: a game update that changes them turns the feature off
-- instead of crashing.

local U = require("dynamic_fov_unreal")

local M = {}

-- Kinds the engine may describe two ways: a float or a double; an enum as an enum or as a byte (PanelProbe pass 7: the
-- overlay's alignments are bytes, a widget's visibility an enum).
local ALIAS = {
	number = { FloatProperty = true, DoubleProperty = true },
	enum = { EnumProperty = true, ByteProperty = true },
}

local function kind(prop)
	local ok, t = pcall(function() return prop:GetClass():GetFName():ToString() end)
	if not ok or type(t) ~= "string" then return "?" end
	if t == "StructProperty" then
		local oks, s = pcall(function() return prop:GetStruct():GetFName():ToString() end)
		t = t .. "<" .. (oks and type(s) == "string" and s or "?") .. ">"
	end
	return t
end

-- The kinds of the function's parameters, its return value left out, or nil when the function is not found.
function M.params(class_path, fn)
	local f = nil
	pcall(function() f = StaticFindObject(class_path .. ":" .. fn) end)
	if not U.is_valid(f) then return nil end
	local list = {}
	local ok = pcall(function()
		f:ForEachProperty(function(prop)
			local okn, name = pcall(function() return prop:GetFName():ToString() end)
			if not (okn and name == "ReturnValue") then list[#list + 1] = kind(prop) end
		end)
	end)
	return ok and list or nil
end

-- Whether the function takes exactly these kinds, in this order; "number" and "enum" stand for the two ways above.
-- Also returns the kinds found, for the log.
function M.takes(class_path, fn, kinds)
	local list = M.params(class_path, fn)
	if list == nil or #list ~= #kinds then return false, list end
	for i, k in ipairs(kinds) do
		if not (list[i] == k or (ALIAS[k] and ALIAS[k][list[i]])) then return false, list end
	end
	return true, list
end

return M
