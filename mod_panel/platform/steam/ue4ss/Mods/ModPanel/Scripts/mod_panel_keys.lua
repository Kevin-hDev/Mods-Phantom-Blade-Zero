-- Mod Panel's keys: UE4SS's binds, and the presses counted between two frames. Taken from Dynamic FOV 1.0.4
-- (dynamic_fov_hotkey.lua). UE4SS reads its binds on its own thread (UE4SSProgram::update) and runs their Lua under its
-- lock, as it runs the player controller's tick hook that drives the mod (mod_panel_driver.lua): the two never run at
-- the same time (UE4SS 1ceefac, LuaMod.cpp). A bind only counts presses; the next frame handles them. UE4SS binds see
-- the keyboard only (GetAsyncKeyState), once when a key goes down, never again while it is held. UE4SS cannot drop a
-- bind: one made for a key that is no longer the panel's does nothing.
-- UE4SS calls a bind only while exactly its modifier keys are held (Handler.cpp): the panel key and Escape are also
-- bound with each modifier alone, or they would do nothing while Shift, the sprint's key, is held (audit of
-- 5 November 2026). The keys that move in the open panel are bound without, and so are the keys a wait reads (D70).

local Names = require("mod_panel_key_names")

local M = {}

local MODIFIERS = { "SHIFT", "CONTROL", "ALT" }
local MAX_PENDING = 8             -- presses kept between two frames, for each count, and keys caught by a wait
-- The commands a press counts for; the controller's are the same (mod_panel_pad_commands.lua).
-- top and bottom come only from the controller (L2, R2, D99): no key is bound to them.
M.COUNTS = { "toggle", "escape", "up", "down", "left", "right", "enter", "prev", "next", "restore", "descriptions",
	"top", "bottom", "favorite" }
local COUNTS = M.COUNTS

-- current: the panel key (Mods Menu's spelling), nil for None. bound[name]: whether that key's bind was made; tried
-- once per key. pending: a press since the last take(). watched: the keys a wait reads bound; catching: a wait runs;
-- caught: the keys it caught since the last caught(), by the engine's name.
local P = { current = nil, bound = {}, shared = false, pending = false, n = {}, watched = false, catching = false,
	caught = {} }
for _, c in ipairs(COUNTS) do P.n[c] = 0 end

local function counter(name)
	return function()
		if P.n[name] < MAX_PENDING then
			P.n[name] = P.n[name] + 1
			P.pending = true
		end
	end
end

-- Returns whether the key works, then why not, or what it misses (a modifier this UE4SS refused).
local function bind(name, fn, with_modifiers)
	local keys = rawget(_G, "Key")
	local code = keys and keys[name]
	if code == nil then return false, "no such key in this UE4SS" end
	local ok, err = pcall(RegisterKeyBind, code, fn)
	if not ok then return false, tostring(err) end
	if not with_modifiers then return true, nil end
	local mods, missed, why = rawget(_G, "ModifierKey"), {}, nil
	for _, m in ipairs(MODIFIERS) do
		local okm, errm = false, "no such modifier in this UE4SS"
		if mods and mods[m] then okm, errm = pcall(RegisterKeyBind, code, { mods[m] }, fn) end
		if not okm then
			missed[#missed + 1] = m
			why = why or tostring(errm)
		end
	end
	if #missed == 0 then return true, nil end
	local names = #missed == 1 and missed[1]
		or table.concat(missed, ", ", 1, #missed - 1) .. " or " .. missed[#missed]
	return true, string.format("not while %s is held (%s)", names, why)
end

-- Escape and the keys of the open panel, bound once whatever the panel key.
local function bind_shared(log)
	local ok, err = bind("ESCAPE", counter("escape"), true)
	if not ok then
		log("Escape is not read in the panel (%s)", tostring(err))
	elseif err ~= nil then
		log("Escape is read in the panel, %s", err)
	end
	local missed = {}
	for key, c in pairs(Names.MOVES) do
		if not bind(key, counter(c), false) then missed[#missed + 1] = key end
	end
	if #missed > 0 then
		table.sort(missed)
		log("these keys do nothing in the panel, UE4SS cannot watch them: %s", table.concat(missed, ", "))
	end
end

-- Escape and the keys of the open panel bound, once: with the first panel key, or at the first frame the controller's
-- button is read with the panel key on None (D109; before 0.4.4 the keyboard did nothing in the panel with the key on
-- None). Never while Mod Panel is off from the start, so it then binds nothing (D46).
function M.share(log)
	if P.shared then return end
	P.shared = true
	bind_shared(log)
end

-- The panel key is now name (Mods Menu's spelling, or None). Its bind is made the first time, the other keys' with
-- it (M.share). Presses of the key before are dropped.
function M.want(name, log)
	P.current, P.n.toggle = Names.UE4SS[name] and name or nil, 0
	if P.current == nil then return end
	M.share(log)
	if P.bound[name] ~= nil then return end
	local ok, err = bind(Names.UE4SS[name], function()
		if P.current == name and P.n.toggle < MAX_PENDING then
			P.n.toggle = P.n.toggle + 1
			P.pending = true
		end
	end, true)
	P.bound[name] = ok
	if not ok then
		log("the panel key %s cannot be used (%s)", name, tostring(err))
	elseif err ~= nil then
		log("the panel key %s works, %s", name, err)
	end
end

-- The keys a wait reads (D70): every key Mod Panel can name, bound at the first wait of a key in the game, never
-- before: UE4SS cannot drop a bind, and reads each key bound at each of its turns, on its own thread. A bind adds its
-- key to those caught only while a wait runs, and does nothing else. log(fmt, ...): the panel's lines.
function M.watch(log)
	if P.watched then return end
	P.watched = true
	local began, missed = os.clock(), {}
	for _, name in ipairs(Names.KEYS) do
		local ok = bind(Names.UE4SS[name], function()
			if P.catching and #P.caught < MAX_PENDING then P.caught[#P.caught + 1] = name end
		end, false)
		if not ok then missed[#missed + 1] = name end
	end
	log("panel: the keys to choose from bound, %d in %d ms", #Names.KEYS - #missed,
		math.floor((os.clock() - began) * 1000 + 0.5))
	if #missed > 0 then
		log("panel: these keys do nothing in a wait, UE4SS cannot watch them: %s", table.concat(missed, ", "))
	end
end

-- A wait for a key begins (true) or ends (false); the keys caught before are dropped.
function M.catch(on)
	P.catching = on
	if #P.caught > 0 then P.caught = {} end
end

-- The keys caught since the last call, in their order, or nil when there are none.
function M.caught()
	local t = P.caught
	if #t == 0 then return nil end
	P.caught = {}
	return t
end

-- The presses since the last call, by count (toggle, escape, up, down, left, right, enter, prev, next, restore,
-- descriptions, and top and bottom, which only the controller gives), or nil when there were none: a frame without a
-- press makes no table.
function M.take()
	if not P.pending then return nil end
	P.pending = false
	local t, any = {}, false
	for _, c in ipairs(COUNTS) do
		t[c] = P.n[c]
		if t[c] > 0 then
			any = true
			P.n[c] = 0
		end
	end
	return any and t or nil
end

return M
