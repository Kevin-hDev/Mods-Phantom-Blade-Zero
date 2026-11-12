-- The enemies the enemy speeds apply to: the game's monsters, PBZCharacter_NPC with BIsMonster set (the others are
-- bystanders and story characters without an AI: EnemyProbe, 12 November 2026, verified in game), 64 at most. Taken as
-- the game makes them (NotifyOnNewObject), only while the enemies' part is on; those already there when it starts are
-- found then, once, by a search of the world's actors (never a walk through every object of the game: optimisation.md,
-- 6.1). One that plays a timeline without being kept is taken in through its task (owner). Every
-- NEAR_EVERY s each is told near the player or not: only the near ones have their walk read and held, which costs a
-- read and a write each frame (the game rewrites their speed allowed every frame, verified in game).

local U = require("movement_unreal")
local Family = require("movement_family")

local M = {}

local NPC_CLASS = "/Script/ProjectPBZ.PBZCharacter_NPC"
local NPC = "PBZCharacter_NPC"
local STATICS = "/Script/Engine.Default__GameplayStatics"
local MAX_PENDING = 256    -- characters announced and not looked at yet: a load makes many at once
local MAX_ENEMIES = 64     -- enemies kept; past this, a new one takes the place of one far away
local NEAR = 5000          -- cm: closer to the player is near (50 m, past an archer's range)
local NEAR_EVERY = 0.5     -- seconds between two looks at who is near

-- on: whether the part runs (the watch keeps what it is told only then). pending: address -> object. list: address ->
-- enemy { actor, asc (its ability system's address, nil until read), near, g (movement_enemy_ground.lua's) }. by_asc:
-- ability system address -> enemy. release: called with an enemy let go while still valid (given at the start), so
-- that it keeps nothing of the mod's. px, py: where the player stood at the last look.
local L = { on = false, pending = {}, n_pending = 0, list = {}, count = 0, by_asc = {}, next_near = 0, errors = 0,
	scans = 0, left_out = 0, release = nil, px = nil, py = nil }

local function location_of(actor) return actor:K2_GetActorLocation() end
local function monster_of(actor) return actor.BIsMonster end
local function asc_of(actor) return actor.AbilitySystemComponent end

local function announced(obj)
	if not L.on or L.n_pending >= MAX_PENDING then return end
	local addr = U.address(obj)
	if addr == nil or L.pending[addr] ~= nil then return end
	L.pending[addr], L.n_pending = obj, L.n_pending + 1
end

-- At load: whether the game's characters are watched, and the error when not.
function M.watch()
	return pcall(function()
		NotifyOnNewObject(NPC_CLASS, function(obj)
			if not pcall(announced, obj) then L.errors = L.errors + 1 end
		end)
	end)
end

local function read_asc(e)
	local ok, asc = pcall(asc_of, e.actor)
	if not ok or not U.is_valid(asc) then return end
	e.asc = U.address(asc)
	if e.asc ~= nil then L.by_asc[e.asc] = e end
end

-- Where the player stands, kept for the looks until the next one.
local function here(pawn)
	local ok, v = pcall(location_of, pawn)
	local x, y = nil, nil
	if ok then x, y = U.flat(v) end
	if x ~= nil then L.px, L.py = x, y end
end

-- Whether the character stands near the player; nil when either cannot be read.
local function near_of(actor)
	local ok, v = pcall(location_of, actor)
	local x, y = nil, nil
	if ok then x, y = U.flat(v) end
	if x == nil or L.px == nil then return nil end
	return (x - L.px) ^ 2 + (y - L.py) ^ 2 < NEAR * NEAR
end

local function drop(addr, e, valid)
	L.list[addr], L.count = nil, L.count - 1
	if e.asc ~= nil and L.by_asc[e.asc] == e then L.by_asc[e.asc] = nil end
	if valid and L.release ~= nil then L.release(e) end
end

-- Room for one more: a place left or, for one near the player, the place of one far away. Returns whether there is
-- room.
local function room(near)
	if L.count < MAX_ENEMIES then return true end
	for addr, e in pairs(near and L.list or {}) do
		if not e.near then drop(addr, e, true); return true end
	end
	L.left_out = L.left_out + 1
	return false
end

-- A character the game made or found: kept when it is a monster and there is room. Returns the enemy kept, or nil.
local function take(obj, addr)
	if L.list[addr] ~= nil then return L.list[addr] end
	local name = U.name(obj)
	if name == nil or name:sub(1, 9) == "Default__" then return nil end
	local ok, monster = pcall(monster_of, obj)
	if not ok or monster ~= true then return nil end
	local near = near_of(obj) == true
	if not room(near) then return nil end
	local e = { actor = obj, near = near }
	L.list[addr], L.count = e, L.count + 1
	read_asc(e)
	return e
end

-- The characters of the game's NPC class in the player's world, or nil when the search cannot be made. Its out array
-- is a table UE4SS fills, as another mod of this game does (single source); GameplayStatics itself is found in game
-- (EnemyProbe, 12 November 2026).
local function in_world(pawn)
	local statics, class = nil, nil
	pcall(function() statics = StaticFindObject(STATICS) end)
	pcall(function() class = StaticFindObject(NPC_CLASS) end)
	if not (U.is_valid(statics) and U.is_valid(class)) then return nil end
	local out = {}
	if not pcall(function() statics:GetAllActorsOfClass(pawn, class, out) end) then return nil end
	local list = {}
	for _, item in ipairs(out) do list[#list + 1] = U.unwrap(item) end
	return list
end

-- The part starts: the monsters already in the world are found, once. say: the log. release: as L's. pawn: the
-- player's character.
function M.start(say, release, pawn)
	L.on, L.next_near, L.release = true, 0, release
	here(pawn)
	local start = os.clock()
	local found = in_world(pawn)
	L.scans = L.scans + 1
	if found == nil then say("the enemies already there cannot be looked for: they are taken as they attack") end
	local kept = 0
	for _, obj in ipairs(found or {}) do
		local addr = U.is_valid(obj) and U.address(obj) or nil
		if addr ~= nil and take(obj, addr) ~= nil then kept = kept + 1 end
	end
	say("enemy speeds on: %d enemies found among %d characters in %.0f ms", kept, #(found or {}),
		(os.clock() - start) * 1e3)
end

-- The part stops: every enemy let go (release, while still valid), nothing kept or watched.
function M.stop()
	for addr, e in pairs(L.list) do drop(addr, e, U.is_valid(e.actor)) end
	L.on, L.pending, L.n_pending = false, {}, 0
end

function M.on()
	return L.on
end

-- Each frame: the characters announced since the last are looked at; every NEAR_EVERY s, those gone are forgotten
-- (before anything else is read from them: GetClass on an object that is not valid crashes the game), and the others
-- told near the player or not. pawn: the player's character.
function M.frame(pawn, now)
	if L.n_pending > 0 then
		local pending = L.pending
		L.pending, L.n_pending = {}, 0
		for addr, obj in pairs(pending) do
			if U.is_valid(obj) then take(obj, addr) end
		end
	end
	if now < L.next_near then return end
	L.next_near = now + NEAR_EVERY
	here(pawn)
	for addr, e in pairs(L.list) do
		if not U.is_valid(e.actor) then
			drop(addr, e, false)
		else
			if e.asc == nil then read_asc(e) end
			local near = near_of(e.actor)
			if near ~= nil then e.near = near end
		end
	end
end

-- The enemy whose ability system this is (whose: its address, asc: the object), taken in when it is a monster not kept
-- yet; nil for any other owner.
function M.owner(whose, asc)
	local e = L.by_asc[whose]
	if e ~= nil or not L.on then return e end
	local avatar = nil
	pcall(function() avatar = asc.AvatarActor end)
	if not U.is_valid(avatar) then return nil end
	local addr = U.address(avatar)
	if addr == nil or L.list[addr] ~= nil then return nil end
	-- A rider's mount plays tasks too: only a character of the game's NPC class is taken.
	local class = nil
	pcall(function() class = avatar:GetClass() end)
	local is_npc = false
	for _, name in ipairs(Family.names(class)) do is_npc = is_npc or name == NPC end
	if not is_npc then return nil end
	e = take(avatar, addr)
	if e ~= nil and e.asc ~= whose then e = nil end
	return e
end

-- The enemies kept, address -> enemy; near: told near the player at the last look.
function M.all()
	return L.list
end

-- For the status line: enemies kept and near now; searches of the world at a start, enemies left out for
-- want of room and errors in the watch, these three since the last call.
function M.report()
	local near = 0
	for _, e in pairs(L.list) do if e.near then near = near + 1 end end
	local r = { kept = L.count, near = near, scans = L.scans, left_out = L.left_out, errors = L.errors }
	L.scans, L.left_out, L.errors = 0, 0, 0
	return r
end

return M
