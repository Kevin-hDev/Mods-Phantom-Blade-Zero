-- The player's camera and the field of view of its modes: the camera found again at each new pawn (load, respawn), its
-- modes scanned, and the values the settings want written there (dynamic_fov_modes.lua). The camera eases itself
-- towards its mode's values, so they are written only when they change: checked every two looks, all the camera's
-- modes scanned every ten once they stop changing (modes the game would load again). While the panel shows one
-- setting's field of view, every managed mode takes it (preview); during an execution, every managed mode takes
-- the game's own (pause).

local U = require("dynamic_fov_unreal")
local Settings = require("dynamic_fov_settings")
local Modes = require("dynamic_fov_modes")

local M = {}

local CHECK_EVERY = 2             -- looks between two checks of the managed modes' values
-- Looks between two scans of all the camera's modes once they stop changing, for a mode the game would replace in
-- play (never seen). Until then, every CHECK_EVERY: a camera fills in over a few seconds after a load (seen in game).
local SCAN_EVERY = 10
local EMPTY_SCANS = 5             -- scans of a camera without modes before it is reported

-- Named functions for pcall rather than a new closure at each look.
local function pawn_of(controller) return controller.Pawn end
local function name_of(obj) return obj:GetFName():ToString() end

local function shown(v)
	return v and string.format("%.2f", v) or "unreadable"
end

-- T: the mod's lines and counts (dynamic_fov_status.lua). new_pawn(): a new pawn came; it runs before the mod reads
-- the pawn's camera.
function M.new(T, log, new_pawn)
	-- wanted: the values written for each setting, nil while the mod is off, so the game's values go back. preview:
	-- the values every managed mode takes while the panel shows one field of view. reapply: a change to write at the
	-- next tick rather than at the next look. paused: an execution, the game's values written meanwhile.
	local K = { pawn = nil, pawn_name = nil, camera = nil, check_in = 0, scan_in = 0, dirty = true, reapply = false,
		restored = false, modes = -1, managed = -1, empty = 0, wanted = nil, speed = 0, preview = nil, paused = false }
	local C = {}

	-- At most once for each mode in a session: with the mod on, the values before are the game's own.
	local function first_write(tag, fov, speed, w)
		log("first write to %s: field of view %s to %s, speed %s to %s", tostring(tag), shown(fov), shown(w.fov),
			shown(speed), shown(w.speed))
	end

	local function wanted(setting)
		if K.wanted == nil or K.paused then return nil end
		return K.preview or K.wanted[setting]
	end

	-- The values settings s give. at_once: written at the next tick (a change made in the panel), else at the next look.
	function C.use(s, at_once)
		K.speed, K.wanted, K.restored = Modes.SPEED_TIME / s.transition, nil, false
		if s.enabled then
			K.wanted = {}
			for _, k in ipairs(Settings.FOV_KEYS) do K.wanted[k.field] = { fov = s[k.field], speed = K.speed } end
		end
		if K.preview ~= nil then K.preview = { fov = K.preview.fov, speed = K.speed } end
		if at_once then K.reapply = true else K.dirty = true end
	end

	-- The field of view every managed mode takes while the panel shows it; nil gives each mode its own back.
	function C.show(fov)
		if (K.preview and K.preview.fov) == fov then return end
		K.preview = fov and { fov = fov, speed = K.speed } or nil
		K.reapply = true
	end

	-- During an execution (on), the game's values in every managed mode, and the settings' back after it; written at
	-- the next tick. The game's camera eases to them at the mode's own speed, also the game's meanwhile.
	function C.pause(on)
		if K.paused == on then return end
		K.paused, K.reapply = on, true
	end

	-- The camera of the controller's pawn. A pawn is known by its address and its name: one that takes the old one's
	-- address after a garbage collection has another name.
	local function find(controller)
		local okp, pawn = pcall(pawn_of, controller)
		if not okp or not U.is_valid(pawn) then return nil end
		local addr = U.address(pawn)
		local okn, name = pcall(name_of, pawn)
		name = okn and type(name) == "string" and name or nil
		if addr ~= K.pawn or name ~= K.pawn_name then
			K.pawn, K.pawn_name, K.camera = addr, name, nil
			new_pawn()
		end
		if not U.is_valid(K.camera) then
			K.camera = Modes.camera(pawn)
			if K.camera == nil then return nil end
			-- Its modes may sit at addresses the mod knew for other modes, and switched off, they are checked once.
			Modes.forget()
			K.scan_in, K.dirty, K.restored, K.empty = 0, true, false, 0
		end
		return K.camera
	end

	-- All the camera's modes; returns how many are new to the mod.
	local function scan(cam)
		local total, managed, fresh = Modes.scan(cam)
		if managed < K.managed then
			-- A managed mode may now sit at an address the mod knew for an unmanaged one: every address is checked
			-- again.
			Modes.forget()
			total, managed, fresh = Modes.scan(cam)
		end
		local settled = managed > 0 and fresh == 0 and total == K.modes and managed == K.managed
		K.scan_in = settled and SCAN_EVERY or CHECK_EVERY
		-- The camera of a pawn just arrived has no mode for a moment (seen in game): reported only if that lasts.
		K.empty = total == 0 and K.empty + 1 or 0
		if K.empty == EMPTY_SCANS then
			T.bounded("camera", "camera: no modes found after %d scans: the mod does nothing", EMPTY_SCANS)
		end
		if total ~= K.modes or managed ~= K.managed then
			K.modes, K.managed = total, managed
			if total > 0 and managed == 0 then
				log("camera: %d modes, none managed: the mod does nothing", total)
			elseif total > 0 then
				T.bounded("camera", "camera: %d modes, %d managed", total, managed)
			end
		end
		return fresh
	end

	-- quiet: a change made in the panel, not written to the log at each step, only a failure: dragging a slider used
	-- up the write lines in a minute (seen in game, 5 November 2026). The status line counts every write.
	local function apply(fresh, quiet)
		local writes, failed = Modes.apply(wanted, first_write)
		T.writes, T.failed = T.writes + writes, T.failed + failed
		if failed > 0 or (writes > 0 and not quiet) then
			T.bounded("write", "%s: modes written %d%s%s",
				(K.wanted and not K.paused) and "settings applied" or "game's values back",
				writes, failed > 0 and string.format(", could not be written %d", failed) or "",
				fresh > 0 and string.format(" (modes new to the mod %d)", fresh) or "")
		end
		K.reapply = false
		-- A scan without a managed mode proves nothing: the modes may not be there yet.
		K.restored = K.wanted == nil and failed == 0 and K.managed > 0
	end

	-- Once a second.
	function C.look(controller)
		if not U.is_valid(controller) then return end
		local cam = find(controller)
		if cam == nil then return end
		-- Switched off and the game's values back: nothing more to read.
		if K.wanted == nil and K.restored then return end
		K.check_in, K.scan_in = K.check_in - 1, K.scan_in - 1
		if K.check_in > 0 and not K.dirty and not K.reapply then return end
		K.check_in = CHECK_EVERY
		apply((K.dirty or K.scan_in <= 0) and scan(cam) or 0, K.reapply and not K.dirty)
		K.dirty = false
	end

	-- Whether a change made in the panel waits for the next tick.
	function C.pending()
		return K.reapply
	end

	-- At each tick: a change made in the panel, written without waiting for the next look.
	function C.tick()
		if not K.reapply then return end
		K.reapply = false
		if U.is_valid(K.camera) and not (K.wanted == nil and K.restored) then apply(0, true) end
	end

	-- A player controller was made (a load): the next pawn counts as new, even at the old one's address and name.
	function C.new_controller()
		K.pawn, K.pawn_name = nil, nil
	end

	-- The camera found by the last look, or nil.
	function C.camera()
		return K.camera
	end

	-- Modes and managed modes at the last scan, -1 before the first.
	function C.counts()
		return K.modes, K.managed
	end

	return C
end

return M
