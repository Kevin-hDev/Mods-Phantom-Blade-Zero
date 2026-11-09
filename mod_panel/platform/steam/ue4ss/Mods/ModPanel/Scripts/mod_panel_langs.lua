-- Mod Panel's own texts in the game's languages but English (D152): one file a language, mod_panel_lang_<code>.lua
-- (fr, zh_hans, es_419...), each { words, buttons, keys } by the ids English has in mod_panel_words.lua,
-- mod_panel_pad_names.lua ("<engine name>.<PlayStation|Xbox>") and mod_panel_key_names.lua. A text a language lacks
-- is its neighbour's (mod_panel_text.lua), then English, which its own module gives. A file is read the first time its
-- language is asked; one that cannot be read gives nothing, and check() says so at start.

local Text = require("mod_panel_text")
local Written = require("mod_panel_written")

local M = {}

local loaded = {}                 -- by language: its table, or false when its file cannot be read
local failed = {}                 -- by language: why its file could not be read

-- The module name of lang's file.
function M.module(lang)
	return "mod_panel_lang_" .. (lang:lower():gsub("-", "_"))
end

local function load(lang)
	if lang == nil or lang == "en" then return nil end
	local t = loaded[lang]
	if t == nil then
		local ok, got = pcall(require, M.module(lang))
		if ok and type(got) == "table" then
			t = got
		else
			t, failed[lang] = false, ok and "not a table" or tostring(got)
		end
		loaded[lang] = t
	end
	return t or nil
end

local function lookup(section, id, l)
	local t = load(l)
	local s = t and t[section] and t[section][id]
	if type(s) == "string" then return s end
	return nil
end

-- The text id of section ("words", "buttons", "keys") in lang, else in its neighbour, else nil (English is the
-- caller's). No table made for the two languages: this runs for each text of each built page (audit of 0.7.0).
function M.get(section, id, lang)
	local s = lookup(section, id, lang)
	if s ~= nil then return s end
	local near = Text.neighbour(lang)
	s = near and lookup(section, id, near)
	if s ~= nil then Written.borrow(s, near) end
	return s
end

-- At start: every language's file read; each that cannot be read told to note(line).
function M.check(note)
	for _, lang in ipairs(Text.LANGS) do load(lang) end
	for _, lang in ipairs(Text.LANGS) do
		if failed[lang] then note(string.format("the %s texts cannot be read, English instead (%s)", lang, failed[lang])) end
	end
end

return M
