-- The panel's life. Opened by the panel key, the controller's button or its combination in steps while hidden
-- (mod_panel_opening.lua, D38), its input context on (mod_panel_controls.lua), then shown with the inputs taken; never
-- while another mod's panel is open (mod_panel_claim.lua, D98); Escape alone stops an opening. Closed by the key, the
-- button, the combination, Escape, Close, a load, another character, a cutscene, a game pause or the game lifting the
-- freeze (mod_panel_freeze.lua), the game taking the panel or its controls back, or Mod Panel turned off: everything
-- given back to the game first, then the files written (mod_panel_closing.lua, D102). An error while the panel is shown
-- refuses the opening. Play is looked at ten times a second, the screen at each frame; the commands
-- (mod_panel_commands.lua) and the changes' writing (mod_panel_edits.lua) run in the open frames. A reason not to open
-- is said once until another comes. Taken from Dynamic FOV 1.0.4 (dynamic_fov_panel.lua).

local U = require("mod_panel_unreal")
local L = require("mod_panel_layout")
local Frame = require("mod_panel_frame")
local View = require("mod_panel_view")
local Game = require("mod_panel_game")
local Input = require("mod_panel_input")
local Pointer = require("mod_panel_pointer")
local Scroll = require("mod_panel_scroll")
local Opening = require("mod_panel_opening")
local Usage = require("mod_panel_usage")
local Hints = require("mod_panel_hints")
local Parts = require("mod_panel_parts")
local Freeze = require("mod_panel_freeze")
local Claim = require("mod_panel_claim")
local Closing = require("mod_panel_closing")
local Language = require("mod_panel_language")

local M = {}

-- d: catalog, edits (mod_panel_edits.lua), state (mod_panel_state.lua), own (Mod Panel's folder name), max (the darkest
-- backdrop, in %), ticks_a_second (how many of main.lua's ticks make a second), settings() (Mod Panel's settings in
-- use), key_label(lang) (the panel key's name), pad_button() (the controller's button that opens and closes the panel,
-- or nil when none is read), pad_combo() (its combination, or nil), report(fmt, ...), said(fmt, ...) and problem(fmt,
-- ...) (the panel's lines, its openings' and closings', and its failures, each bounded on its own, D104).
function M.new(d)
	local parts = Parts.new(d)
	local controls, capture, listing, head = parts.controls, parts.capture, parts.listing, parts.head
	local screen, nav, commands = parts.screen, parts.nav, parts.commands
	local language = Language.new({ settings = d.settings, screen = screen, key_label = d.key_label,
		report = d.report, problem = d.problem })
	local opening = Opening.new(d.catalog, screen.all_rows_of, d.max, function(line) d.report("%s", line) end,
		function(gi) language.speak(gi, true) end)
	local freeze = Freeze.new(d.report, d.problem)
	local claim = Claim.new(d.own, d.problem)
	local close = Closing.new({ commands = commands, controls = controls, freeze = freeze, claim = claim, nav = nav,
		edits = d.edits, state = d.state, said = d.said, problem = d.problem })
	-- state: "closed", "opening" or "open". taken: the input context tried at this opening, the panel shown at the
	-- next frame. by_pad: this opening came from the controller's button. frames, longest: this opening's frames and
	-- its longest. opened: openings in all. ticks: this opening's ticks.
	local P = { state = "closed", refused = nil, ready = false, taken = false, by_pad = false, told = false, frames = 0,
		longest = 0, opened = 0, ticks = 0 }
	local look = {}                   -- what the screen paints, a table used again at each frame

	local function refuse(why, failed)
		P.state = "closed"
		controls.off()
		if why == P.refused then return end
		P.refused = why
		local say = failed and d.problem or d.report
		say("panel: not opened, %s", why)
	end

	-- R: what the pointer did (mod_panel_pointer.lua), nil before the first read of an opening.
	local function paint(R)
		look.mod, look.row, look.head, look.now, look.back = nav.mod, nav.focus(), nav.head, os.clock(), nav.backs()
		look.hover, look.on_restore, look.lit = R and R.band, R and R.on_restore, R and R.lit
		look.opacity, look.icons = head.opacity(d.settings().opacity), d.settings().icons
		look.descriptions = d.state.get("descriptions")
		screen.paint(look)
	end

	function P.close(pc, why)
		if P.state == "opening" then
			P.state = "closed"
			controls.off()
			d.said("panel: opening stopped (%s)", why)
			return
		end
		if P.state ~= "open" then return end
		P.state = "closed"
		close(pc, why)
	end

	-- The panel made, painted then shown; whether it shows. The help's device and the controller's icons first, so the
	-- hidden panel's first paint has them; what the player does counted from here, so that any closing says this
	-- opening's. The frame is looked at first: the last look was two frames before (D103).
	local function show(pc)
		local other = claim.taken()
		if other then return refuse(other, false) end
		if not Frame.alive() then return refuse("the game took the panel off the screen", true) end
		local lang = language.speak(opening.gi, true)
		head.start()
		nav.start(d.state.get("mod"))
		freeze.start()
		controls.start(pc, P.by_pad)
		screen.start(lang, d.key_label(lang))
		Usage.start()
		paint()
		local ok, err = Frame.show(true)
		if not ok then return refuse("the panel could not be shown (" .. tostring(err) .. ")", true) end
		P.state, P.refused, P.opened, P.ticks = "open", nil, P.opened + 1, 0
		claim.hold()
		commands.start()
		Pointer.reset(d.problem)
		Input.take(pc, d.problem, controls.on())
		return true
	end

	-- One frame of an opening. The frame that shows the panel does nothing else: it paints the whole panel, and the
	-- frames before it keep their 3 ms (D38), the input context's alone excepted (optimisation.md, 7.1). The log line
	-- is written once that frame is measured too.
	local function opening_frame(pc)
		local start = os.clock()
		local opened = false
		if not P.ready then
			local done, why, failed = opening.step(pc)
			if done == nil then return refuse(why, failed) end
			P.ready = done
		elseif not P.taken then
			P.taken = true
			-- Opened by the controller, the panel would leave it nothing to do, not even closing (D78).
			if not controls.take(pc, opening.gi) and P.by_pad then
				return refuse("the controller would do nothing in the panel: the panel key opens it", false)
			end
		else
			local ok, res = pcall(show, pc)
			if not ok then
				-- An error past the frame shown closes it as any closing, the error said in its line; before it, the
				-- opening is refused (D102).
				if P.state == "open" then return P.close(pc, "an error while it was shown: " .. tostring(res)) end
				return refuse("the panel could not be shown (" .. tostring(res) .. ")", true)
			end
			opened = res
		end
		P.frames, P.longest = P.frames + 1, math.max(P.longest, os.clock() - start)
		if opened then
			d.said("panel: opened in %d frames, the mods read in %d ms, the longest frame under %d ms", P.frames,
				math.floor(opening.spent_reading() * 1000 + 0.5), math.floor(P.longest * 1000 + 0.5) + 1)
		end
	end

	local function open_frame(pc, k)
		if not Frame.alive() then return P.close(pc, "the game took it off the screen") end
		local waiting = capture.waiting()
		if k ~= nil and k.toggle % 2 == 1 and not waiting then return P.close(pc, "the panel key") end
		local now = os.clock()
		Input.keep(pc, d.report, d.problem)
		local why, c = controls.frame(pc, now, waiting)
		if why then return P.close(pc, why) end
		local list = listing.list(nav.mod)
		local R = Pointer.read(#nav.rows(), #list, k ~= nil or c ~= nil or controls.side() ~= nil)
		Usage.frame(k, R)
		Hints.frame(k, R)
		why = commands.frame(k, c, R, now)
		if why then return P.close(pc, why) end
		d.edits.step(now)
		why = freeze.frame(pc, head.freeze())
		if why then return P.close(pc, why) end
		local F, rows_to, list_to = Frame.get(), nav.take_scroll()
		if rows_to ~= nil then Scroll.to(F.rows, rows_to, #nav.rows(), L.ROW_HEIGHT) end
		if list_to ~= nil then Scroll.to(F.list, list_to, #listing.list(nav.mod), L.ENTRY_HEIGHT) end
		paint(R)
		View.close_lit(R.on_close)
		if not P.told and View.refusals() > 0 then
			P.told = true
			d.problem("panel: the game refused a change to the panel; it is tried again at each frame")
		end
	end

	-- At each frame while the panel opens or is open, a key was pressed, or the controller's button is read: k, the
	-- presses (Keys.take()), or nil.
	function P.frame(pc, k)
		if P.state == "closed" then
			local by_key = k ~= nil and k.toggle % 2 == 1
			if by_key or controls.pressed(pc) or controls.combo(pc) then
				local other = claim.taken()
				if other then return refuse(other, false) end
				P.state, P.ready, P.taken, P.frames, P.longest = "opening", false, false, 0, 0
				P.by_pad = not by_key
				opening.begin()
			end
			return
		end
		if not d.settings().enabled then return P.close(pc, "Mod Panel was turned off in Mods Menu") end
		if P.state == "opening" then
			-- Escape alone stops an opening: the first of a session lasted over a second in game, and a second press of
			-- the key or the button, made because nothing showed yet, stopped it (trial of 0.2.1, D79).
			if k ~= nil and k.escape > 0 then return P.close(pc, "Escape") end
			return opening_frame(pc)
		end
		open_frame(pc, k)
	end

	-- Ten times a second while the panel opens (once the player was seen in play) or is open; once a second while it
	-- is open, Mod Panel's input context looked for and its claim written again (D98).
	function P.tick(pc)
		if P.state == "closed" or opening.gi == nil then return end
		local playing, pawn = Game.in_play(pc, freeze.holds())
		if not playing then return P.close(pc, pawn) end
		if U.address(pawn) ~= opening.pawn then return P.close(pc, "the character changed") end
		if P.state ~= "open" then return end
		language.speak(opening.gi)
		screen.key_now(d.key_label(screen.lang))
		P.ticks = P.ticks + 1
		if P.ticks % d.ticks_a_second ~= 0 then return end
		claim.hold()
		local why = controls.second(pc, opening.gi)
		if why then P.close(pc, why) end
	end

	function P.busy() return P.state ~= "closed" end
	-- The status line's slot for this frame's time (mod_panel_status.lua).
	function P.slot() return P.state end
	function P.openings() return P.opened end

	return P
end

return M
