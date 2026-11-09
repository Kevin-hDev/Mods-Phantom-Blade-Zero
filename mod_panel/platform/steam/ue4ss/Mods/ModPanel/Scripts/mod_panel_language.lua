-- The open panel's language (D153, taken out of mod_panel_panel.lua): the Language row's, else the game's. The game's
-- is asked at each opening, as the player may change it in the game's main menu, and again only when the row changes:
-- it does not change in play. The texts, and their font (D154), follow it at once, panel open too.

local Settings = require("mod_panel_settings")
local Game = require("mod_panel_game")
local Pieces = require("mod_panel_pieces")
local Make = require("mod_panel_make")

local M = {}

-- d: { settings() (Mod Panel's settings in use), screen (mod_panel_screen.lua), key_label(lang), report(fmt, ...),
-- problem(fmt, ...) }.
function M.new(d)
	-- chosen: the Language row's value last seen; lang: the language it gave.
	local G = { chosen = nil, lang = nil }

	-- The panel's language now, its texts and font set to it; opening: the game's language asked again.
	function G.speak(gi, opening)
		local chosen = d.settings().language
		if opening or chosen ~= G.chosen or G.lang == nil then
			G.chosen = chosen
			G.lang = (chosen ~= nil and chosen ~= Settings.GAME) and chosen or Game.language(gi)
		end
		local lang = G.lang
		-- A font not in memory at a build is looked for again at the next opening, not at each tick.
		if Pieces.language(lang, d.report) or (opening and Make.lacking()) then
			local refused = Make.refont()
			if refused > 0 then d.problem("panel: the game refused the %s font to %d texts", lang, refused) end
		end
		if lang ~= d.screen.lang then d.screen.start(lang, d.key_label(lang)) end
		return lang
	end

	return G
end

return M
