--!strict
-- #4842 (Derek2 11-16: "when playing minigame dim the background ontop of hiding the ui so it helps players focus on
-- the minigame ... clear the dimming of background and stuff instantly if cat is caught or failed"). While the catch
-- circles or the rescue bar run (HUD.catchingChanged), the 3D world dims and greys a little through a
-- ColorCorrectionEffect of this client's own in Lighting. Post effects touch only the world, so the circles, the
-- trust bar over the cat and the money stay sharp. It eases in over IN seconds and goes off at once, with no fade,
-- the moment the catch ends (the server's result, #3078). One effect for the session, made on first use.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local FreeStart =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FreeStart"))

local CatchDim = {}

CatchDim.BRIGHTNESS = -0.22
CatchDim.SATURATION = -0.45
CatchDim.CONTRAST = -0.05
CatchDim.IN = 0.2

local effect: ColorCorrectionEffect? = nil
local easing: Tween? = nil

-- The values the effect holds: dimmed while on, plain (and disabled) while off.
function CatchDim.look(on: boolean): { [string]: number }
	if on then
		return {
			Brightness = CatchDim.BRIGHTNESS,
			Saturation = CatchDim.SATURATION,
			Contrast = CatchDim.CONTRAST,
		}
	end
	return { Brightness = 0, Saturation = 0, Contrast = 0 }
end

local function made(): ColorCorrectionEffect
	local existing = effect
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local fresh = Instance.new("ColorCorrectionEffect")
	fresh.Name = "CatchDim"
	fresh.Enabled = false
	fresh.Parent = Lighting
	effect = fresh
	return fresh
end

function CatchDim.set(on: boolean)
	-- #5533 (shared/FreeStart): no catch dim for a save on the play first start until Tier 3
	if on and FreeStart.quiet() then
		on = false
	end
	local running = easing
	if running ~= nil then
		running:Cancel()
		easing = nil
	end
	local dim = made()
	if not on then
		-- at once: no fade back, so the world is clear the moment the cat is caught or gets away
		dim.Enabled = false
		for key, value in CatchDim.look(false) do
			(dim :: any)[key] = value
		end
		return
	end
	dim.Enabled = true
	local tween = TweenService:Create(
		dim,
		TweenInfo.new(CatchDim.IN, Enum.EasingStyle.Quad),
		CatchDim.look(true)
	)
	easing = tween
	tween:Play()
end

return CatchDim
