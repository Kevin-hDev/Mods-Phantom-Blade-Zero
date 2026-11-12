-- Dynamic FOV for Phantom Blade Zero: a field of view for each situation (normal view, sprint, crouch, enemy locked
-- on), from a preset or the player's own values, the time the view takes to change between them, and where the view
-- sits (distance, height, side). Settings in DynamicFOV.config.json in the mod's folder (dynamic_fov_settings_file.lua),
-- changed in Mods Menu (Nexus 149), by hand, or in the mod's own panel, opened in play with the panel key, F8 unless
-- changed (dynamic_fov_panel.lua); read at each new pawn, and within a second of a change saved in the menu.
--
-- The field of view goes through the camera's modes (dynamic_fov_camera.lua), looked at once a second. The view's
-- place goes through the camera's layer (dynamic_fov_layer.lua), which must leave a dialogue's view as it starts:
-- while a place is set, the camera's mode is read at each tick, ten times a second; with the three at 0 and the panel
-- closed, a tick asks nothing of the game. Everything runs from the player controller's tick, inside UE4SS's lock
-- (dynamic_fov_driver.lua).
-- The colours and the clean image go through the image settings of the camera seen through (dynamic_fov_image.lua),
-- looked at once a second, at the next tick after a change, and for a scene's camera in the frame the game makes
-- it (1.0.8); the comfort options through four fields of the camera's modes (dynamic_fov_comfort.lua), as often.
-- When the settings are read: dynamic_fov_watch.lua.
-- During an execution, given or taken, the camera is the game's, place and field of view (1.0.7): the game films most
-- in the combat view in progress, where the place pushed the view into the enemy (dynamic_fov_executions.lua).

local U = require("dynamic_fov_unreal")
local Settings = require("dynamic_fov_settings")
local SettingsFile = require("dynamic_fov_settings_file")
local Menu = require("dynamic_fov_menu")
local Watch = require("dynamic_fov_watch")
local Camera = require("dynamic_fov_camera")
local Layer = require("dynamic_fov_layer")
local Status = require("dynamic_fov_status")
local Driver = require("dynamic_fov_driver")
local Hotkey = require("dynamic_fov_hotkey")
local Panel = require("dynamic_fov_panel")
local Image = require("dynamic_fov_image")
local Comfort = require("dynamic_fov_comfort")
local ImageLines = require("dynamic_fov_image_lines")
local Executions = require("dynamic_fov_executions")

local VERSION = "1.0.8"
local TICK_SECONDS = 0.1          -- a tick: the view's place
-- Seconds the place takes to go as an execution starts: 0.2 is too abrupt for the eyes (Kevin, 10 November 2026).
local EXECUTION_BLEND = 0.4
local EARLY = 0.001               -- a frame this close to the next tick reaches it: no tick lost to the clock's steps
local LOOK_TICKS = 10             -- ticks between two looks (settings, menu, modes): once a second
local STATUS_EVERY = 600          -- looks between two status lines
-- Frames in a row without a valid player controller before it is said: a load has a few.
local NO_CONTROLLER_FRAMES = 600
local MOD_DIR = SettingsFile.mod_dir(debug.getinfo(1, "S").source)
local SETTINGS_PATH = MOD_DIR and SettingsFile.file_in(MOD_DIR)
local EVENTS_PATH = MOD_DIR and Menu.events_file(MOD_DIR)
-- Mods Menu reads <ModName>.modsmenu.json, ModName being the mod's folder name; the panel reads the same file.
local DESCRIPTOR_PATH = MOD_DIR and MOD_DIR .. "/" .. MOD_DIR:match("([^/\\]+)$") .. ".modsmenu.json"

-- new_controller: a player controller was made (a load) since the last tick. key: the panel key whose bind was last
-- asked for. no_controller: frames in a row whose controller could not be read; get_failed: that reading failed once.
-- execution: the player is in one.
local S = { controller = nil, new_controller = true, next_tick = 0, ticks = 0, looks = 0, settings = nil,
	position = nil, key = nil, no_controller = 0, get_failed = false, execution = false }

local function log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(string.format("[DynamicFOV] %s\n", ok and msg or tostring(fmt)))
end

local T = Status.new(log)

local function warn(message)
	log("settings: %s", message)
end

local watch, panel
-- A new pawn: the panel closes first, so its changes are in the file the watch then reads.
local camera = Camera.new(T, log, function()
	T.run("panel", panel.close, S.controller, "the character changed")
	watch.new_pawn()
end)

-- The settings in use, and the view's place; no place while the mod is off, so the game's view comes back. at_once:
-- the camera's modes take them at the next tick (a change made in the panel), else at the next look.
local function use(s, at_once)
	S.settings, S.position = s, nil
	if s.enabled and (s.distance ~= 0 or s.height ~= 0 or s.side ~= 0) then
		S.position = { distance = s.distance, height = s.height, side = s.side }
	end
	camera.use(s, at_once)
	-- Nothing an execution would give back to the game, nothing watched: the place at 0, the game's fields of view (the
	-- transition time paces only the field of view, then the same in every view).
	Executions.set_on(S.position ~= nil or (s.enabled and not Settings.game_fovs(s)))
	Image.want(s.enabled and Settings.colour_factor(s) or nil, s.enabled and s.clean_image)
	Comfort.want(s)
end
use(Settings.resolve({}, function() end))

-- The panel keeps its changes on top of what is read: those made while it is open, and those not saved yet.
watch = Watch.new(SETTINGS_PATH, EVENTS_PATH, function(s, read)
	local used = panel.on_read(s, read)
	use(used)
	return used
end, log, warn)

panel = Panel.new({ log = log, warn = warn, report = function(fmt, ...) T.bounded("panel", fmt, ...) end,
	problem = function(fmt, ...) T.bounded("panel problem", fmt, ...) end,
	saving = function(fmt, ...) T.bounded("panel save", fmt, ...) end, settings_path = SETTINGS_PATH,
	ticks_a_second = LOOK_TICKS,
	descriptor_path = DESCRIPTOR_PATH, settings = function() return S.settings end,
	apply = function(s) use(s, true) end, preview = camera.show, camera = camera.camera })

local look_image, born_image = ImageLines.new(T, function() return panel.is_open() end,
	function() return S.controller end)

-- The camera found by the last look; a toggle in the panel is one write, so its lines are said even while it is open.
local function look_comfort()
	local writes, failed = Comfort.look(camera.camera(), function(fmt, ...) T.bounded("comfort", fmt, ...) end,
		function(fmt, ...) T.bounded("comfort problem", fmt, ...) end)
	T.comfort_writes, T.comfort_failed = T.comfort_writes + writes, T.comfort_failed + failed
end

local function look()
	S.looks = S.looks + 1
	watch.check()
	panel.retry()
	-- Once a second, the camera's mode is read again even at the same address (a mode the game would load again).
	Layer.recheck()
	camera.look(S.controller)
	look_image()
	look_comfort()
end

-- Not while the panel is open: each step of a slider moves the view, and would use up the lines in a minute.
local function report_position(fmt, ...)
	if panel.is_open() then return end
	T.bounded("position", "camera position: " .. fmt, ...)
end

-- The fields of view go to the game's as an execution starts, and back to the settings' as it ends; the mod off, no
-- execution is followed, and the settings' are none.
local function executions(pc)
	local now = Executions.tick(pc, os.clock(), T)
	if now == S.execution then return end
	S.execution = now
	camera.pause(now)
end

-- The camera found by the last look: a new pawn's camera takes the place at most a second after it arrives. No place
-- during an execution: it goes in EXECUTION_BLEND, and comes back in the layer's own time.
local function place()
	local want = not S.execution and S.position or nil
	local result = Layer.frame(camera.camera(), want, log, report_position, S.execution and EXECUTION_BLEND or nil)
	if result == "set" then T.sets = T.sets + 1 elseif result == "failed" then T.set_failed = T.set_failed + 1 end
end

local function tick(pc)
	S.controller, S.ticks = pc, S.ticks + 1
	if S.new_controller then
		S.new_controller = false
		camera.new_controller()
		Executions.reset()
		T.run("panel", panel.close, pc, "a load")
	end
	if panel.is_open() then T.run("panel", panel.tick, pc) end
	-- First: the fields of view an execution changes are written within this tick.
	T.run("executions", executions, pc)
	if S.ticks % LOOK_TICKS == 0 then
		T.run("looks", look)
		-- Outside look: the status line is written even while an error repeats there.
		if S.looks % STATUS_EVERY == 0 then
			local modes, managed = camera.counts()
			T.line(modes, managed, STATUS_EVERY * LOOK_TICKS * TICK_SECONDS // 60, Executions.seen())
		end
	end
	if camera.pending() then T.run("panel", camera.tick) end
	if Image.pending() then T.run("looks", look_image) end
	-- Before the first camera, the next look takes the change: no look at each tick for nothing.
	if Comfort.pending() and camera.camera() ~= nil then T.run("looks", look_comfort) end
	if S.position ~= nil or not Layer.idle() then T.run("ticks", place) end
end

local function get(param) return param:get() end

-- Every frame: the panel's keys and, while it is open, its frame; a tick every TICK_SECONDS. Without a key pressed,
-- an open panel, a camera the game just made or a tick due, a frame reads nothing from the game.
local function frame_work(param)
	-- Asked here, under UE4SS's lock, never at start: a bind's Lua runs on UE4SS's own thread. Before the presses are
	-- taken, so a key changed in the settings never counts the old one's.
	if S.key ~= S.settings.panel_key then
		S.key = S.settings.panel_key
		Hotkey.want(S.key, log)
	end
	local toggles, escapes, moves = Hotkey.take()
	local now = os.clock()
	local due = now + EARLY >= S.next_tick
	local busy = toggles > 0 or escapes > 0 or panel.is_open()
	-- First, and whatever the controller: a scene's shot is seen through its camera within this frame.
	if Image.waiting() then T.run("cameras", born_image) end
	if not (due or busy) then return end
	local ok, pc = pcall(get, param)
	if not ok and not S.get_failed then
		S.get_failed = true
		log("the player controller cannot be read from the hook (%s): frames without it are skipped", tostring(pc))
	end
	if not ok or not U.is_valid(pc) then
		S.no_controller = S.no_controller + 1
		if S.no_controller == NO_CONTROLLER_FRAMES then
			log("no valid player controller for %d frames in a row: the mod waits", NO_CONTROLLER_FRAMES)
		end
		return
	end
	S.no_controller = 0
	if busy then T.run("panel", panel.frame, pc, toggles, escapes, moves) end
	if due then
		-- On the clock's tenths rather than a tenth after this frame: ten ticks a second whatever the frame rate. After
		-- a long frame (a load), a tenth from now: no ticks pile up.
		S.next_tick = S.next_tick + TICK_SECONDS
		if S.next_tick <= now then S.next_tick = now + TICK_SECONDS end
		tick(pc)
	end
end

local function frame(param)
	T.run("frames", frame_work, param)
end

log("Dynamic FOV %s loaded", VERSION)
if SETTINGS_PATH ~= nil then
	SettingsFile.recover(SETTINGS_PATH, warn)
	SettingsFile.ensure_file(SETTINGS_PATH, warn)
end

-- Last: once the hook or the notifications are set, the mod runs on the game thread, and this file must be done by
-- then. The lines below are only written when something failed.
Executions.watch(log)
Image.watch(log)
Driver.start(frame, function() S.new_controller = true end, log)
