-- Restore defaults and Undo (D21). R, or a click on the button under the rows: every row the page
-- shows that has a default goes back to it, the rows made from the settings file left; the button then undoes it,
-- until another change or another mod. Undo gives the file back as it was: only the rows Restore defaults changed
-- (D116). Taken out of mod_panel_changes.lua at the audit of 0.4.3.
-- A row made of several settings (the controller's combination, mod_panel_combo_row.lua) stands for each of them.

local M = {}

-- d: { edits (mod_panel_edits.lua), set(name, row, v, now) (a value changed, as every change of the panel is: it
-- tells All mods of a mod turned on, D163), value(entry, row) (the value the panel shows), adjustable(row) (a row
-- that changes), leaves(entry, row) (a row Restore defaults leaves: a key row whose default another uses now, D64) }.
function M.new(d)
	-- undo: { name, before = { { row, its value, whether a change of it waited } } } after Restore defaults.
	local R = { undo = nil }

	-- A row Restore defaults takes: one that changes, with a default from its descriptor.
	local function restorable(row)
		return d.adjustable(row) and row.default ~= nil and not row.generated
	end

	-- Whether a row the page shows is, or stands for, one Restore defaults takes; asked at each frame, so it makes no
	-- table.
	local function shows_restorable(row)
		if row.parts == nil then return restorable(row) end
		for _, part in ipairs(row.parts) do
			if restorable(part) then return true end
		end
		return false
	end

	-- R, or a click on the button under the rows: Restore defaults on the rows the page shows, or Undo just after it.
	function R.restore(entry, rows, now)
		local u = R.undo
		R.undo = nil
		if u ~= nil and u.name == entry.name then
			-- Undo gives the file back (audit of 0.4.3): a default set by Restore defaults and not written yet is dropped,
			-- so the file keeps its own text; one written meanwhile, or a change that waited before, is set again.
			for _, c in ipairs(u.before) do
				if not c[3] and d.edits.value(entry.name, c[1].key) ~= nil then
					d.edits.drop(entry.name, c[1].key)
				else
					d.set(entry.name, c[1], c[2], now)
				end
			end
			return
		end
		-- before: the rows Restore defaults changes only. The button turns to Undo as before 0.4.4 once a row could be
		-- restored, even when none was changed (D21).
		local before, any = {}, false
		for _, shown in ipairs(rows) do
			for _, row in ipairs(shown.parts or { shown }) do
				local v = nil
				if restorable(row) and not d.leaves(entry, row) then v = d.value(entry, row) end
				any = any or v ~= nil
				if v ~= nil and v ~= row.default then
					before[#before + 1] = { row, v, d.edits.value(entry.name, row.key) ~= nil }
					d.set(entry.name, row, row.default, now)
				end
			end
		end
		if any then R.undo = { name = entry.name, before = before } end
	end

	-- What the button under the rows says for entry: "undo" just after Restore defaults, else "restore"; nil when no
	-- row shown has a default, and then there is no button.
	function R.label(entry, rows)
		if R.undo ~= nil and R.undo.name == entry.name then return "undo" end
		for _, row in ipairs(rows) do
			if shows_restorable(row) then return "restore" end
		end
		return nil
	end

	-- Another change, another mod or the closing: Undo ends there.
	function R.forget() R.undo = nil end

	return R
end

return M
