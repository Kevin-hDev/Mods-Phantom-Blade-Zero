-- Where things are, for the navigation (mod_panel_nav.lua): the row a mod's page starts on, and a mod's place in a
-- list. Taken out of mod_panel_nav.lua in 1.0.4, when the search's changes made it outgrow one file.

local M = {}

-- The row a page starts on: its first that is not a title, Up reaching a title above it; a title when the page
-- shows only titles (every section folded).
function M.first(r)
	for i = 1, #r do
		if r[i].type ~= "heading" then return i end
	end
	return r[1] ~= nil and 1 or nil
end

-- The place of the mod called name in list, or nil.
function M.place(list, name)
	for i, entry in ipairs(list) do
		if entry.name == name then return i end
	end
	return nil
end

return M
