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
-- looked at once a second, and at the next tick after a change.
-- When the settings are read: dynamic_fov_watch.lua.

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

local VERSION = "1.0.4"
local TICK_SECONDS = 0.1          -- a tick: the view's place
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
local S = { controller = nil, new_controller = true, next_tick = 0, ticks = 0, looks = 0, settings = nil,
	position = nil, key = nil, no_controller = 0, get_failed = false }

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
	Image.want(s.enabled and Settings.colour_factor(s) or nil, s.enabled and s.clean_image)
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
	descriptor_path = DESCRIPTOR_PATH, settings = function() return S.settings end,
	apply = function(s) use(s, true) end, preview = camera.show, camera = camera.camera })

-- Not while the panel is open: each click on Colours or Clean image would say it. The last line is held and said once
-- the panel is closed, so the log tells what the camera ended up with (silent before 1.0.3's trial of 5 November 2026).
local held_image = nil

local function report_image(fmt, ...)
	local line = string.format(fmt, ...)
	if panel.is_open() then held_image = line return end
	held_image = nil
	T.bounded("image", "%s", line)
end

-- What went wrong is said even while the panel is open, under its own bound: routine lines never silence it.
local function problem_image(fmt, ...)
	T.bounded("image problem", fmt, ...)
end

local function look_image()
	local writes, failed = Image.look(S.controller, report_image, problem_image)
	T.image_writes, T.image_failed = T.image_writes + writes, T.image_failed + failed
	if held_image ~= nil and not panel.is_open() then
		local line = held_image
		held_image = nil
		T.bounded("image", "%s", line)
	end
end

local function look()
	S.looks = S.looks + 1
	watch.check()
	panel.retry()
	-- Once a second, the camera's mode is read again even at the same address (a mode the game would load again).
	Layer.recheck()
	camera.look(S.controller)
	look_image()
end

-- Not while the panel is open: each step of a slider moves the view, and would use up the lines in a minute.
local function report_position(fmt, ...)
	if panel.is_open() then return end
	T.bounded("position", "camera position: " .. fmt, ...)
end

-- The camera found by the last look: a new pawn's camera takes the place at most a second after it arrives.
local function place()
	local result = Layer.frame(camera.camera(), S.position, log, report_position)
	if result == "set" then T.sets = T.sets + 1 elseif result == "failed" then T.set_failed = T.set_failed + 1 end
end

local function tick(pc)
	S.controller, S.ticks = pc, S.ticks + 1
	if S.new_controller then
		S.new_controller = false
		camera.new_controller()
		T.run("panel", panel.close, pc, "a load")
	end
	if panel.is_open() then T.run("panel", panel.tick, pc) end
	if S.ticks % LOOK_TICKS == 0 then
		T.run("looks", look)
		-- Outside look: the status line is written even while an error repeats there.
		if S.looks % STATUS_EVERY == 0 then
			local modes, managed = camera.counts()
			T.line(modes, managed, STATUS_EVERY * LOOK_TICKS * TICK_SECONDS // 60)
		end
	end
	if camera.pending() then T.run("panel", camera.tick) end
	if Image.pending() then T.run("looks", look_image) end
	if S.position ~= nil or not Layer.idle() then T.run("ticks", place) end
end

local function get(param) return param:get() end

-- Every frame: the panel's keys and, while it is open, its frame; a tick every TICK_SECONDS. Without a key pressed,
-- an open panel or a tick due, a frame reads nothing from the game.
local function frame_work(param)
	-- Asked here, under UE4SS's lock, never at start: a bind's Lua runs on UE4SS's own thread. Before the presses are
	-- taken, so a key changed in the settings never counts the old one's.
	if S.key ~= S.settings.panel_key then
		S.key = S.settings.panel_key
		Hotkey.want(S.key, log)
	end
	local toggles, escapes = Hotkey.take()
	local now = os.clock()
	local due = now + EARLY >= S.next_tick
	local busy = toggles > 0 or escapes > 0 or panel.is_open()
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
	if busy then T.run("panel", panel.frame, pc, toggles, escapes) end
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

-- Last: once the hook or the notification is set, the mod runs on the game thread, and this file must be done by
-- then. The lines below are only written when something failed.
Driver.start(frame, function() S.new_controller = true end, log)
