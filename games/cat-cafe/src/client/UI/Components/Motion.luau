--!strict
-- Whether the UI may shake its panels (the catch circles' and the rescue bar's wobble): not when the player turned
-- Screen shake off in Settings (Derek 2026-10-27), nor when they asked Roblox for reduced motion. init keeps
-- `screenShake` in step with the Settings screen; the camera shake is the Effects code's (it reads the same key).

local GuiService = game:GetService("GuiService")

local Motion = {}

Motion.screenShake = true

function Motion.canShake(): boolean
	return Motion.screenShake and not GuiService.ReducedMotionEnabled
end

return Motion
