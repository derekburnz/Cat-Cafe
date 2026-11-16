--!strict
-- #4877 (Derek 2026-11-16: "make sure no admin events ui or anything on screen for people in tutorial steps"): whether
-- nothing of an admin event may show now. The UI hands in the probe (AdminFlash.hideWhen, UI.firstCat.tutorial);
-- AdminFlash and AdminAir read it. Its own small module, so AdminAir needs none of AdminFlash's requires.
local AdminHide = {}

local probe: (() -> boolean)? = nil

function AdminHide.set(fn: () -> boolean)
	probe = fn
end

-- True while the probe says so; false with none set or when it errors.
function AdminHide.on(): boolean
	local fn = probe
	if fn == nil then
		return false
	end
	local ok, value = pcall(fn)
	return ok and value == true
end

return AdminHide
