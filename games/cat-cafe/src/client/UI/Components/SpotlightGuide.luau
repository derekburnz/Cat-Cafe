--!strict
-- #3555 (Derek 2026-11-12: "do the darken screen and point through rank up also ... as some people are missing it"):
-- the tutorial's own spotlight on any button, with a line of words and a way to close it, and the small "Ready!"
-- tag for the times after the first. It adds nothing new to look at: the dim, the gold ring and the big arrow are
-- Components/TutorialGlow and TutorialArrow, so a walk-through looks exactly like a tutorial step.
--   local close = SpotlightGuide.show(button, "You can rank up!", function() ... end)
--       lights `button` (ring, arrow, the rest of the screen dimmed), puts the words by it and calls the function
--       once when the player presses anywhere on the dim. It never takes the press: what is under the dim still
--       gets it. `close()` takes it all away; the caller closes it on a press outside, on a press of the button,
--       and whenever its step no longer holds (the server's word, #3555).
--   local remove = SpotlightGuide.ready(button)
--       a small green "Ready!" tag on the button's top right corner that breathes gently (still with Roblox's
--       Reduce Motion). `remove()` takes it off.
-- The caller decides when: this never asks whether a rank up is possible and never starts by itself. One walk-through
-- at a time: a second show closes the first. Nothing here has a timer, an arrow of its own or hurry words.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local SpotlightGuideLogic = require(script.Parent.SpotlightGuideLogic)
local Theme = require(script.Parent.Parent.Theme)
local TutorialArrow = require(script.Parent.TutorialArrow)
local TutorialGlow = require(script.Parent.TutorialGlow)

local SpotlightGuide = {}

SpotlightGuide.CAPTION = "SpotlightCaption"
SpotlightGuide.TAG = "ReadyTag"
local Z = 61 -- over the tutorial's arrow (60) and its dim (59)
local CAPTION_HEIGHT = 40
local CAPTION_WIDTH = 280
local TAG_SIZE = Vector2.new(58, 22)
local READY_GREEN = Color3.fromHex("4CB86B")
local BREATHE = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local closeCurrent: (() -> ())? = nil

-- Lights `target` with `words` beside it; see the top of this file. Returns the function that closes it.
function SpotlightGuide.show(
	target: GuiObject,
	words: string,
	onOutside: (() -> ())?,
	ringOutside: boolean?
): () -> ()
	local previous = closeCurrent
	if previous ~= nil then
		previous()
	end
	local gui = target:FindFirstAncestorOfClass("ScreenGui")
	TutorialGlow.set(target, true, ringOutside) -- outside: for a card whose words reach its edge
	local caption: TextLabel? = nil
	if gui ~= nil and words ~= "" then
		local made: TextLabel = Create("TextLabel", {
			Name = SpotlightGuide.CAPTION,
			BackgroundColor3 = Theme.colors.cream,
			Size = UDim2.fromOffset(CAPTION_WIDTH, CAPTION_HEIGHT),
			FontFace = Theme.fonts.display,
			Text = words,
			TextColor3 = Theme.colors.ink,
			TextScaled = true,
			Active = false,
			ZIndex = Z,
			Parent = gui,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			Create("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12 }),
		})
		Outline.border(made)
		made:SetAttribute(TutorialArrow.AVOID, true) -- the arrow keeps off the words
		caption = made
	end

	-- the words follow the button (a HUD that folds, a window that opens with a pop)
	local follow: RBXScriptConnection? = nil
	if caption ~= nil and gui ~= nil then
		local label, screenGui = caption, gui
		local function place()
			label.Visible = target.Visible and target:IsDescendantOf(screenGui)
			local at = SpotlightGuideLogic.captionAt(
				target.AbsolutePosition - screenGui.AbsolutePosition,
				target.AbsoluteSize,
				screenGui.AbsoluteSize,
				label.AbsoluteSize
			)
			label.Position = UDim2.fromOffset(at.X, at.Y)
		end
		place()
		follow = RunService.Heartbeat:Connect(place)
	end

	-- a press on the dim: told to the caller, never taken
	local pressed: RBXScriptConnection? = nil
	local told = false
	if onOutside ~= nil then
		local tell = onOutside
		pressed = UserInputService.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
				return
			end
			-- InputObject.Position and AbsolutePosition share one space (both already under the top bar's inset)
			local point = Vector2.new(input.Position.X, input.Position.Y)
			if
				not told
				and SpotlightGuideLogic.outside(point, target.AbsolutePosition, target.AbsoluteSize)
			then
				told = true
				tell()
			end
		end)
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		if follow ~= nil then
			follow:Disconnect()
		end
		if pressed ~= nil then
			pressed:Disconnect()
		end
		if caption ~= nil then
			caption:Destroy()
		end
		TutorialGlow.set(target, false)
		if closeCurrent == close then
			closeCurrent = nil
		end
	end
	closeCurrent = close
	return close
end

-- A "Ready!" tag on `button`'s top right corner; see the top of this file. Returns the function that removes it.
function SpotlightGuide.ready(button: GuiObject, words: string?): () -> ()
	local existing = button:FindFirstChild(SpotlightGuide.TAG)
	if existing ~= nil then
		existing:Destroy()
	end
	local tag: TextLabel = Create("TextLabel", {
		Name = SpotlightGuide.TAG,
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = READY_GREEN,
		Position = UDim2.new(1, 6, 0, -8),
		Size = UDim2.fromOffset(TAG_SIZE.X, TAG_SIZE.Y),
		FontFace = Theme.fonts.display,
		Text = words or "Ready!",
		TextColor3 = Theme.colors.white,
		TextScaled = true,
		Active = false,
		ZIndex = button.ZIndex + 2,
		Parent = button,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		Create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 10 }),
	})
	Outline.border(tag)
	Outline.text(tag, 1.5)
	local size: UIScale = Create("UIScale", { Scale = 1, Parent = tag })
	local tween: Tween? = nil
	if not GuiService.ReducedMotionEnabled then
		local made = TweenService:Create(size, BREATHE, { Scale = 1.1 })
		made:Play()
		tween = made
	end
	return function()
		if tween ~= nil then
			tween:Cancel()
		end
		tag:Destroy()
	end
end

return SpotlightGuide
