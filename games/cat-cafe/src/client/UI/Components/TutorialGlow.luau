--!strict
-- #1796 (Derek2: "highlight those buttons during tutorial so its painfully obvious"): a thick gold outline round the
-- thing a tutorial step asks the player to press (the HUD's Upgrades tile, then the table or Bait bowl row in
-- Upgrades; TutorialHints.upgrade says which). It pulses between gold and white and thick and thin; with Roblox's
-- Reduce Motion on it holds still, thick and gold. It is its own frame the target's size (the stroke draws outside
-- its edge), so the target's own UIStroke stays as it is (a GuiObject draws only one UIStroke) and the HUD grid's
-- spacing check still measures the tile alone.
--   set(target, on)   puts the outline on the target, or takes it off; calling it again with the same answer is free

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Parent.Theme)

local TutorialGlow = {}

TutorialGlow.NAME = "TutorialGlow"
local THIN = 3
local THICK = 7
local PULSE_SECONDS = 0.6

function TutorialGlow.set(target: GuiObject?, on: boolean)
	if target == nil then
		return
	end
	local existing = target:FindFirstChild(TutorialGlow.NAME)
	if not on then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local still = GuiService.ReducedMotionEnabled
	local frame: Frame = Create("Frame", {
		Name = TutorialGlow.NAME,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = target,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	local stroke: UIStroke = Create("UIStroke", {
		Color = Theme.colors.gold,
		Thickness = if still then THICK - 1 else THIN,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	if not still then
		local info = TweenInfo.new(
			PULSE_SECONDS,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		TweenService:Create(stroke, info, { Thickness = THICK, Color = Theme.colors.white }):Play()
	end
end

return TutorialGlow
