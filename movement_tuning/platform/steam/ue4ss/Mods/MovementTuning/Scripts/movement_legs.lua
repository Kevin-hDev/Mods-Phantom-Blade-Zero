-- The legs' cadence under the game's speed: walking, running or sprinting slower than the game (a gait setting under
-- 1), the character slid, its legs at the game's cadence over half the ground (Kevin, trial of 1.0.18: "the character
-- skates far too much"). The mesh's animation rate (GlobalAnimRateScale, written without error by RealismProbe, 9
-- November 2026) is held at the game's own times the ground speeds' factor, on the ground with the stick pushed and no
-- montage (attacks, dodges, which the timelines pace), not in one of the game's turn clips (below), and not crouched
-- (a crouch has a speed of its own, which the ground speeds do not set). Faster than the game, the legs keep the
-- game's cadence (Kevin, 10 November 2026: faster legs were refused by eye). A stop, a montage or the air gives the
-- game's rate back at once: an attack or a dodge starting must play at its own speed; going slower is eased over
-- SMOOTH s.

local U = require("movement_unreal")
local Held = require("movement_held")

local M = {}

local FIELD = "GlobalAnimRateScale"
local NEUTRAL = 0.999   -- a factor this close to 1 changes nothing
local SMOOTH = 0.08     -- seconds over which the cadence eases down, as RealismProbe did
local MAX_LAYERS = 16   -- linked animation instances looked through for the locomotion layer, as RealismProbe did
local LAYER_LOOK = 2    -- seconds between two looks for it, found or not: a layer the game unlinks (another weapon's
                        -- may take its place, not seen) can stay valid, and its clip would no longer be the one playing
-- The game's turn clips turn the body themselves (Hun_Unarmed_Run_Reface_Start_F_L_180, _Walk_Turn_R_090,
-- _Idle_TurnRight_90, in RealismProbe's log of 10 November 2026). Slowed, the body turned late while the movement had
-- already turned, and the feet slid (Kevin, trial of 1.0.19): they keep the game's cadence. Matched as written in the
-- names, capital first: a name with "Return" in it is no turn.
local TURNS = { "Reface", "Turn", "Pivot" }

-- held: the rate the mod holds. mesh, mesh_addr: the mesh it holds it on and its address (a new pawn's is another).
-- scale: the eased factor. clock: the last frame's, for the easing. broken: the rate cannot be written, said once for
-- a character. layer: the locomotion layer, the linked instance whose blend stack plays the clips (found in game by
-- RealismProbe: ABP_Hun_Locomotion_C); next_look: when to look for it again. unread: the clip could not be read, said
-- once. slowed: frames the legs were slowed since the last status line.
local L = { held = Held.new(), mesh = nil, mesh_addr = nil, scale = 1, clock = nil, broken = false, layer = nil,
	next_look = 0, unread = false, slowed = 0 }

local function mesh_of(pawn) return pawn.Mesh end
local function crouched_of(pawn) return pawn.bIsCrouched end
local function layers_of(mesh) return U.items(mesh.LinkedInstances, MAX_LAYERS) end
local function blend_rate(inst) return inst.AnimGraphNode_BlendStack.WantedPlayRate end
local function clip_of(inst) return inst.AnimGraphNode_BlendStack.AnimationAsset end

-- Gives the game its rate back where the mod's is still in place. Nothing held: nothing done, nothing made.
function M.release()
	Held.release(L.held, L.mesh ~= nil and U.is_valid(L.mesh) and L.mesh or nil)
	L.mesh, L.mesh_addr, L.scale = nil, nil, 1
end

-- A new character: its mesh and its layer are read anew, a rate that could not be written is tried again; what was
-- held on the old mesh is given back if it is still there.
function M.forget()
	M.release()
	L.clock, L.layer, L.next_look, L.broken = nil, nil, 0, false
end

local function layer(mesh, now)
	if now < L.next_look then return U.is_valid(L.layer) and L.layer or nil end
	L.next_look, L.layer = now + LAYER_LOOK, nil
	local ok, list = pcall(layers_of, mesh)
	for _, inst in ipairs(ok and list or {}) do
		if U.is_valid(inst) and pcall(blend_rate, inst) then
			L.layer = inst
			return inst
		end
	end
	return nil
end

-- Whether the locomotion clip playing is one of the game's turns; nil when it cannot be read (the legs are slowed all
-- the same: walking, running and sprinting without sliding, the turns as in 1.0.19), said once.
local function turning(mesh, now, say)
	local inst, ok, clip = layer(mesh, now), false, nil
	if inst ~= nil then ok, clip = pcall(clip_of, inst) end
	local name = ok and U.name(clip) or nil
	if name == nil then
		if not L.unread then
			L.unread = true
			say("the locomotion clip cannot be read: turns play at the slower cadence too")
		end
		return nil
	end
	for _, word in ipairs(TURNS) do
		if name:find(word, 1, true) then return true end
	end
	return false
end

local function slowed(pawn, cmc, mode, factor, now, say)
	if mode ~= U.WALKING or factor >= NEUTRAL then return nil end
	local _, _, pushed = U.acceleration(cmc, now)
	if pushed == nil or pushed < U.PUSHED then return nil end
	local ok, mesh = pcall(mesh_of, pawn)
	if not ok or not U.is_valid(mesh) then return nil end
	local read, crouched = pcall(crouched_of, pawn)
	if read and crouched == true then return nil end
	-- Unreadable (nil), a montage may be playing: the game's rate.
	if U.montage_plays(mesh) ~= false or turning(mesh, now, say) then return nil end
	return mesh
end

-- factor: the ground speeds' factor this frame (movement_ground.lua).
function M.frame(pawn, cmc, mode, factor, now, say)
	local dt = L.clock and now - L.clock or 0
	L.clock = now
	local mesh = not L.broken and slowed(pawn, cmc, mode, factor, now, say) or nil
	if mesh == nil then return M.release() end
	local addr = U.address(mesh)
	if L.mesh ~= nil and L.mesh_addr ~= addr then M.release() end
	L.scale = L.scale + (factor - L.scale) * (1 - math.exp(-math.max(dt, 0) / SMOOTH))
	if Held.hold(L.held, mesh, FIELD, L.scale) then
		L.mesh, L.mesh_addr, L.slowed = mesh, addr, L.slowed + 1
	else
		L.broken = true
		say("the legs' cadence cannot be changed (%s): slower gaits keep the game's cadence", FIELD)
		M.release()
	end
end

function M.holding()
	return Held.holding(L.held)
end

-- Frames the legs were slowed since the last call, for the status line.
function M.report()
	local n = L.slowed
	L.slowed = 0
	return n
end

return M
