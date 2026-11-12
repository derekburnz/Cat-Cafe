--!strict
-- A soft dark shade round the edges of the screen while something in the world has the player's eye (#3702, Derek
-- 2026-11-12: "put a little shade around the outsides of screen until animation of pool is done"). Four black
-- strips, one per edge, each fading to clear toward the middle through a UIGradient: no texture. The middle of the
-- screen stays clear. A tap anywhere (or a gamepad's A or B) calls `onTap`, and an optional small hint sits at the
-- bottom ("Tap to skip").
--   EdgeShade.show(parent, hint, onTap)   shows it; returns the function that lifts it (safe to call twice)
-- It fades in and out over FADE seconds, or appears at once with Roblox's Reduce Motion. Numbers in EdgeShadeLogic.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local Create = require(script.Parent.Create)
local EdgeShadeLogic = require(script.Parent.EdgeShadeLogic)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

local EdgeShade = {}

local ACTION = "CatCafeEdgeShadeSkip"
local FADE = TweenInfo.new(EdgeShadeLogic.FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function EdgeShade.show(parent: Instance, hint: string?, onTap: (() -> ())?): () -> ()
	local gui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeEdgeShade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = EdgeShadeLogic.DISPLAY_ORDER,
		Parent = parent,
	})
	local still = GuiService.ReducedMotionEnabled
	local strips: { Frame } = {}
	for _, edge in EdgeShadeLogic.EDGES do
		local strip: Frame = Create("Frame", {
			Name = edge.name,
			AnchorPoint = edge.anchor,
			Position = UDim2.fromScale(edge.anchor.X, edge.anchor.Y),
			Size = UDim2.fromScale(edge.size.X, edge.size.Y),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = if still then 0 else 1,
			BorderSizePixel = 0,
			Parent = gui,
		})
		Create("UIGradient", {
			Rotation = edge.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, EdgeShadeLogic.EDGE_TRANSPARENCY),
				NumberSequenceKeypoint.new(0.5, EdgeShadeLogic.MID_TRANSPARENCY),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = strip,
		})
		table.insert(strips, strip)
		if not still then
			Tween.to(strip, FADE, { BackgroundTransparency = 0 })
		end
	end
	if hint ~= nil and hint ~= "" then
		Create("TextLabel", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -EdgeShadeLogic.HINT_BOTTOM),
			Size = UDim2.fromOffset(240, 24),
			BackgroundTransparency = 1,
			FontFace = Theme.fonts.body,
			TextSize = EdgeShadeLogic.HINT_SIZE,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.4,
			Text = hint,
			Parent = gui,
		})
	end
	local lifted = false
	local function tap()
		if not lifted and onTap ~= nil then
			onTap()
		end
	end
	local catcher: TextButton = Create("TextButton", {
		Name = "Tap",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Parent = gui,
	})
	catcher.Activated:Connect(tap)
	ContextActionService:BindAction(
		ACTION,
		function(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				tap()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB
	)
	return function()
		if lifted then
			return
		end
		lifted = true
		ContextActionService:UnbindAction(ACTION)
		catcher.Active = false
		catcher.Visible = false
		if still then
			gui:Destroy()
			return
		end
		for _, strip in strips do
			Tween.to(strip, FADE, { BackgroundTransparency = 1 })
		end
		task.delay(EdgeShadeLogic.FADE + 0.05, function()
			gui:Destroy()
		end)
	end
end

return EdgeShade
