-- The rows of a mod's page (taken out of mod_panel_screen.lua): Mod Panel's own page leaves out the rows it keeps
-- elsewhere (D22, D28) and shows its two settings of the combination as one row (D131); a folded section's rows are not
-- shown (mod_panel_folds.lua, D149).

local Settings = require("mod_panel_settings")
local ComboRow = require("mod_panel_combo_row")

local M = {}

-- own: Mod Panel's folder name; folds: mod_panel_folds.lua.
function M.new(own, folds)
	local P = {}
	local pages = setmetatable({}, { __mode = "k" })   -- by entry: Mod Panel's page, made once

	-- The rows of a mod's page, its folded sections' too.
	function P.all_rows_of(entry)
		if entry.name ~= own then return entry.rows end
		local rows = pages[entry]
		if rows == nil then
			rows = {}
			for _, row in ipairs(entry.rows) do
				local key = row.key
				if key == Settings.COMBO_FIRST then
					rows[#rows + 1] = ComboRow.of(entry)
				elseif key ~= Settings.COMBO_SECOND and not Settings.HIDDEN[key] then
					rows[#rows + 1] = row
				end
			end
			pages[entry] = rows
		end
		return rows
	end

	-- The rows a mod's page shows: those outside its folded sections.
	function P.rows_of(entry)
		return folds.shown(entry, P.all_rows_of(entry))
	end

	return P
end

return M
