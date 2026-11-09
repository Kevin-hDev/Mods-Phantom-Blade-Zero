-- The language a text shown was borrowed from (D159): a text missing in the panel's language takes its neighbour's
-- (mod_panel_text.lua, mod_panel_langs.lua), and is drawn in that language's font, not the panel's. The Traditional
-- Chinese font lacks the characters only Simplified Chinese has: an author's name in Simplified, shown in it, lost
-- them (trial of 0.6.0, 8 November 2026, verified in game). A text is known by its words, so a text put together
-- from parts (the descriptions) is noted too when one of its parts was borrowed.

local M = {}

-- Texts come from the authors' files: at most MAX noted, all forgotten when full; a text shown again is noted again
-- at its next pick.
local MAX = 4096
local S = { from = {}, count = 0 }

-- s, a text taken from the language from in place of the panel's.
function M.borrow(s, from)
	if type(s) ~= "string" or S.from[s] ~= nil then return end
	if S.count >= MAX then S.from, S.count = {}, 0 end
	S.from[s] = from
	S.count = S.count + 1
end

-- The language s was borrowed from, or nil for the panel's.
function M.from(s)
	return S.from[s]
end

-- The parts joined by sep; the whole noted as borrowed when one of its parts is, from the first such part's language.
function M.join(parts, sep)
	local s = table.concat(parts, sep)
	for _, part in ipairs(parts) do
		local from = S.from[part]
		if from ~= nil then
			M.borrow(s, from)
			break
		end
	end
	return s
end

return M
