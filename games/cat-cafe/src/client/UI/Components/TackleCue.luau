--!strict
-- #2558 (Derek2 11-09: "makes pressing Q to tackle more obvious for pc players"): a big key cap with "Tackle!" over
-- the player carrying a cat that a step and a press would reach, while this player's tackle is ready. It pulses
-- (holds still with Reduce Motion) and shows on keyboard and gamepad (the cap reads Q, or Y after a gamepad press);
-- touch players have the round Tackle button instead. Screens/TackleBar decides when and over whom
-- (TackleTry.cueTarget) and stops it after TackleTry.CUE_HITS landed tackles in the session, so a player who knows
-- the key is left with the bar's own key cap. The billboard lives in this player's PlayerGui, so only they see it.
--
-- Roblox terms: a BillboardGui is 2D UI drawn at a point in the 3D world, always facing the camera; its Adornee is
-- the part it hangs over. AlwaysOnTop draws it over walls and other players.
--
--   TackleCue.new(parent)        the billboard, hidden; :show(root, key) over that part, :hide(), :destroy()

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type TackleCue = {
	gui: BillboardGui,
	show: (self: TackleCue, root: BasePart, key: string) -> (),
	hide: (self: TackleCue) -> (),
	destroy: (self: TackleCue) -> (),
}

local TackleCue = {}
TackleCue.__index = TackleCue

TackleCue.NAME = "CatCafeTackleCue"
TackleCue.LIFT = 4.5 -- studs over the carrier's root: over their head and the cat in their arms
TackleCue.PULSE = 1.18 -- the cue grows to this and back
TackleCue.PULSE_SECONDS = 0.45 -- one way

function TackleCue.new(parent: Instance): TackleCue
	local self = setmetatable({}, TackleCue) :: any
	local gui: BillboardGui = Create("BillboardGui", {
		Name = TackleCue.NAME,
		-- a fixed size on screen, near or far, so it reads at the length of a lunge
		Size = UDim2.fromOffset(150, 64),
		StudsOffsetWorldSpace = Vector3.new(0, TackleCue.LIFT, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = parent,
	})
	local holder: Frame = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local scale: UIScale = Create("UIScale", { Parent = holder })
	-- the key cap: a paper square with the key in ink, as on the bar, but big
	local key: TextLabel = Create("TextLabel", {
		Name = "Key",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(56, 56),
		FontFace = Theme.fonts.display,
		TextSize = 38,
		TextColor3 = Theme.colors.ink,
		Text = "Q",
		ZIndex = 2,
		Parent = holder,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	Outline.border(key, 3)
	local word: TextLabel = Create("TextLabel", {
		Name = "Word",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 64, 0.5, 0),
		Size = UDim2.new(1, -64, 0, 40),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.colors.warn,
		Text = "Tackle!",
		ZIndex = 2,
		Parent = holder,
	})
	Outline.text(word, 2.5)
	self.gui = gui
	self._key = key
	self._scale = scale
	self._pulse = nil :: Tween?
	return self :: TackleCue
end

function TackleCue.show(self: any, root: BasePart, key: string)
	local gui: BillboardGui = self.gui
	gui.Adornee = root
	self._key.Text = key
	gui.Enabled = true
	local pulse: Tween? = self._pulse
	if GuiService.ReducedMotionEnabled then
		if pulse ~= nil then
			pulse:Cancel()
			self._pulse = nil
		end
		self._scale.Scale = 1
	elseif pulse == nil then
		self._scale.Scale = 1
		local made = TweenService:Create(
			self._scale,
			TweenInfo.new(
				TackleCue.PULSE_SECONDS,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			),
			{ Scale = TackleCue.PULSE }
		)
		made:Play()
		self._pulse = made
	end
end

function TackleCue.hide(self: any)
	local gui: BillboardGui = self.gui
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	(gui :: any).Adornee = nil
	local pulse: Tween? = self._pulse
	if pulse ~= nil then
		pulse:Cancel()
		self._pulse = nil
	end
end

function TackleCue.destroy(self: any)
	self:hide()
	self.gui:Destroy()
end

return TackleCue
