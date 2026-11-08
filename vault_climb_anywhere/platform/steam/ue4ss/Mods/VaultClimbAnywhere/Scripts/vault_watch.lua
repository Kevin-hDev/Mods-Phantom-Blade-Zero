-- For a trial build only (vault_trial.lua), called while its lines are open: each change of the result's action or
-- of DoingTraversalAction, with the whole result; each change of the montage playing; and Circle, a mark with the
-- position and the result, for the tester to point at a jump that went wrong. Its time is the trial's detail in the
-- status line (vault_status.lua), which a published build does not spend.

local R = require("vault_reading")
local Keys = require("vault_keys")
local Trial = require("vault_trial")
local Result = require("vault_result")
local Status = require("vault_status")

local M = {}

local MARKS = { "Gamepad_FaceButton_Right" }

-- action, doing, montage: the last values said; down: Circle held at the last read.
local S = { action = nil, doing = nil, montage = nil, down = {} }

-- doing: DoingTraversalAction, read once this frame.
function M.frame(controller, comp, pawn, doing)
	local start = os.clock()
	local a = R.num(R.read(function() return comp.TraversalResult.ActionType end), -1)
	if a ~= S.action or doing ~= S.doing then
		S.action, S.doing = a, doing
		Trial.say("traversal: doing=%s %s %s", R.text(doing), Result.text(comp), R.where(pawn))
	end
	local m = R.read(function() return pawn.Mesh:GetAnimInstance():GetCurrentActiveMontage() end)
	local name = R.is_valid(m) and R.short(R.path(m)) or "none"
	if name ~= S.montage then
		S.montage = name
		Trial.say("montage: %s %s", name, R.where(pawn))
	end
	if Keys.pressed(controller, MARKS, S.down) then Trial.say("Circle mark: %s %s", Result.text(comp), R.where(pawn)) end
	Status.detail(os.clock() - start)
end

-- A new character or the mod switched off: everything is said again.
function M.reset()
	S.action, S.doing, S.montage = nil, nil, nil
end

return M
