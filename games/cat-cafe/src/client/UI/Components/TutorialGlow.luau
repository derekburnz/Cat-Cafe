--!strict
-- #1796 (Derek2: "highlight those buttons during tutorial so its painfully obvious"): a thick gold outline round the
-- thing a tutorial step asks the player to press (the HUD's Upgrades tile, then the table or Bait bowl row in
-- Upgrades; TutorialHints.upgrade says which). It pulses between gold and white and thick and thin; with Roblox's
-- Reduce Motion on it holds still, thick and gold. It is its own frame the target's size (the stroke draws outside
-- its edge), so the target's own UIStroke stays as it is (a GuiObject draws only one UIStroke) and the HUD grid's
-- spacing check still measures the tile alone.
--   set(target, on, outside?)   puts the outline on the target, or takes it off; calling it again with the same
--       answer is free. `outside` draws the ring round the target's edge instead of inside it, for a card whose
--       words reach its edge (the goal card: the inside ring covered the first letters of its lines). `noDim` (Derek
--       2026-11-16, the rank up window's button and the strip's RANK UP): the ring and the arrow with no dim round
--       it, so nothing covers the window's X
-- #2314: each glowing target also gets Components/TutorialArrow, the big arrow pointing at it for a while.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local FreeStart =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FreeStart"))
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent.TutorialArrow)

local TutorialGlow = {}

TutorialGlow.NAME = "TutorialGlow"
local THIN = 3
local THICK = 7
local PULSE_SECONDS = 0.6

-- `lead` (#4909): with noDim, the arrow still leads over the HUD's tutorial targets (a card's button over the HUD)
function TutorialGlow.set(
	target: GuiObject?,
	on: boolean,
	outside: boolean?,
	noDim: boolean?,
	lead: boolean?
)
	if target == nil then
		return
	end
	-- #5533 (shared/FreeStart): no ring, dim or arrow for a save on the play first start until Tier 3
	if on and FreeStart.quietFor(target) then -- #5599: but a target marked LOUD_ATTR
		on = false
	end
	local existing = target:FindFirstChild(TutorialGlow.NAME)
	if not on then
		if existing then
			existing:Destroy()
			TutorialArrow.remove(target) -- #2314: the arrow goes with the glow
		end
		return
	end
	if existing then
		return
	end
	TutorialArrow.add(target, noDim and lead ~= true, noDim and lead == true) -- #2314: and a big arrow points at it for a while (a `low` one: no dim)
	local still = GuiService.ReducedMotionEnabled
	local frame: Frame = Create("Frame", {
		Name = TutorialGlow.NAME,
		BackgroundTransparency = 1,
		-- inset by the thickest stroke, so the ring stays inside the target's own box: the HUD grid's spacing check
		-- measured the outline as part of the tile and found it 1 px from its neighbour (CI on #1797)
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = if outside then UDim2.fromScale(1, 1) else UDim2.new(1, -2 * THICK, 1, -2 * THICK),
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
