-- Dynamic FOV's settings panel in play (1.0.2): opened and closed with the panel key (F8 unless changed in Mods Menu),
-- closed too by Escape, by its Close and, since 1.0.5, by the controller's Circle. A frameless strip at the right over
-- a darkened fade, built from the game's own menu pieces (dynamic_fov_panel_build.lua); while it is open the inputs
-- are the panel's (dynamic_fov_panel_input.lua), and the controller works in it (dynamic_fov_panel_controls.lua) with
-- the keys and the mouse (dynamic_fov_panel_changes.lua). It opens only in play: a camera the mod manages, no cutscene,
-- the game not paused, no other mod's panel open (dynamic_fov_panel_claim.lua); it closes when that ends. The game goes
-- on while it is open: the panel is there to change the settings while playing. A change applies to the view at once,
-- and a field of view's row shows its value in the view while it is chosen (dynamic_fov_panel_screen.lua); the
-- changes are written when the panel closes (dynamic_fov_panel_edits.lua).

local Settings = require("dynamic_fov_settings")
local Hotkey = require("dynamic_fov_hotkey")
local Layer = require("dynamic_fov_layer")
local PanelCalls = require("dynamic_fov_panel_calls")
local Texts = require("dynamic_fov_panel_texts")
local Rows = require("dynamic_fov_panel_rows")
local Edits = require("dynamic_fov_panel_edits")
local Screen = require("dynamic_fov_panel_screen")
local Game = require("dynamic_fov_panel_game")
local Input = require("dynamic_fov_panel_input")
local View = require("dynamic_fov_panel_view")
local Changes = require("dynamic_fov_panel_changes")
local Controls = require("dynamic_fov_panel_controls")
local Claim = require("dynamic_fov_panel_claim")

local M = {}

local NOT_IN_PLAY = "not in play (a cutscene, a dialogue, a special move or another view the mod leaves alone)"
local OWN = "DynamicFOV"          -- the mod's folder: its name for the other mods' panels

-- d: log(fmt, ...), report(fmt, ...), problem(fmt, ...) and saving(fmt, ...) (the panel's lines, its failures and
-- what its saves say, each bounded on its own), warn(message) (settings lines), settings_path, descriptor_path,
-- settings() (the settings in use), apply(s) (settings changed in the panel), preview(fov or nil), camera() (the
-- player's camera, or nil), ticks_a_second (P.tick's calls in a second).
function M.new(d)
	-- lines: the panel's headings and rows, read once, screen what it shows of them, changes what the devices do to
	-- them. refused: the last reason given for not opening. told: whether the game's refusals of the panel's looks were
	-- said. gi: the game instance of the opening; ticks: ticks since it, for what is done once a second.
	local P = { open = false, lines = nil, screen = nil, changes = nil, failed = nil, refused = nil, told = false,
		gi = nil, ticks = 0 }
	local E = Edits.new()
	local controls = Controls.new(d)
	local claim = Claim.new(OWN, d.report)

	-- The engine's functions checked and the descriptor read, once.
	local function ready()
		if P.lines ~= nil then return true end
		if P.failed ~= nil then return false, P.failed end
		local ok, why = PanelCalls.check()
		if not ok then
			P.failed = why
			return false, why
		end
		local D, problem = Texts.load(d.descriptor_path)
		if D == nil then return false, string.format("%s %s", d.descriptor_path:match("([^/\\]+)$"), problem) end
		P.lines = Rows.build(D)
		P.screen = Screen.new(P.lines, D.title, d.preview)
		P.changes = Changes.new(P.lines, d.warn)
		d.report("panel: ready (the engine's functions checked, the menu's file read)")
		return true
	end

	-- Each reason once until another comes: a key pressed again and again in a menu fills no log. A failure (failed
	-- set) goes with the panel's failures, bounded apart from its routine lines, so it is still written late in a game.
	local function refuse(why, failed)
		if why == P.refused then return end
		P.refused = why
		local say = failed and d.problem or d.report
		say("panel: not opened, %s", why)
	end

	-- What a save of the panel's changes says has its own bound: a file that stays unwritable fills no log, and leaves
	-- room for the panel's other failures.
	local function told(message)
		d.saving("panel: %s", message)
	end

	local function build(gi)
		local start = os.clock()
		local built, info, absent = View.build(gi, P.lines, d.report)
		if not built then return false, info end
		-- 66 to 89 ms at a session's first opening, 5 to 13 ms after a load (logs of 5 to 7 November 2026): once per
		-- load, at the press of the panel's key, a short freeze the player asks for; spread over frames, the panel
		-- would show half built (audit of 1.0.5).
		d.report("panel: built in %d ms", math.floor((os.clock() - start) * 1000 + 0.5))
		if #info > 0 then d.problem("panel: the game's %s not found, plain ones used", table.concat(info, ", ")) end
		if #absent > 0 then
			d.report("panel: controller icons not in memory, the button's name in their place: %s",
				table.concat(absent, ", "))
		end
		return true
	end

	-- One reading of the other mods' panels: the opening fits in one frame, and while it runs under UE4SS's lock no
	-- other mod's Lua can open its panel.
	local function open(pc)
		if d.settings_path == nil then return refuse("the mod's folder is unknown", true) end
		local ok, why = ready()
		if not ok then return refuse(why, true) end
		local cam = d.camera()
		if cam == nil then return refuse("no player camera yet") end
		local paused = Game.paused(pc)
		if paused ~= false then
			return refuse(paused and "the game is paused (one of its menus is open)"
				or "the game cannot say whether it is paused", paused ~= true)
		end
		local playable, reason = Layer.playable(cam, d.log)
		if not playable then return refuse(reason or NOT_IN_PLAY, reason ~= nil) end
		local other = claim.taken()
		if other then return refuse(other) end
		local gi = Game.instance()
		if gi == nil then return refuse("the game instance is not found", true) end
		if not View.alive() then
			local built, info = build(gi)
			if not built then return refuse("the panel could not be built (" .. info .. ")", true) end
		end
		P.changes.start()
		P.screen.start(Game.language(gi), Hotkey.label(Hotkey.current()))
		local shown, err = View.show(true)
		if not shown then return refuse("the panel could not be shown (" .. tostring(err) .. ")", true) end
		-- The input context last, P.open right after it: an opening that failed once the game's keys were taken would
		-- leave them taken, since only an open panel's closing gives them back (audit of 1.0.5).
		local both = controls.take(pc, gi)
		P.open, P.refused, P.gi, P.ticks = true, nil, gi, 0
		controls.start(pc)
		claim.hold()
		E.start(d.settings())
		Input.take(pc, d.problem, both)
		d.report("panel: opened")
	end

	function P.close(pc, why)
		if not P.open then return end
		P.open = false
		controls.off()
		claim.release()
		Input.give_back(pc, d.problem)
		if View.alive() then
			local hidden, err = View.show(false)
			if not hidden then d.problem("panel: could not be hidden (%s)", tostring(err)) end
		end
		P.screen.stop()
		d.report("panel: closed (%s)", why)
		local saved = E.save(d.settings_path, d.settings(), told)
		if saved == nil then return end
		d.apply(saved)
		d.report("panel: saved, %s", Settings.describe(saved))
	end

	-- At each frame while the panel is open or a key was pressed: toggles, the panel key's presses, escapes, Escape's,
	-- moves, the open panel's keys (dynamic_fov_hotkey.lua, nil when none).
	function P.frame(pc, toggles, escapes, moves)
		if P.open and escapes > 0 then
			P.close(pc, "Escape")
		elseif toggles % 2 == 1 then
			if P.open then P.close(pc, "the panel key") else open(pc) end
		end
		if not P.open then return end
		if not View.alive() then return P.close(pc, "the game took it off the screen") end
		Input.keep(pc, d.report, d.problem)
		local now = os.clock()
		local c, by_pad = controls.frame(pc, now)
		if c ~= nil and c.close > 0 then return P.close(pc, "the controller's Circle or B") end
		local s = d.settings()
		local input = View.read()
		local new = P.changes.frame(s, input, moves, c, controls.side(), by_pad, now)
		if new ~= s then d.apply(new) end
		View.scroll_to(P.changes.take_scroll(), #P.lines)
		P.screen.frame(new, P.changes.chosen_row(), P.changes.undo_offered(),
			P.changes.by_pad() and controls.brand_now() or nil)
		if not P.told and View.refusals() > 0 then
			P.told = true
			d.problem("panel: the game refused a change to the panel; it is tried again at each frame (refusals so "
				.. "far: %d)", View.refusals())
		end
		if input.close then P.close(pc, "Close") end
	end

	-- Ten times a second while it is open: it closes when play stops; once a second its claim is written again and its
	-- input context looked for.
	function P.tick(pc)
		if not P.open then return end
		local cam = d.camera()
		if cam == nil or not Layer.playable(cam, d.log) then
			return P.close(pc, "the game left play (a cutscene, a dialogue, a special move or another view)")
		elseif Game.paused(pc) == true then
			return P.close(pc, "the game paused")
		end
		P.ticks = P.ticks + 1
		if P.ticks % d.ticks_a_second ~= 0 then return end
		claim.hold()
		local why = controls.second(pc, P.gi)
		if why then P.close(pc, why) end
	end

	-- Settings s just read from the file, with the panel's changes kept on top.
	function P.on_read(s, read)
		if P.open then P.changes.forget_undo() end
		return E.on_read(s, d.settings(), P.open, read)
	end

	-- Once a second, the panel closed: changes a save could not write are tried again, a few times.
	function P.retry()
		if P.open or not E.retry_due() then return end
		local saved = E.retry(d.settings_path, told)
		if saved == nil then return end
		d.apply(saved)
		d.report("panel: saved at a new try, %s", Settings.describe(saved))
	end

	function P.is_open()
		return P.open
	end

	return P
end

return M
