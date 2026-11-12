-- How Dynamic FOV's settings file is written (dynamic_fov_settings_file.lua decides what is): in two steps, so the
-- file is never seen half written, and what a cut left behind is put right at the next start.

local M = {}

local NO_SUCH_FILE = 2

-- Writes text to a temporary file, then puts it in place: the file is never seen half written. The text reaches the
-- disk at the close, so a failed close (a full disk) fails the writing too. Windows renames onto no existing file: the
-- file in place is set aside first, put back if the new one cannot take its place, removed once it has. A copy set
-- aside and left there by a cut (power off) is put back at the next start (M.recover).
function M.put_in_place(path, text)
	local temporary, aside = path .. ".tmp", path .. ".bak"
	local f = io.open(temporary, "wb")
	local ok = f ~= nil and f:write(text) ~= nil
	if f ~= nil then ok = f:close() == true and ok end
	if not ok then
		os.remove(temporary)
		return false
	end
	local had = false
	local current = io.open(path, "rb")
	if current ~= nil then
		current:close()
		-- Older than the file in place: a copy an earlier cut left there.
		os.remove(aside)
		had = os.rename(path, aside) == true
		if not had then
			os.remove(temporary)
			return false
		end
	end
	if os.rename(temporary, path) ~= true then
		if had then os.rename(aside, path) end
		os.remove(temporary)
		return false
	end
	if had then os.remove(aside) end
	return true
end

-- At start: a file set aside by a save that a cut stopped half way is put back when the file is missing; with the
-- file in place, the copy is older and is removed. A temporary file left by a cut is removed, never put in place: a
-- power cut can lose a file's last writes even after its close, while the copy set aside was on the disk long before.
function M.recover(path, warn)
	os.remove(path .. ".tmp")
	local aside = path .. ".bak"
	local a = io.open(aside, "rb")
	if a == nil then return end
	a:close()
	local f, _, code = io.open(path, "rb")
	if f ~= nil then
		f:close()
		os.remove(aside)
	elseif code == NO_SUCH_FILE and os.rename(aside, path) == true then
		warn("put back the settings file a save had set aside before it was cut short")
	end
end

return M
