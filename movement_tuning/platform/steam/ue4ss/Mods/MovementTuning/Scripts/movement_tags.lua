-- The character's state tags the mod reads: the game's walk and sprint (CharacterState.Native.Attitude.Walking and
-- .Sprinting), named in the mechanic config, asked of the character's ability system. The one reader of them: the walk
-- (movement_walk.lua) and the sprint resume (movement_resume.lua) both ask here.

local U = require("movement_unreal")

local M = {}

local CONFIG = "PDA_GlobalMechanicConfig_C"
local LOOK_EVERY = 1      -- seconds between two looks for the mechanic config
local MAX_LOOKS = 15      -- looks before giving up until the next character: FindFirstOf walks the game's objects

-- tags: { walking, sprinting } once the config is found. broken: a tag could not be read; not asked again for this
-- character, as the call fails the same way each frame.
local G

function M.forget()
	G = { asc = nil, tags = nil, looks = 0, next_look = 0, broken = false }
end
M.forget()

local function tag(config, field)
	local name = nil
	pcall(function() name = config[field].TagName:ToString() end)
	if type(name) ~= "string" or name == "" or name == "None" then return nil end
	return { TagName = FName(name) }
end

-- Whether the tags can be asked this frame: looks for the config (at most every LOOK_EVERY s, MAX_LOOKS times) and the
-- ability system when they are missing.
function M.look(pawn, now)
	if G.broken then return false end
	if G.tags == nil and G.looks < MAX_LOOKS and now >= G.next_look then
		G.looks, G.next_look = G.looks + 1, now + LOOK_EVERY
		local config = nil
		pcall(function() config = FindFirstOf(CONFIG) end)
		local walking = U.is_valid(config) and tag(config, "Walking Tag") or nil
		if walking ~= nil then G.tags = { walking = walking, sprinting = tag(config, "Sprinting Tag") } end
	end
	-- One validity check a frame while the ability system is kept (each one is a call to the game).
	if G.tags == nil then return false end
	if U.is_valid(G.asc) then return true end
	pcall(function() G.asc = pawn.AbilitySystemComponent end)
	return U.is_valid(G.asc)
end

-- The config was not found in MAX_LOOKS looks, or a tag could not be read: no tag for this character.
function M.gave_up()
	return G.broken or (G.tags == nil and G.looks >= MAX_LOOKS)
end

function M.broken()
	return G.broken
end

-- Whether the character holds the tag ("walking" or "sprinting"); nil when it cannot be asked. Call after look().
function M.has(key)
	local t = G.tags and G.tags[key]
	if t == nil or G.broken then return nil end
	local ok, v = pcall(function() return G.asc:HasMatchingGameplayTag(t) end)
	if not ok or type(v) ~= "boolean" then
		G.broken = true
		return nil
	end
	return v
end

return M
