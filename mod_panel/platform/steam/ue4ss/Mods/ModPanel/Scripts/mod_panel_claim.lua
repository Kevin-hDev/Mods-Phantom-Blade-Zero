-- One panel at a time between mods (D98, the only authority on the shared value's form). UE4SS's shared variable
-- PBZ_OpenPanel holds "<mod's folder> <os.time()>" while that mod's panel shows, "" else, always text (discovery 5).
-- Mod Panel writes its value when its panel shows, again each second while it is open, and "" at its closing while the
-- value still holds its own name. Before opening, at the press and just before showing, it reads the value: another
-- mod's name with a time 3 seconds or less from now means that mod's panel is open, and Mod Panel does not open. Any
-- other value counts for nothing, so a panel closed badly (a Lua error, a load gone wrong) blocks the other 3 seconds,
-- not until the game restarts. Without ModRef, or with a variable that cannot be read, the panel opens as before, said
-- once. The only module that reads or writes PBZ_OpenPanel.

local M = {}

M.NAME = "PBZ_OpenPanel"
local FRESH = 3                   -- seconds: two rewrites missed (a long frame) still count

local function get(ref) return ref:GetSharedVariable(M.NAME) end
local function set(ref, v) ref:SetSharedVariable(M.NAME, v) end

-- own: Mod Panel's folder name; report(fmt, ...): the panel's failures (D104).
function M.new(own, report)
	-- mine: the value holds Mod Panel's name since its last writing; told: a failure was said, once a session (D98): a
	-- reading and a writing fail with two messages, which would alternate.
	local C = { mine = false, told = false }

	local function broken(why)
		if C.told then return end
		C.told = true
		report("panel: other mods' panels cannot be seen (%s): the panel opens even while one is open", why)
	end

	local function ref()
		local r = rawget(_G, "ModRef")
		if r == nil then broken("no ModRef") end
		return r
	end

	local function value()
		local r = ref()
		if r == nil then return nil end
		local ok, v = pcall(get, r)
		if not ok then
			broken(tostring(v))
			return nil
		end
		return type(v) == "string" and v or nil
	end

	local function write(v)
		local r = ref()
		if r == nil then return false end
		local ok, err = pcall(set, r, v)
		if not ok then broken(tostring(err)) end
		return ok
	end

	-- Why another mod's panel keeps Mod Panel's closed, or nil: the mod whose panel shows now, Mod Panel left out.
	-- The time is the value's last word (D105): a mod's folder name may hold a space.
	function C.taken()
		local name, t = (value() or ""):match("^(.+) (%d+)$")
		if name == nil or name == own or math.abs(os.time() - tonumber(t)) > FRESH then return nil end
		return string.format("the panel of %s is open", name)
	end

	-- When the panel shows, and each second while it is open.
	function C.hold()
		if write(own .. " " .. os.time()) then C.mine = true end
	end

	-- At each closing: "" while the value still holds Mod Panel's name, never over another mod's.
	function C.release()
		if not C.mine then return end
		C.mine = false
		local name = (value() or ""):match("^(.+) %d+$")
		if name == own then write("") end
	end

	return C
end

return M
