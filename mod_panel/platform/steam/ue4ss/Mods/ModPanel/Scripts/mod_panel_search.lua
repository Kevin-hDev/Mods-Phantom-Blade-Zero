-- The search of the list (D186): the text typed, MAX characters at most, and whether a mod matches: each word typed
-- found in the mod's names, in any order and anywhere. A mod's names are its title in each of its languages, the one
-- shown among them, then its folder's name, brought to their words (mod_panel_search_words.lua): kept once made, for
-- as long as the catalog keeps the mod's table, which it makes anew when it reads the mod again. Typing itself:
-- mod_panel_typing.lua; whether the field types: mod_panel_keys.lua.

local Words = require("mod_panel_search_words")

local M = {}

M.MAX = 16                        -- characters: enough to tell two names apart
local BACK = "\b"                 -- Backspace, as mod_panel_keys.lua gives it

function M.new()
	-- text: typed; words: its words; version: raised at each change of the text.
	local st = { text = "", words = {}, version = 0 }
	local names = setmetatable({}, { __mode = "k" })   -- each mod's names, by its entry
	local S = {}

	local function set(text)
		if text == st.text then return false end
		st.text, st.words, st.version = text, Words.words(text), st.version + 1
		return true
	end

	-- entry's names brought to their words, a space at each end.
	local function names_of(entry)
		local n = names[entry]
		if n ~= nil then return n end
		local parts = {}
		if type(entry.title) == "table" then
			for _, title in pairs(entry.title) do parts[#parts + 1] = Words.normalize(title) end
		end
		parts[#parts + 1] = Words.normalize(entry.name)
		n = " " .. table.concat(parts, " ") .. " "
		names[entry] = n
		return n
	end

	function S.text() return st.text end
	function S.version() return st.version end

	-- Whether the text has a word: only then does it leave mods out.
	function S.active() return #st.words > 0 end

	-- One key typed: a small letter, a digit or a space, added while the text is shorter than MAX; "\b", the last
	-- character erased. Whether the text changed.
	function S.put(token)
		if token == BACK then return set(st.text:sub(1, -2)) end
		if type(token) ~= "string" or not token:match("^[a-z0-9 ]$") or #st.text >= M.MAX then return false end
		return set(st.text .. token)
	end

	-- The text erased; whether there was one.
	function S.clear() return set("") end

	-- Whether entry, a mod of the catalog, matches the text: always, while it has no word.
	function S.matches(entry)
		if #st.words == 0 then return true end
		local n = names_of(entry)
		for _, w in ipairs(st.words) do
			if not n:find(w, 1, true) then return false end
		end
		return true
	end

	return S
end

return M
