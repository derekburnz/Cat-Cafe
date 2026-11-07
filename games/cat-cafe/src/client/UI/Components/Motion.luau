--!strict
-- Whether the UI may shake its panels (the catch circles' and the rescue bar's wobble): not when the player turned
-- Screen shake off in Settings (Derek 2026-10-27), nor when they asked Roblox for reduced motion. init keeps
-- `screenShake` in step with the Settings screen; the camera shake is the Effects code's (it reads the same key).

local GuiService = game:GetService("GuiService")

local Motion = {}

Motion.screenShake = true

function Motion.canShake(): boolean
	-- Whether the player asked Roblox for reduced motion: then a pop-in just appears (#2060, the catch's next ring).
	function Motion.reduced(): boolean
		return GuiService.ReducedMotionEnabled
	end

	return Motion.screenShake and not GuiService.ReducedMotionEnabled
end

-- Whether the player asked Roblox for reduced motion: then a pop-in just appears (#2060, the catch's next ring).
function Motion.reduced(): boolean
	return GuiService.ReducedMotionEnabled
end

return Motion
