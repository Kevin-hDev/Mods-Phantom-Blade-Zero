-- The authors' texts as Mods Menu takes them (0.8.3 for the trimming and the lengths, 0.9.2 for the languages): a text
-- is a string or an object of languages, each of the game's 15 kept, en needed, each trimmed and cut to a length. A
-- language's exact code wins over its aliases (zh-CN, es, ja-JP...), the first alias in the file over a later one
-- (D151). Lengths count characters; Mods Menu counts UTF-16 units, so only a character beyond U+FFFF (an emoji) counts
-- otherwise.

local Json = require("mod_panel_json")
local Written = require("mod_panel_written")

local M = {}

-- The game's text languages, as Mods Menu 0.9.2 names them.
M.LANGS = { "en", "de", "es-419", "es-ES", "fr", "it", "ja", "ko", "pt-BR", "pt-PT", "ru", "th", "vi", "zh-Hans",
	"zh-Hant" }
local LANGS = M.LANGS
local EXACT = {}
for _, lang in ipairs(LANGS) do EXACT[lang] = true end
local PLAIN = { en = true, de = true, fr = true, it = true, ja = true, ko = true, ru = true, th = true, vi = true }
local TRADITIONAL = { "hant", "tw", "hk", "mo" }
-- The language a text missing in a language takes before English: a reader of one of these reads the other better.
local NEIGHBOUR = { ["zh-Hans"] = "zh-Hant", ["zh-Hant"] = "zh-Hans", ["es-419"] = "es-ES", ["es-ES"] = "es-419",
	["pt-BR"] = "pt-PT", ["pt-PT"] = "pt-BR" }
-- What JavaScript's trim() takes away: its white space and line ends.
local SPACES = { [0x09] = true, [0x0A] = true, [0x0B] = true, [0x0C] = true, [0x0D] = true, [0x20] = true,
	[0xA0] = true, [0x1680] = true, [0x2028] = true, [0x2029] = true, [0x202F] = true, [0x205F] = true,
	[0x3000] = true, [0xFEFF] = true }
for code = 0x2000, 0x200A do SPACES[code] = true end

-- The character starting at byte i, as a code and its length in bytes; nil where the bytes are not UTF-8.
local function char_at(s, i)
	local ok, code = pcall(utf8.codepoint, s, i)
	if not ok then return nil end
	return code, #utf8.char(code)
end

-- s without JavaScript's white space at either end.
function M.trim(s)
	local first, last = 1, #s
	while first <= last do
		local code, size = char_at(s, first)
		if code == nil or not SPACES[code] then break end
		first = first + size
	end
	while last >= first do
		local start = last
		while start > first and (s:byte(start) & 0xC0) == 0x80 do start = start - 1 end
		local code, size = char_at(s, start)
		if code == nil or not SPACES[code] or start + size - 1 ~= last then break end
		last = start - 1
	end
	return s:sub(first, last)
end

-- s as the game can take it (D106): each byte that starts no UTF-8 character becomes "?", a sign every font has.
-- UE4SS turns a text into the engine's by a conversion that throws a C++ exception on such bytes, past any pcall
-- (String.hpp, to_wstring), and an author may save a file in Windows-1252 or GBK.
function M.safe(s)
	if type(s) ~= "string" or utf8.len(s) ~= nil then return s end
	local out, i = {}, 1
	while i <= #s do
		local code, size = char_at(s, i)
		if code == nil then
			out[#out + 1], i = "?", i + 1
		else
			out[#out + 1], i = s:sub(i, i + size - 1), i + size
		end
	end
	return table.concat(out)
end

-- The number of characters in s (of bytes, where s is not UTF-8).
function M.length(s)
	return utf8.len(s) or #s
end

-- s cut to max characters (bytes, where s is not UTF-8).
function M.cut(s, max)
	if max == nil or M.length(s) <= max then return s end
	if utf8.len(s) == nil then return s:sub(1, max) end
	return s:sub(1, utf8.offset(s, max + 1) - 1)
end
local cut = M.cut

-- A text from a mod's file as the log cites it: MAX_CITED characters at most, then "...", each control character
-- as "?". A value of 200 000 characters made a line as long in the log (audit of 0.4.3), and a line break inside
-- a key wrote a line that looked like Mod Panel's own (audit of 0.7.0).
local MAX_CITED = 64
function M.cited(s)
	s = M.length(s) > MAX_CITED and cut(s, MAX_CITED) .. "..." or s
	return (s:gsub("%c", "?"))
end

-- As Mods Menu reads a text: a string trimmed and cut to max characters, or nil for an empty one or no string.
function M.str(v, max)
	if type(v) ~= "string" then return nil end
	local t = M.trim(v)
	if t == "" then return nil end
	return cut(t, max)
end

-- Whether s is p or starts with p and a dash.
local function under(s, p)
	return s == p or s:sub(1, #p + 1) == p .. "-"
end

-- The language of a code or an alias (zh-CN, zhHans, zh_TW, es, pt, de-DE, ja-JP, en-GB...), or nil for none.
function M.code(k)
	if type(k) ~= "string" then return nil end
	local l = k:gsub("_", "-"):lower()
	local st = l:match("^zh([st])$") or l:match("^zhhan([st])$")
	if st then l = "zh-han" .. st end
	local base, rest = l:match("^([^-]*)%-?(.*)$")
	if base == "zh" then
		for _, p in ipairs(TRADITIONAL) do
			if under(rest, p) then return "zh-Hant" end
		end
		return "zh-Hans"
	end
	if base == "es" then return (rest == "" or under(rest, "es")) and "es-ES" or "es-419" end
	if base == "pt" then return under(rest, "br") and "pt-BR" or "pt-PT" end
	return PLAIN[base] and base or nil
end

-- As Mods Menu reads a text of languages: each language's text from a string or an object of languages, or nil without
-- an English text. A decoded object's aliases are read in the file's order, after every exact code.
function M.text(v, max)
	local o = type(v) == "table" and v or { en = v }
	local t = {}
	for _, lang in ipairs(LANGS) do t[lang] = M.str(o[lang], max) end
	for _, key in ipairs(Json.keys(o)) do
		-- An exact code is read above: only an alias needs M.code (audit of 0.7.0).
		local lang = not EXACT[key] and M.code(key) or nil
		if lang ~= nil and t[lang] == nil then t[lang] = M.str(o[key], max) end
	end
	return t.en and t or nil
end

-- One of the 15 languages for the game's culture ("fr", "zh-Hans-CN", "pt-BR"...), English for any other. The game's
-- "he" is its own harmonised Simplified Chinese, not Hebrew (Mods Menu).
function M.lang_of(culture)
	local c = type(culture) == "string" and culture:lower() or ""
	if under(c, "he") then return "zh-Hans" end
	return M.code(c) or "en"
end

-- The language a text missing in lang takes before English, or nil.
function M.neighbour(lang) return NEIGHBOUR[lang] end

-- A text in lang: its own words, then its neighbour's (noted as borrowed, D159), then English; a string as it is.
function M.pick(t, lang)
	if type(t) == "string" then return t end
	if type(t) ~= "table" then return nil end
	if t[lang] ~= nil then return t[lang] end
	local near = NEIGHBOUR[lang]
	if near ~= nil and t[near] ~= nil then
		Written.borrow(t[near], near)
		return t[near]
	end
	return t.en
end

return M
