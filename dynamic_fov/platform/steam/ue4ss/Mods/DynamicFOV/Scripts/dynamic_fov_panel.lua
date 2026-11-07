-- Dynamic FOV's settings panel in play (1.0.2): opened and closed with the panel key (F8 unless changed in Mods Menu),
-- closed too by Escape and by its Close. A frameless strip at the right over a darkened fade, built from the game's own
-- menu pieces (dynamic_fov_panel_view.lua); while it is open the inputs are the panel's (dynamic_fov_panel_input.lua).
-- It opens only in play: a camera the mod manages, no cutscene, the game not paused; it closes when that ends. The
-- game goes on while it is open: the panel is there to change the settings while playing. A change applies to the
-- view at once, and a field of view's row shows its value in the view while the pointer is on it
-- (dynamic_fov_panel_screen.lua); the changes are written when the panel closes (dynamic_fov_panel_edits.lua).

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

local M = {}

local NOT_IN_PLAY = "not in play (a cutscene, a dialogue, a special move or another view the mod leaves alone)"

-- d: log(fmt, ...), report(fmt, ...), problem(fmt, ...) and saving(fmt, ...) (the panel's lines, its failures and
-- what its saves say, each bounded on its own), warn(message) (settings lines), settings_path, descriptor_path, settings() (the settings in use), apply(s)
-- (settings changed in the panel), preview(fov or nil), camera() (the player's camera, or nil).
function M.new(d)
	-- lines: the panel's headings and rows, read once, and screen what it shows of them. undo: the settings before
	-- Restore defaults, while its button offers to undo it. refused: the last reason given for not opening.
	-- told: whether the game's refusals of the panel's looks were said.
	local P = { open = false, lines = nil, screen = nil, failed = nil, undo = nil, refused = nil, told = false }
	local E = Edits.new()

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
		local gi = Game.instance()
		if gi == nil then return refuse("the game instance is not found", true) end
		if not View.alive() then
			local start = os.clock()
			local built, info = View.build(gi, P.lines, d.report)
			if not built then return refuse("the panel could not be built (" .. info .. ")", true) end
			-- About 15 ms at a session's first opening, 6 ms after a load (5 November 2026): once per load, on a key
			-- press, so it is not spread over frames.
			d.report("panel: built in %d ms", math.floor((os.clock() - start) * 1000 + 0.5))
			if #info > 0 then d.problem("panel: the game's %s not found, plain ones used", table.concat(info, ", ")) end
		end
		P.screen.start(Game.language(gi), Hotkey.label(Hotkey.current()))
		local shown, err = View.show(true)
		if not shown then return refuse("the panel could not be shown (" .. tostring(err) .. ")", true) end
		P.open, P.undo, P.refused = true, nil, nil
		E.start(d.settings())
		Input.take(pc, d.problem)
		d.report("panel: opened")
	end

	function P.close(pc, why)
		if not P.open then return end
		P.open, P.undo = false, nil
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

	-- The settings after what the pointer did since the last frame; a row that cannot change keeps its value.
	-- Restore defaults, clicked again before any other change, gives back the settings it replaced: an undo rather
	-- than a question, and nothing is lost to a click gone astray.
	local function changes(s, input)
		local new = s
		for i, line in ipairs(P.lines) do
			local v, dir = input.moved[i], input.click[i]
			if v ~= nil then
				v = Rows.on_step(line, v)
				if v ~= Rows.value(line, new) and Rows.waits_for(line, new) == nil then
					new = Rows.with(new, line, v, d.warn)
				end
			elseif dir ~= nil and Rows.waits_for(line, new) == nil then
				new = Rows.with(new, line, Rows.next(line, new, dir), d.warn)
			end
		end
		if new ~= s then P.undo = nil end
		if input.restore then
			if P.undo ~= nil then new, P.undo = P.undo, nil else P.undo, new = new, Rows.defaults(new, d.warn) end
		end
		return new
	end

	-- At each frame while the panel is open or a key was pressed: toggles, the panel key's presses, escapes, Escape's.
	function P.frame(pc, toggles, escapes)
		if P.open and escapes > 0 then
			P.close(pc, "Escape")
		elseif toggles % 2 == 1 then
			if P.open then P.close(pc, "the panel key") else open(pc) end
		end
		if not P.open then return end
		if not View.alive() then return P.close(pc, "the game took it off the screen") end
		Input.keep(pc, d.report, d.problem)
		local s = d.settings()
		local input = View.read()
		local new = changes(s, input)
		if new ~= s then d.apply(new) end
		P.screen.frame(new, input.over, P.undo ~= nil)
		if not P.told and View.refusals() > 0 then
			P.told = true
			d.problem("panel: the game refused a change to the panel; it is tried again at each frame (refusals so "
				.. "far: %d)", View.refusals())
		end
		if input.close then P.close(pc, "Close") end
	end

	-- Ten times a second while it is open: it closes when play stops.
	function P.tick(pc)
		if not P.open then return end
		local cam = d.camera()
		if cam == nil or not Layer.playable(cam, d.log) then
			P.close(pc, "the game left play (a cutscene, a dialogue, a special move or another view)")
		elseif Game.paused(pc) == true then
			P.close(pc, "the game paused")
		end
	end

	-- Settings s just read from the file, with the panel's changes kept on top.
	function P.on_read(s, read)
		if P.open then P.undo = nil end
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
