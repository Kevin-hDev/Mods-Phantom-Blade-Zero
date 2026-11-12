-- A text brought to its words for the search (D186): its letters in lower case, the accents of the Latin letters taken
-- off (Latin-1, Latin Extended-A, Romanian's ș and ț, and the combining accents), any other sign a space. Vietnamese's
-- letters (Latin Extended Additional) are not brought back: its mods are found by their English names and their
-- folders'. No pattern here uses a class of letters or spaces (%a, %w, %s): Lua takes them from the C locale, where
-- 0xA0, the second byte of "à", can be a space (it split this file's table in the tests, Python having set the locale).

local M = {}

-- Each accented small letter and what it becomes. Its capital is folded too: 32 codes before it in Latin-1, the code
-- just before it in the others; ß and ÿ have none there, Ÿ is apart.
local SMALL = "à=a á=a â=a ã=a ä=a å=a æ=ae ç=c è=e é=e ê=e ë=e ì=i í=i î=i ï=i ð=d ñ=n ò=o ó=o ô=o õ=o ö=o ø=o "
	.. "ù=u ú=u û=u ü=u ý=y þ=th ÿ=y ß=ss ā=a ă=a ą=a ć=c ĉ=c ċ=c č=c ď=d đ=d ē=e ĕ=e ė=e ę=e ě=e ĝ=g ğ=g ġ=g "
	.. "ģ=g ĥ=h ħ=h ĩ=i ī=i ĭ=i į=i ı=i ĵ=j ķ=k ĺ=l ļ=l ľ=l ŀ=l ł=l ń=n ņ=n ň=n ō=o ŏ=o ő=o œ=oe ŕ=r ŗ=r ř=r "
	.. "ś=s ŝ=s ş=s š=s ţ=t ť=t ŧ=t ũ=u ū=u ŭ=u ů=u ű=u ų=u ŵ=w ŷ=y ź=z ż=z ž=z ș=s ț=t"
local NO_CAPITAL = { [0xDF] = true, [0xFF] = true }
local FOLD = { [utf8.char(0x178)] = "y" }
for pair in SMALL:gmatch("[^ ]+") do
	local small, base = pair:match("^(.-)=(.+)$")
	local code = utf8.codepoint(small)
	FOLD[small] = base
	if not NO_CAPITAL[code] then FOLD[utf8.char(code < 0x100 and code - 32 or code - 1)] = base end
end

-- s's words, in lower case, apart by one space, none at either end; "" for no string.
function M.normalize(s)
	if type(s) ~= "string" then return "" end
	-- The combining accents (U+0300 to U+036F, a letter then its accent, as macOS often spells a name) go first: each
	-- would become a space and cut its word in two (audit of 1.0.4). Every letter of the table is two bytes long in
	-- UTF-8; a byte of a longer character is never one of them. lower() may change a byte above 127 too, never into a
	-- letter or a digit: it then becomes a space.
	local bare = s:gsub("\204[\128-\191]", ""):gsub("\205[\128-\175]", "")
	local folded = bare:gsub("[\192-\223][\128-\191]", FOLD):lower():gsub("[^a-z0-9]+", " ")
	return (folded:match("^ *(.-) *$"))
end

-- The words of s, in order.
function M.words(s)
	local t = {}
	for w in M.normalize(s):gmatch("[^ ]+") do t[#t + 1] = w end
	return t
end

return M
