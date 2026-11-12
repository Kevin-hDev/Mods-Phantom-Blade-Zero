-- Typing in the search field (D186). Begun by a click on the field or Ctrl+F; the keys that write (mod_panel_keys.lua,
-- the only holder of whether the field types) then go to the text in their order, Backspace erasing one; Enter ends
-- the typing, the search kept; Escape erases the search and ends it; Up and Down go to the mod found before or after;
-- the other keys do nothing. A press on anything of the panel but the field and its cross, a click the game got outside
-- the panel, or a button of the controller ends it, the text kept: that frame's keys do nothing more, the pointer and
-- the button then act as always. The cross erases the text. Each change of the text looks for the chosen mod again: it
-- stays while the search finds it, else gives way to the first mod found, or to none, the head left as it is
-- (mod_panel_nav.lua). At the panel's closing the typing ends and the text is erased: a search forgotten would hide
-- mods at the next opening without the player knowing why. What ended each typing is counted for the closing's line.
-- A key held writes again (mod_panel_key_repeat.lua, D187).

local Keys = require("mod_panel_keys")
local Usage = require("mod_panel_usage")
local KeyRepeat = require("mod_panel_key_repeat")

local M = {}

local NONE = {}

-- d: { search (mod_panel_search.lua), nav (mod_panel_nav.lua), controls (mod_panel_controls.lua), report(fmt, ...)
-- (the panel's lines) }.
function M.new(d)
	local search, nav = d.search, d.nav
	local T = {}

	local function begin()
		if not Keys.typing() then Keys.type(true, d.report) end
	end

	-- why: what ended it, one of mod_panel_usage.lua's causes.
	local function finish(why)
		if not Keys.typing() then return end
		Keys.type(false, d.report)
		KeyRepeat.stop()
		Usage.search_ended(why)
	end

	-- What ends the typing from elsewhere in this frame, or nil: c, the controller's commands; R, what the pointer did.
	local function ended(c, R)
		if c ~= nil then return "pad" end
		if R.on_search then return nil end
		if R.pressed then return "press" end
		return d.controls.clicked() and "click" or nil
	end

	-- At each frame of the open panel, out of a wait for a key: k, the keys' presses; c, the controller's commands; R,
	-- what the pointer did; now, the clock. Returns the presses and the commands left to the panel's commands: none
	-- while it types.
	function T.frame(k, c, R, now)
		if R.search then Usage.search_click("field") end
		if R.clear then Usage.search_click("cross") end
		local edited = R.clear and search.clear()
		if R.search or (k ~= nil and k.search > 0) then begin() end
		if not Keys.typing() then
			if edited then nav.refilter(true) end
			return k, c
		end
		local why = ended(c, R)
		if why ~= nil then
			finish(why)
			if edited then nav.refilter(true) end
			return nil, c
		end
		local typed = Keys.typed()
		local again, n = KeyRepeat.frame(typed, now, d.controls.down)
		typed, n = typed or NONE, n or 0
		for _, token in ipairs(typed) do edited = search.put(token) or edited end
		for _ = 1, n do edited = search.put(again) or edited end
		Usage.typed(#typed, n)
		if k ~= nil and k.escape > 0 then
			edited = search.clear() or edited
			finish("escape")
		elseif k ~= nil and k.enter > 0 then
			finish("enter")
		end
		if edited then nav.refilter(true) end
		if k ~= nil and k.up + k.down > 0 then KeyRepeat.stop() end
		if k ~= nil and k.up > 0 then nav.switch(-1, k.up) end
		if k ~= nil and k.down > 0 then nav.switch(1, k.down) end
		return nil, nil
	end

	-- At the panel's closing.
	function T.close()
		finish("close")
		search.clear()
	end

	return T
end

return M
