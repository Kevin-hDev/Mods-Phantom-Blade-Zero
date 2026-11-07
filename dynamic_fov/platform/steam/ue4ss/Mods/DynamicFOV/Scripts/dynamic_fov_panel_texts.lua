-- The panel's texts in the game's language (1.0.2). The title, the labels, the explanations, the headings and the
-- presets' names come from DynamicFOV.modsmenu.json, where Mods Menu reads them too: every text about a setting has one
-- place. The panel's own few words are below. The language is chosen as Mods Menu chooses it (its main.js, 0.5.3: lang()
-- and inLang()), so the panel and the menu speak the same, but for Traditional Chinese: Mods Menu has its own words
-- for On, Off and Restore defaults there, and the panel, like our texts, has none yet (English).

local Tree = require("dynamic_fov_json_tree")

local M = {}

local MAX_FILE_BYTES = 65536
local TRADITIONAL = { "zh-hant", "zh-tw", "zh-hk", "zh-mo" }
-- On and Off are Mods Menu's own words for a switch, Restore defaults its row's (PBZ_MM_ZH in its main.js).
local OWN = {
	on = { en = "On", ["zh-Hans"] = "开启" },
	off = { en = "Off", ["zh-Hans"] = "关闭" },
	restore = { en = "Restore defaults", ["zh-Hans"] = "恢复默认设置" },
	-- Restore defaults' button just after its click, until another change: it gives the settings before back.
	undo = { en = "Undo", ["zh-Hans"] = "撤销" },
	-- Not 关闭, which is the switch's Off: the two would read the same.
	close = { en = "Close", ["zh-Hans"] = "返回" },
	escape = { en = "Esc", ["zh-Hans"] = "Esc" },
	-- The row under the pointer and the field of view the view shows for it. 镜头 as in 普通镜头, the normal view.
	view_shows = { en = "View shows: %s, %s", ["zh-Hans"] = "当前镜头：%s，%s" },
	-- A row that cannot change yet: the row to set first, and to what.
	set_first = { en = "Set %s to %s to change this row.", ["zh-Hans"] = "将“%s”设为“%s”后可调整此项。" },
}

-- "zh-Hant", "zh-Hans" or "en" for the game's culture ("fr", "zh-Hans-CN"...). The game's "he" is its own harmonised
-- Simplified Chinese, not Hebrew (Mods Menu).
function M.lang_of(culture)
	local c = type(culture) == "string" and culture:lower() or ""
	for _, prefix in ipairs(TRADITIONAL) do
		if c:sub(1, #prefix) == prefix then return "zh-Hant" end
	end
	if c:sub(1, 2) == "zh" or c == "he" or c:sub(1, 3) == "he-" then return "zh-Hans" end
	return "en"
end

-- A text in lang: its words in that language when it has them, else its English ones, as Mods Menu shows it; nil for
-- something that is no text.
function M.pick(t, lang)
	if type(t) == "string" then return t end
	if type(t) ~= "table" then return nil end
	local s = t[lang]
	if type(s) == "string" and s ~= "" then return s end
	return type(t.en) == "string" and t.en or nil
end

function M.own(name, lang)
	return M.pick(OWN[name], lang)
end

-- An entry of the descriptor's settings: a heading, or a setting with its texts in every language.
local function entry(s)
	if s.type == "heading" then return { heading = true, label = s.label } end
	if type(s.key) ~= "string" then return nil end
	local options = {}
	if type(s.options) == "table" then
		for _, o in ipairs(s.options) do
			if type(o) == "table" and type(o.value) == "string" then options[o.value] = o.label end
		end
	end
	return { key = s.key, label = s.label, help = s.help, options = options }
end

-- The descriptor at path: { title, order }, order its headings and settings in the file's order, each text kept in
-- every language; or nil and why.
function M.load(path)
	local f = path and io.open(path, "rb")
	if f == nil then return nil, "cannot be opened" end
	local text = f:read(MAX_FILE_BYTES + 1)
	f:close()
	if text == nil or #text > MAX_FILE_BYTES then
		return nil, string.format("is empty or larger than %d bytes", MAX_FILE_BYTES)
	end
	local doc, why = Tree.decode(text)
	if type(doc) ~= "table" or type(doc.settings) ~= "table" then
		return nil, why and string.format("is not valid JSON (%s)", why) or "has no settings"
	end
	local D = { title = doc.title, order = {} }
	for _, s in ipairs(doc.settings) do
		local e = type(s) == "table" and entry(s) or nil
		if e ~= nil then D.order[#D.order + 1] = e end
	end
	return D
end

return M
