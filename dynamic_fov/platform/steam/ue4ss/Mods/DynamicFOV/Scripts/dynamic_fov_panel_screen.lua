-- What the open panel shows (1.0.2): its fixed texts in the game's language, each row's value and look, the line
-- saying what the view shows, the explanation of the row under the pointer, and the buttons' words. All of it is worked
-- out at each frame; the view sets in the game only what changed, and again what the game refused
-- (dynamic_fov_panel_view.lua). No memory here of what was painted: one hid the refusals from the view (audit of
-- 5 November 2026).

local Texts = require("dynamic_fov_panel_texts")
local Rows = require("dynamic_fov_panel_rows")
local View = require("dynamic_fov_panel_view")

local M = {}

-- lines and title: the panel's (dynamic_fov_panel_rows.lua). preview(fov or nil): every situation shows that field
-- of view, or its own again.
function M.new(lines, title, preview)
	-- over: the row under the pointer. fov: the field of view the camera was asked to show for it.
	local S = { lang = nil, over = nil, fov = nil, close_text = nil }

	local function say(t) return Texts.pick(t, S.lang) end
	local function own(name) return Texts.own(name, S.lang) end

	local function line_of(key)
		for _, line in ipairs(lines) do
			if line.key == key then return line end
		end
	end

	local function paint(s)
		for i, line in ipairs(lines) do
			if line.kind ~= nil then
				local v = Rows.value(line, s)
				View.row(i, Rows.text(line, v, say, own), v, Rows.waits_for(line, s) ~= nil, i == S.over)
			end
		end
	end

	-- The explanation of row i: what to set first while it waits for another setting, then its own.
	local function help_of(i, s)
		local line = i and lines[i]
		if line == nil then return "" end
		local text = say(line.help) or ""
		local key, value = Rows.waits_for(line, s)
		local first = key and line_of(key)
		if first == nil then return text end
		return string.format(own("set_first"), say(first.label) or key, Rows.text(first, value, say, own)) .. "\n" .. text
	end

	-- The title and the rows' names; the view sets only what changed, so a new panel gets them all.
	local function fixed()
		View.title(say(title) or "")
		for i, line in ipairs(lines) do View.label(i, say(line.label) or line.key or "") end
	end

	-- At the opening: the texts in lang ("en", "zh-Hans"...), the panel key's name on Close (nil for None), nothing
	-- under the pointer yet.
	function S.start(lang, key)
		S.lang = lang
		fixed()
		S.close_text = own("close") .. "   " .. (key and key .. " / " .. own("escape") or own("escape"))
		View.buttons(own("restore"), S.close_text)
		View.view_line("")
		View.help("")
		S.over, S.fov = nil, nil
	end

	-- At each frame: the settings s in use, the row under the pointer, whether Restore defaults offers to undo. A slider
	-- moved on a row that cannot change is put back by the view, its value no longer where the slider stands.
	function S.frame(s, over, undo)
		-- Also at the opening: the panel opens and paints in the same tick, before the game draws it.
		View.backdrop(s.panel_opacity)
		fixed()
		View.buttons(own(undo and "undo" or "restore"), S.close_text)
		S.over = over
		paint(s)
		local line = over and lines[over]
		local fov = Rows.preview(line, s)
		if fov ~= S.fov then
			S.fov = fov
			preview(fov)
		end
		View.view_line(fov and string.format(own("view_shows"), say(line.label) or line.key,
			Rows.text(line, fov, say, own)) or "")
		View.help(help_of(over, s))
	end

	-- At the closing: each situation has its own field of view back.
	function S.stop()
		if S.fov == nil then return end
		S.fov = nil
		preview(nil)
	end

	return S
end

return M
