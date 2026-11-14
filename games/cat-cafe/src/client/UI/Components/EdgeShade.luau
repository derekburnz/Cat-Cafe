--!strict
-- A soft dark shade round the edges of the screen while something in the world has the player's eye (#3702, Derek
-- 2026-11-12: "put a little shade around the outsides of screen until animation of pool is done"). Four black
-- strips, one per edge, each fading to clear toward the middle through a UIGradient: no texture. The middle of the
-- screen stays clear. A tap anywhere that is not a drag (or a gamepad's A or B) calls `onTap`, and an optional small hint sits at the
-- bottom ("Tap to skip").
--   EdgeShade.show(parent, hint, onTap)   shows it; returns the function that lifts it (safe to call twice)
-- It fades in and out over FADE seconds, or appears at once with Roblox's Reduce Motion. Numbers in EdgeShadeLogic.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

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
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, EdgeShadeLogic.HINT_AT),
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = EdgeShadeLogic.HINT_FILL,
			FontFace = Theme.fonts.bodyBold,
			TextSize = EdgeShadeLogic.HINT_SIZE,
			TextColor3 = Color3.new(1, 1, 1),
			Text = hint,
			Parent = gui,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
			Create("UIStroke", {
				Color = Color3.new(1, 1, 1),
				Thickness = EdgeShadeLogic.HINT_RING,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end
	local lifted = false
	local function tap()
		if not lifted and onTap ~= nil then
			onTap()
		end
	end
	-- #4016 (Derek: "move the screen with right click during trait normal animations"): no full-screen button, which
	-- took every click and touch from the camera. A left click or a touch that ends near where it began, soon, and
	-- that no GUI took, is the tap; a right click drag or a touch drag turns the camera as usual.
	local downs: { [InputObject]: { at: Vector3, time: number } } = {}
	local began = UserInputService.InputBegan:Connect(
		function(input: InputObject, processed: boolean)
			local kind = input.UserInputType
			if
				processed
				or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch)
			then
				return
			end
			downs[input] = { at = input.Position, time = os.clock() }
		end
	)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		local down = downs[input]
		downs[input] = nil
		if down == nil then
			return
		end
		if EdgeShadeLogic.isTap((input.Position - down.at).Magnitude, os.clock() - down.time) then
			tap()
		end
	end)
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
		began:Disconnect()
		ended:Disconnect()
		table.clear(downs)
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
