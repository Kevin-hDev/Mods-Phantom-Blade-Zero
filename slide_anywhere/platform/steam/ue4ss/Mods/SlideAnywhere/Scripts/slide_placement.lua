-- The game's foot placement, turned off while a slide leans (slide_tilt.lua), by turning off the character's whole
-- post-process animation, which holds it. Seventh trial (5 November 2026, essai-glissade-12, seen in game): leaned
-- 20° back, the lifted foot rose from about 44 to 66-72 cm above the planted one in the mesh's own space, so the
-- player saw it barely lower. Eighth trial (essai-glissade-13, seen in game): with the post-process animation off,
-- the same lean left it at 36-49 cm, seen at 20-26 cm, and Kevin saw those slides better. The foot placement node
-- alone could not be turned off: the game wrote its Alpha back every frame (127 of 128 frames in slide #1).
-- The mesh's bDisablePostProcessBlueprint is written directly: SetDisablePostProcessBlueprint would reinitialise that
-- animation when it comes back, and it may be running on another thread then (engine knowledge, not checked).
-- It is put back after the lean, unless the game changed it meanwhile; if the game turns the animation back on during
-- the lean, it is turned off again, counted, and the game's value is the one put back.

local R = require("slide_reading")
local Trial = require("slide_trial")

local M = {}

local NAME = "bDisablePostProcessBlueprint"

local P = { mesh = nil, held = nil, said = false }

local function read()
	local v = nil
	pcall(function() v = P.mesh.bDisablePostProcessBlueprint end)
	if type(v) ~= "boolean" then return nil end
	return v
end

local function write(v)
	return pcall(function() P.mesh.bDisablePostProcessBlueprint = v end)
end

function M.on_pawn(say, mesh)
	P.mesh, P.held, P.said = mesh, nil, false
	local pp = nil
	pcall(function() pp = mesh:GetPostProcessInstance() end)
	say("foot placement: post-process %s, %s=%s", R.class_name(pp), NAME, tostring(read()))
end

function M.hold(say)
	M.release(say)
	if not R.is_valid(P.mesh) then return end
	local v = read()
	if v == nil or not write(true) then
		if not P.said then say("the post-process animation cannot be turned off: %s unreadable or refused", NAME) end
		P.said = true
		return
	end
	P.held = { saved = v, rewrites = 0 }
	Trial.say("post-process off: %s %s -> true", NAME, tostring(v))
end

-- Every frame of a lean.
function M.frame()
	local h = P.held
	if h == nil then return end
	local v = read()
	if v == false then
		h.saved, h.rewrites = v, h.rewrites + 1
		write(true)
	end
end

-- For the slide's summary: what is held and how often the game wrote it again.
function M.text()
	local h = P.held
	if h == nil then return "nothing held" end
	return string.format("post-process off, turned back on by the game %d", h.rewrites)
end

function M.release(say)
	local h = P.held
	P.held = nil
	if h == nil then return end
	if read() == true and not write(h.saved) then say("%s could not be put back to %s", NAME, tostring(h.saved)) end
end

-- A new pawn, the mod switched off or no button (slide_tilt.lua's reset): the mesh gets its value back, then is
-- forgotten.
function M.reset(say)
	if R.is_valid(P.mesh) then M.release(say) end
	P.mesh, P.held = nil, nil
end

return M
