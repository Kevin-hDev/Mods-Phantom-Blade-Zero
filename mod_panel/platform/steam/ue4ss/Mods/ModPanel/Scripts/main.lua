-- Mod Panel for Phantom Blade Zero: one panel in the game for the settings of every UE4SS mod, read from the files
-- Mods Menu reads (<ModName>.modsmenu.json and <ModName>.config.json), opened in play with the panel key or the
-- controller's button (mod_panel_panel.lua); what the panel keeps by itself is in ModPanel.state.json
-- (mod_panel_state.lua). Everything runs from the player controller's tick, inside UE4SS's lock
-- (mod_panel_driver.lua); a key's bind only counts its presses (mod_panel_keys.lua). With the panel closed and no key
-- pressed, a frame asks the game only whether the controller's button was pressed (mod_panel_pad.lua, D67) and, when
-- the player chose a combination, whether its two buttons are held (D136); in the seconds after a load, it also
-- prepares the panel, hidden, 3 ms a frame at most, until done (mod_panel_prepare.lua, D180); once a second, it reads
-- Mod Panel's own signal file (mod_panel_watch.lua) and tries again a mod's signal that could not be written
-- (mod_panel_signal.lua).
-- The JavaScript mods Mods Menu runs come from the list Mod Panel's script link writes (mod_panel_js_mods.lua, D173).

local U = require("mod_panel_unreal")
local Status = require("mod_panel_status")
local Driver = require("mod_panel_driver")
local Keys = require("mod_panel_keys")
local KeyNames = require("mod_panel_key_names")
local Files = require("mod_panel_files")
local Folders = require("mod_panel_folders")
local Catalog = require("mod_panel_catalog")
local Settings = require("mod_panel_settings")
local Watch = require("mod_panel_watch")
local Signal = require("mod_panel_signal")
local Edits = require("mod_panel_edits")
local Panel = require("mod_panel_panel")
local Pad = require("mod_panel_pad")
local PadNames = require("mod_panel_pad_names")
local State = require("mod_panel_state")
local Langs = require("mod_panel_langs")
local JsMods = require("mod_panel_js_mods")

local VERSION = "1.0.2"
local TICK_SECONDS = 0.1
local EARLY = 0.001               -- a frame this close to the next tick reaches it: no tick lost to the clock's steps
local TICKS_A_SECOND = math.floor(1 / TICK_SECONDS + 0.5)
local STATUS_SECONDS = 300        -- between two status lines
local DARKEST = 100               -- the backdrop's most, in %, when Mod Panel's descriptor gives PanelOpacity no bound

-- key: the panel key whose bind was last asked for. status_due: a status line to write at the end of the frame.
-- new_controller: a player controller was made (a load) and an open panel has not closed for it yet. get_failed: the
-- controller could not be read from the hook once. opened: the openings the last status line counted. combo_said:
-- the combination that cannot be read was said.
local S = { key = nil, next_tick = 0, ticks = 0, seconds = 0, status_due = false, settings = nil, catalog = nil,
	watch = nil, signal = nil, panel = nil, new_controller = false, get_failed = false, opened = 0,
	combo_said = false }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[ModPanel] %s\n", ok and msg or tostring(fmt)))
end

local T = Status.new(log)

local function note_catalog(line)
	T.bounded("catalog", "%s", line)
end

local function note_settings(line)
	log("settings: %s", line)
end

local function second()
	S.seconds = S.seconds + 1
	S.watch.second()
	S.signal.second()
	if S.seconds % STATUS_SECONDS == 0 then S.status_due = true end
end

local function tick()
	S.ticks = S.ticks + 1
	if S.ticks % TICKS_A_SECOND == 0 then second() end
end

local function get(param) return param:get() end

-- This frame's player controller, from the hook's parameter, or nil; a failure to read it is said once.
local function controller(param)
	local ok, pc = pcall(get, param)
	if not ok and not S.get_failed then
		S.get_failed = true
		log("the player controller cannot be read from the hook (%s): frames without it are skipped", tostring(pc))
	end
	return ok and U.is_valid(pc) and pc or nil
end

-- The controller's button that opens and closes the panel (PadButton), or nil while none is read: None, Mod Panel
-- off, or the engine's function not the one this version knows.
local function pad_button()
	local button = S.settings.pad_button
	if not S.settings.enabled or button == nil or button == PadNames.NONE or not Pad.usable() then return nil end
	return button
end

-- The controller's combination ({ first, second }), or nil while none is read: none chosen, Mod Panel off, or the
-- engine's function not the one this version knows (D124, D136).
local function pad_combo()
	local pair = S.settings.combo
	if not S.settings.enabled or pair == nil then return nil end
	if Pad.usable_down() then return pair end
	if not S.combo_said then
		S.combo_said = true
		log("the controller's combination cannot be read: the engine's function is not the one this version knows")
	end
	return nil
end

local function frame_work(param)
	-- Asked here, under UE4SS's lock, never at start: a bind's Lua runs on UE4SS's own thread. Before the presses are
	-- taken, so a key changed in the settings never counts the old one's.
	local wanted = S.settings.enabled and S.settings.panel_key or KeyNames.NONE
	if S.key ~= wanted then
		S.key = wanted
		Keys.want(S.key, log)
	end
	if S.key == KeyNames.NONE and (pad_button() ~= nil or pad_combo() ~= nil) then Keys.share(log) end
	local presses = Keys.take()
	local now = os.clock()
	local due = now + EARLY >= S.next_tick
	if due then
		-- On the clock's tenths rather than a tenth after this frame: ten ticks a second whatever the frame rate.
		-- After a long frame (a load), a tenth from now: no ticks pile up.
		S.next_tick = S.next_tick + TICK_SECONDS
		if S.next_tick <= now then S.next_tick = now + TICK_SECONDS end
	end
	if S.new_controller and not S.panel.busy() then S.new_controller = false end
	if presses ~= nil or S.panel.busy() or S.panel.wants() or pad_button() ~= nil or pad_combo() ~= nil then
		local pc = controller(param)
		if pc ~= nil then
			if S.new_controller then
				S.new_controller = false
				S.panel.close(pc, "a load")
			end
			-- Apart (D102): an error repeated in the panel's frame still lets its tick close it at a cutscene, the
			-- claim be written (D98) and the status line come.
			T.guard(S.panel.frame, pc, presses)
			if due then T.guard(S.panel.tick, pc) end
		end
	end
	if due then T.guard(tick) end
end

local function frame(param)
	-- Under the slot of the panel's state as the frame begins: closed, opening or open (mod_panel_status.lua).
	T.run(S.panel.slot(), frame_work, param)
	-- Outside the frame's work: the status line is written even while an error repeats there, and counts this frame.
	if S.status_due then
		S.status_due = false
		local listed, left_out = S.catalog.counts()
		local opened = S.panel.openings()
		T.line(STATUS_SECONDS // 60, { mods = listed, left_out = left_out, openings = opened - S.opened })
		S.opened = opened
	end
end

local function start()
	local mod_dir, mods_dir = Folders.paths(debug.getinfo(1, "S").source)
	if mods_dir == nil then
		log("the mod's folder cannot be told from its script's path: the mod stays off")
		return false
	end
	local own = mod_dir:match("([^/\\]+)$")
	local config_path = mod_dir .. "/" .. own .. ".config.json"
	local state_path = mod_dir .. "/" .. own .. ".state.json"
	Files.recover(config_path, note_settings)
	local function note_state(line) T.bounded("state", "state: %s", line) end
	Files.recover(state_path, note_state)
	local state = State.new(state_path, note_state)
	local began = os.clock()
	local names = Folders.started(mods_dir, note_catalog)
	for _, name in ipairs(names) do
		if name ~= own then
			Files.recover_other(mods_dir .. "/" .. name .. "/" .. name .. ".config.json",
				function(line) note_catalog(name .. ": " .. line) end)
		end
	end
	Langs.check(function(line) log("%s", line) end)
	S.catalog = Catalog.new({ mods_dir = mods_dir, names = names, own = own, note = note_catalog,
		js_list = mod_dir .. "/" .. JsMods.FILE })
	S.catalog.start()
	log("%d mods run by UE4SS, found and their descriptors read in %d ms", #names,
		math.floor((os.clock() - began) * 1000 + 0.5))
	local rows = S.catalog.rows(own)
	if rows == nil then
		log("%s.modsmenu.json is missing or broken: the mod stays off", own)
		return false
	end
	Settings.ensure(config_path, rows, note_settings)
	local function read_settings()
		S.settings = Settings.from(S.catalog.refresh_mod(own), rows)
		log("settings: %s", Settings.describe(S.settings))
	end
	read_settings()
	S.watch = Watch.new(Signal.events_path(mods_dir, own), function()
		log("settings changed in the Mods Menu")
		read_settings()
	end)
	local darkest = DARKEST
	for _, row in ipairs(rows) do
		if row.key == "PanelOpacity" and row.max ~= nil then darkest = row.max end
	end
	S.signal = Signal.new(mods_dir, function(line) T.bounded("signal", "%s", line) end)
	local edits = Edits.new({ catalog = S.catalog, mods_dir = mods_dir, own = own, signal = S.signal,
		report = function(fmt, ...) T.bounded("edits", fmt, ...) end,
		note = function(fmt, ...) T.bounded("edits problem", fmt, ...) end,
		-- Mod Panel's own page changed: its settings read again, and its key bound at the next frame.
		saved = function(name) if name == own then read_settings() end end })
	S.panel = Panel.new({ catalog = S.catalog, edits = edits, state = state, own = own, max = darkest,
		ticks_a_second = TICKS_A_SECOND,
		settings = function() return S.settings end,
		key_label = function(lang) return S.key ~= KeyNames.NONE and KeyNames.label(S.key, lang) or nil end,
		pad_button = pad_button,
		pad_combo = pad_combo,
		report = function(fmt, ...) T.bounded("panel", fmt, ...) end,
		said = function(fmt, ...) T.bounded("openings", fmt, ...) end,
		problem = function(fmt, ...) T.bounded("panel problem", fmt, ...) end })
	return true
end

log("Mod Panel %s loaded", VERSION)
-- Last: once the hook or the notification is set, the mod runs on the game thread, and this file must be done by then.
if start() then Driver.start(frame, function() S.new_controller = true; S.panel.loaded() end, log) end
