-- The motion reactor component's traversal setup, against the game's own: heights from the player's MinHeight up to
-- their MaxHeight, never above GAME_MAX (game: 75 to 155 cm), so that a player who keeps the base game's feel keeps
-- it for the game's own traversals too; minimum depth 5 cm (game: 30), since thin fences were refused while seen. The
-- maximum depth (110 cm) and the detection (200 cm) stay the game's: raised, they made the game pick animations that
-- did not fit.
-- The game's values of those fields are read before the mod writes its own on a component, and put back, when the
-- mod is switched off, on any component that still holds the mod's last write (restore). Every CHECK_EVERY s the
-- setup is read again and written back if the game changed it; new settings that change none of these values write
-- nothing. The write lives in the component only: a new game session starts again from the game's values.

local R = require("vault_reading")
local Settings = require("vault_settings")
local Status = require("vault_status")

local M = {}

local CHECK_EVERY = 1             -- s
local GAME_MAX = 300              -- cm: the highest the game's detection was tried at; ours climbs higher
local FIELDS = { "MinFrontHeightType", "CustomMinFrontHeight", "MaxFrontHeight", "MinObstacleDepth" }
local CONFIG = { "bEnableAutoTraversal", "MeshDiffAngle", "DetectDistance", "bCheckFrontAngle", "bCheckPlatformAngle",
	"MaxPlatformAngle", "MinFrontHeightType", "CustomMinFrontHeight", "MaxFrontHeight", "MinObstacleDepth",
	"MaxObstacleDepth", "MaxFloorDepth", "MantleTrace" }

-- next: when to read the setup again; refused: a write failed for this component, so it is not tried again; game:
-- the game's values of FIELDS, by name; written: the values the mod wrote last.
local S = { next = 0, refused = false, game = nil, written = nil }

local function config(comp)
	return R.read(function() return comp.TraversalConfig end)
end

-- The values the mod writes, from the settings in force. EMinFrontHeightType::Custom (1): the minimum is
-- CustomMinFrontHeight, not a step.
local function wanted()
	return { MinFrontHeightType = 1, CustomMinFrontHeight = Settings.MinHeight,
		MaxFrontHeight = math.min(Settings.MaxHeight, GAME_MAX), MinObstacleDepth = 5 }
end

local function text(values)
	local parts = {}
	for _, k in ipairs(FIELDS) do parts[#parts + 1] = k .. "=" .. R.text(values[k]) end
	return table.concat(parts, " ")
end

local function same_values(a, b)
	for _, k in ipairs(FIELDS) do
		if math.abs(a[k] - b[k]) > 0.01 then return false end
	end
	return true
end

local function held(comp, values)
	local cfg = config(comp)
	if cfg == nil then return false end
	for _, k in ipairs(FIELDS) do
		local v = R.num(R.read(function() return cfg[k] end), nil)
		if v == nil or math.abs(v - values[k]) > 0.01 then return false end
	end
	return true
end

-- The whole setup as a table, with values in place of the game's; nil when one field cannot be read, so that a write
-- never puts a zero in a field the mod did not see.
local function whole(cfg, values)
	local t = {}
	for _, k in ipairs(CONFIG) do
		local v = R.read(function() return cfg[k] end)
		if v == nil then return nil end
		t[k] = v
	end
	local x = R.read(function() return cfg.FrontAngleRange.X end)
	local y = R.read(function() return cfg.FrontAngleRange.Y end)
	if x == nil or y == nil then return nil end
	t.FrontAngleRange = { X = x, Y = y }
	for _, k in ipairs(FIELDS) do t[k] = values[k] end
	return t
end

-- Writes values field by field; if the game keeps its own (the setup read may be a copy), writes the whole setup at
-- once. Whether one way held.
local function write(comp, values)
	Status.note("the game's traversal setup")
	local cfg = config(comp)
	if cfg == nil then return false, "setup unreadable" end
	pcall(function()
		for _, k in ipairs(FIELDS) do cfg[k] = values[k] end
	end)
	if held(comp, values) then return true, "field by field" end
	local t = whole(cfg, values)
	if t ~= nil then pcall(function() comp.TraversalConfig = t end) end
	if held(comp, values) then return true, "whole setup" end
	return false, "the game kept its own"
end

local function set(say, comp, why)
	local values = wanted()
	local ok, how = write(comp, values)
	if ok then
		S.written = values
		return say("traversal setup set (%s), %s: %s", why, how, text(values))
	end
	say("traversal setup not set (%s): %s", why, how)
	S.refused = true
end

-- The game's values of FIELDS, or nil when one cannot be read.
local function read_game(comp)
	local cfg = config(comp)
	if cfg == nil then return nil end
	local values = {}
	for _, k in ipairs(FIELDS) do
		values[k] = R.num(R.read(function() return cfg[k] end), nil)
		if values[k] == nil then return nil end
	end
	return values
end

-- A component to set up: a new character, or the mod switched on (why). The game's values are read each time, the
-- mod having put them back when it was switched off. Values equal to the mod's last write are its own, left on a
-- component it set up before (the same pawn given back at ClientRestart, or a put back that did not hold): the game's
-- values read before are kept, or switching the mod off would put the mod's values back.
function M.start(say, comp, now, why)
	S.next, S.refused = now + CHECK_EVERY, false
	local found = read_game(comp)
	if found == nil then
		S.refused = true
		return say("traversal setup not set (%s): the game's own values cannot be read, so they could not be put back",
			why)
	end
	if S.game == nil or S.written == nil or not same_values(found, S.written) then S.game = found end
	set(say, comp, why)
end

-- The settings changed: the new heights, now, when they change the values written.
function M.refresh(say, comp, now)
	S.next = now + CHECK_EVERY
	if S.refused or S.game == nil then return end
	local values = wanted()
	if S.written ~= nil and same_values(values, S.written) and held(comp, values) then return end
	set(say, comp, "settings changed")
end

function M.keep(say, comp, now)
	if now < S.next then return end
	S.next = now + CHECK_EVERY
	if S.refused or S.game == nil or held(comp, wanted()) then return end
	set(say, comp, "the game changed them")
end

-- The game's values back on comp when it still holds the mod's last write: the mod switched off, or a new character
-- while it is off (the same pawn given back).
function M.restore(say, comp)
	if S.game == nil or S.written == nil or not held(comp, S.written) then return end
	local ok, how = write(comp, S.game)
	if ok then return say("traversal setup put back to the game's (%s): %s", how, text(S.game)) end
	say("the game's traversal setup could not be put back: %s", how)
end

-- The whole setup in one line, for a trial build.
function M.describe(comp)
	local cfg = config(comp)
	if cfg == nil then return "traversal setup unreadable" end
	local parts = {}
	for _, k in ipairs(CONFIG) do parts[#parts + 1] = k .. "=" .. R.text(R.read(function() return cfg[k] end)) end
	return "the game's traversal setup: " .. table.concat(parts, " ")
end

return M
