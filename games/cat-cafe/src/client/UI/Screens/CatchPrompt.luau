--!strict
-- Catch prompt card for strays and stuck cats.
--   show(info)          "[E] Catch" card at the bottom centre with the cat's name and rarity (no stars, F97). v0.5: tries
--                       are unlimited; while the cat sprints off after a miss (info.fleeingUntil) it reads "It's
--                       running!", then "Cooling down 3s" (counting down) for the player who missed until info.retryAt, and
--                       turns back to Catch when it can be tried. A cat knocked loose by a shove reads "Owner's
--                       turn" for everyone else until info.ownerTurnUntil (reviewer N90). A dropped cat anyone can
--                       pick up (kind "pickup", v0.8 F56) reads "Pick up" with no circles, and "It's walking home"
--                       while it heads back to where it was caught (info.returning, v0.10 F67).
--   waiting()           one press went to the server: "Get ready..." until the circles (CatchCircles) or the
--                       rescue bar (RescueBar) come.
--   fail(reason)        red flash ("It got away"), then hide; with retry the card stays.
--   hide()
--   holdStart() / holdStop()   the player began or let go of the prompt's hold (PromptButtonHoldBegan/Ended):
--                       the key cap and the CATCH button fill with gold over info.holdDuration, letting go drains
--                       them (reviewer S52)
-- 2026-10-27: a stray's prompt (F26) and a stuck cat's (F27) are held for HoldDuration (0.5 s), so a passing
-- player never starts a catch by accident; the trigger asks the server for the closing circles or the rescue
-- minigame. The key cap says HOLD under it.
-- On touch a big round CATCH button appears; it drives the real prompt through holdBegan / holdEnded. #2315: on any
-- sign of touch (Components/TouchPrompt), not only a device with no keyboard or mouse, and it swaps live with the key
-- cap when the player's input changes.
-- bindProximityPrompts() in init.luau wires all of this to any ProximityPrompt with Style = Custom.
-- #4307 (Derek 2026-11-14: "if a phone player or tablet player is beside the cat prompt them to click the catch button
-- with the arrow pointing to it until they do"; touch players left at their first stray without starting a catch ~20x
-- as often as computer players): until the player's first press this session, a "Tap to catch!" bubble and a bobbing
-- gold arrow (drawn like Components/TutorialArrow's) point at the CATCH button from its left (the Tackle button may sit above
-- it), a gold ring keeps rippling out of the button (the button itself keeps its size, so it never grows onto the jump
-- button). The button is a quarter bigger than the Net button, on the
-- same right edge and middle, still clear of the jump button. A quick tap is enough: it finishes the 0.5 s hold
-- (kids tap, they don't hold). On a gamepad (Derek: "for console players make it show what button to swing on screen
-- if its not obvious") the same bubble reads "Hold X to catch!" over the card, the arrow pointing at the key cap.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Cooldown = require(script.Parent.Parent.Components.Cooldown)
local Create = require(script.Parent.Parent.Components.Create)
local JumpButton = require(script.Parent.Parent.Components.JumpButton)
local NetButtonPlace = require(script.Parent.Parent.Components.NetButtonPlace)
local Outline = require(script.Parent.Parent.Components.Outline)
local PromptKey = require(script.Parent.Parent.Components.PromptKey)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Parent.Components.Signal)
local Theme = require(script.Parent.Parent.Theme)
local TouchPrompt = require(script.Parent.Parent.Components.TouchPrompt)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local OWNER_TURN = "Owner's turn" -- a knocked-loose cat inside its old carrier's DropOwnerPrioritySeconds
-- Less text (Derek 2026-11-03: "all the texts on thins like this is not needed too much text on screen make pictures
-- easy for kids"): the card is the key, the word, the cat's name and rarity, and a little picture of the minigame (the
-- rescue bar, or a catch ring); the hint line shows only when it says why you have to wait.
local CARD_W = 360
local CARD_H = 70
local CARD_HINT_H = 86 -- with the hint line
local MINI_W = 96
-- #4307: the touch button, a quarter over the Net button's size (56 -> 70 beside the small jump button, 80 -> 100)
local GRAB_GROW = 1.25
local NUDGE_ARROW = 56 -- design px, the arrow's box
local NUDGE_GAP = 4
local BOB = 6 -- px the arrow bobs toward its tip
local BOB_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local RIPPLE_INFO = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)

export type CatchPrompt = {
	screenGui: ScreenGui,
	holdBegan: Signal.Signal,
	holdEnded: Signal.Signal,
	show: (self: CatchPrompt, info: Types.CatchInfo) -> (),
	fail: (self: CatchPrompt, reason: string?, retry: boolean?) -> (),
	waiting: (self: CatchPrompt) -> (),
	hide: (self: CatchPrompt) -> (),
	isVisible: (self: CatchPrompt) -> boolean,
	-- #3752: keeps the card over `top` (design pixels from the screen's bottom, negative: the Tackle bar's top
	-- edge), or back at its own place for nil
	setClear: (self: CatchPrompt, top: number?) -> (),
	grabShowing: (self: CatchPrompt) -> boolean, -- #2409
	blockedText: (self: CatchPrompt) -> string?,
	nudgeShowing: (self: CatchPrompt) -> boolean, -- #4307
	resetNudge: (self: CatchPrompt) -> (),
	holdStart: (self: CatchPrompt) -> (),
	holdStop: (self: CatchPrompt) -> (),
	destroy: (self: CatchPrompt) -> (),
}

local CatchPrompt = {}
CatchPrompt.__index = CatchPrompt

CatchPrompt.FOOT = -140 -- the card's bottom edge, design pixels from the screen's bottom
CatchPrompt.CLEAR_GAP = 8 -- px the card keeps over the Tackle bar (#3752)

-- Where the card's bottom edge sits when something whose top edge is at `top` shows under it (nil: nothing).
function CatchPrompt.foot(top: number?): number
	if top == nil then
		return CatchPrompt.FOOT
	end
	return math.min(CatchPrompt.FOOT, top - CatchPrompt.CLEAR_GAP)
end

function CatchPrompt.new(parent: Instance): CatchPrompt
	local self = setmetatable({}, CatchPrompt) :: any
	self.holdBegan = Signal.new()
	self.holdEnded = Signal.new()
	self._connections = {} :: { RBXScriptConnection }
	self._failToken = 0
	self._kind = "swing" :: Types.PromptKind
	self._fleeingUntil = nil :: number?
	self._retryAt = nil :: number?
	self._ownerTurnUntil = nil :: number?
	self._holdDuration = 0
	self._nudged = false -- #4307: the player pressed the prompt once this session; the nudge stays away

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeCatch",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 15,
		Enabled = false,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)
	self._root = root

	-- Card
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.hud.panel,
		BackgroundTransparency = Theme.hud.panelTransparency,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, CatchPrompt.FOOT),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 2) }),
		Create(
			"UIStroke",
			{ Color = Theme.hud.stroke, Transparency = Theme.hud.strokeTransparency, Thickness = 2 }
		),
	})
	self._card = card
	-- Key cap: a light key whose gold fill rises over the hold, with HOLD under it
	local keyFrame: Frame = Create("Frame", {
		Name = "Key",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(40, 40),
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	self._keyFrame = keyFrame
	self._keyFill = Create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = keyFrame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	self._keycap = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.ink,
		Text = "E",
		Parent = keyFrame,
	})
	self._holdTag = Create("TextLabel", {
		Name = "Hold",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.fromOffset(48, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.colors.gold,
		Text = "HOLD",
		Visible = false,
		Parent = card,
	})
	self._action = Create("TextLabel", {
		Name = "Action",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -(80 + MINI_W), 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge - 2,
		TextColor3 = Theme.hud.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Catch",
		Parent = card,
	})
	-- the cat's name and its rarity chip side by side under the word
	local line: Frame = Create("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 40),
		Size = UDim2.new(1, -(80 + MINI_W), 0, 20),
		Parent = card,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self._catName = Create("TextLabel", {
		Name = "Cat",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		LayoutOrder = 1,
		Parent = line,
	}, { Create("UISizeConstraint", { MaxSize = Vector2.new(CARD_W - 80 - MINI_W - 80, 20) }) })
	self._rarity = Create("TextLabel", {
		Name = "Rarity",
		BackgroundColor3 = Theme.rarity.Common.color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 18),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.rarity.Common.text,
		Text = "Common",
		Parent = line,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	self._hint = Create("TextLabel", {
		Name = "Hint",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(66, 62),
		Size = UDim2.new(1, -80, 0, 18),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textTiny,
		TextColor3 = Theme.hud.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = card,
	})
	-- the minigame in a picture, right of the words: the rescue bar (a dark track, the green zone, the marker) or a
	-- catch ring (the white ring and the gold circle closing on it); none for a pick up
	local bar: Frame = Create("Frame", {
		Name = "MiniBar",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, CARD_H / 2),
		Size = UDim2.fromOffset(MINI_W, 20),
		Visible = false,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2 }),
		Create("Frame", {
			Name = "Zone",
			BackgroundColor3 = Theme.colors.good,
			BorderSizePixel = 0,
			Position = UDim2.new(0.56, 0, 0, 4),
			Size = UDim2.new(0.28, 0, 1, -8),
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		Create("Frame", {
			Name = "Marker",
			BackgroundColor3 = Theme.colors.white,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.4, 0.5),
			Size = UDim2.new(0, 5, 1, 10),
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", { Color = Theme.colors.outline, Thickness = 1.5 }),
		}),
	})
	self._miniBar = bar
	local ring: Frame = Create("Frame", {
		Name = "MiniRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -(14 + MINI_W / 2), 0, CARD_H / 2),
		Size = UDim2.fromOffset(40, 40),
		Visible = false,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.white, Thickness = 3 }),
		Create("Frame", {
			Name = "Closing",
			BackgroundColor3 = Theme.colors.gold,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", { Color = Theme.colors.outline, Thickness = 2 }),
		}),
	})
	self._miniRing = ring

	-- Mobile CATCH button (bottom right, right of the Shove button); reads RESCUE on a stuck cat
	-- #2409 (Derek2: "rescue button is overlapping net button on mobile"): it takes the Net button's own spot, up and
	-- left of the jump button (_placeGrab), and the Net button steps away while it shows (UI's blocked())
	-- #4307: a gold ring that ripples out of the CATCH button while the nudge shows (under the button)
	local ripple: Frame = Create("Frame", {
		Name = "Ripple",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Name = "Ring", Color = Theme.colors.gold, Thickness = 4 }),
	})
	self._ripple = ripple
	local grab: TextButton = Create("TextButton", {
		Name = "Grab",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.good,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -100),
		Size = UDim2.fromOffset(108, 108),
		Visible = Scale.isTouch(),
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Theme.colors.goodDark, Thickness = 4 }),
	})
	self._grab = grab
	table.insert(
		self._connections,
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if grab.Visible then
				self:_placeGrab() -- a phone turned
			end
		end)
	)
	-- a gold disc that grows from the centre over the hold, under the word
	self._grabFill = Create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = grab,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._grabLabel = Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		FontFace = Theme.fonts.display,
		TextScaled = true, -- "PICK UP" and "RESCUE" fit the Net button's size on a small phone
		TextColor3 = Theme.colors.goodText,
		Text = "CATCH",
		Parent = grab,
	}, {
		Create("UITextSizeConstraint", { MaxTextSize = Theme.sizes.textLarge }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	local holding = false
	local latched = false -- #4307: let go before the hold was full; it lets go itself once full
	local pressedAt = 0
	local function release()
		holding = false
		latched = false
		grab.BackgroundColor3 = if self:blockedText()
			then Theme.colors.disabled
			else Theme.colors.good
		self.holdEnded:Fire()
	end
	table.insert(
		self._connections,
		grab.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if not holding then
					holding = true
					pressedAt = Workspace:GetServerTimeNow()
					grab.BackgroundColor3 = Theme.colors.goodDark
					self:_nudgeDone()
					self.holdBegan:Fire()
				end
			end
		end)
	)
	table.insert(
		self._connections,
		grab.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if holding and not latched then
					-- #4307: a quick tap finishes the hold; only a cat that can't be tried yet lets go at once
					local left = self._holdDuration - (Workspace:GetServerTimeNow() - pressedAt)
					if left > 0.02 and not self:blockedText() then
						latched = true
						task.delay(left + 0.05, function()
							if latched then
								release()
							end
						end)
					else
						release()
					end
				end
			end
		end)
	)
	self:_makeNudge(root)
	-- #2315: a player who puts the keyboard down and touches the screen gets the button at once, and back
	table.insert(
		self._connections,
		UserInputService.LastInputTypeChanged:Connect(function()
			if screenGui.Enabled then
				self:_paintInput()
			end
		end)
	)

	if parent then
		screenGui.Parent = parent
	end
	return self :: CatchPrompt
end

-- v0.5: why the cat cannot be grabbed yet, or nil when it can. "It's running!" while it sprints off after a miss
-- (FleeingUntil still ahead); "Cooling down Ns" (#2324) for the player who missed, until the retryAt the server sent
-- with CatchResult (F57: 3, 6, then 10 s after the stop by misses in a row; the server's own refusal for that wait is
-- "Catch your breath, then try again").
function CatchPrompt.blockedText(self: any): string?
	local now = Workspace:GetServerTimeNow()
	local fleeingUntil: number? = self._fleeingUntil
	if fleeingUntil ~= nil and now < fleeingUntil then
		return "It's running!"
	end
	local ownerTurnUntil: number? = self._ownerTurnUntil
	if ownerTurnUntil ~= nil and now < ownerTurnUntil then
		return OWNER_TURN
	end
	local retryAt: number? = self._retryAt
	if retryAt ~= nil and now < retryAt then
		return Cooldown.text(retryAt - now) -- #2324: "Cooling down 3s", ticking down (_countDown)
	end
	return nil
end

function CatchPrompt._actionText(self: any): string
	if self._kind == "rescue" then
		return "Rescue"
	elseif self._kind == "pickup" then
		return self:blockedText() or "Pick up"
	end
	return self:blockedText() or "Catch"
end

-- The resting look of the action line and the CATCH button: warn and grey while the cat runs.
function CatchPrompt._paintIdle(self: any, actionText: string?)
	local blocked = self:blockedText()
	self._action.Text = blocked or actionText or self:_actionText()
	self._action.TextColor3 = if blocked == "It's running!"
		then Theme.colors.warn
		elseif blocked then Theme.hud.subtext
		else Theme.hud.text
	self._grab.BackgroundColor3 = if blocked then Theme.colors.disabled else Theme.colors.good
	self:_paintNudge()
end

-- #2315: the big press-and-hold button on any sign of touch (Components/TouchPrompt), else the key cap and HOLD
function CatchPrompt._paintInput(self: any)
	local touch = TouchPrompt.wants(
		self._promptTouch,
		UserInputService:GetLastInputType().Name,
		Scale.isTouch()
	)
	self._keyFrame.Visible = not touch
	-- #2874 (console): the cap names the key of the input in hand, E on a keyboard and X on a gamepad
	local pad = string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
	self._keycap.Text = if pad
		then PromptKey.label("Gamepad", self._padKeyName or "ButtonX")
		else PromptKey.label("Keyboard", self._keyName or "E")
	self._holdTag.Visible = self._holdDuration > 0 and not touch
	self._grab.Visible = touch
	if touch then
		self:_placeGrab()
	end
	self:_paintNudge()
end

-- #2409: the touch button on the Net button's spot (Components/NetButtonPlace, in screen pixels), the same size, so
-- it never lands on the Net or jump buttons or the HUD's corner beside them
function CatchPrompt._placeGrab(self: any)
	local camera = Workspace.CurrentCamera
	local root: Frame = self._root
	local scale = self._uiScale.Scale
	if camera == nil or scale <= 0 or root.AbsoluteSize.Y <= 0 then
		return
	end
	local viewport = camera.ViewportSize
	local netAt, netSize = NetButtonPlace.place(viewport, JumpButton.read(viewport))
	-- #4307: a quarter bigger, grown left and evenly up and down from the Net button's spot (its right edge keeps the
	-- gap to the jump button), kept on screen
	local size = math.floor(netSize * GRAB_GROW + 0.5)
	local at = Vector2.new(
		math.clamp(netAt.X + netSize - size, 0, math.max(0, viewport.X - size)),
		math.clamp(netAt.Y - math.floor((size - netSize) / 2), 0, math.max(0, viewport.Y - size))
	)
	local inset = GuiService:GetGuiInset()
	local origin = root.AbsolutePosition + inset
	local grab: TextButton = self._grab
	grab.AnchorPoint = Vector2.zero
	grab.Position = UDim2.fromOffset((at.X - origin.X) / scale, (at.Y - origin.Y) / scale)
	grab.Size = UDim2.fromOffset(size / scale, size / scale)
	self:_placeNudge()
end

-- #4307: the bubble and the arrow (see the header), built once and hidden
function CatchPrompt._makeNudge(self: any, root: Frame)
	local nudge: Frame = Create("Frame", {
		Name = "CatchNudge",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), -- its parent's box (the root, or the card on a gamepad); _placeNudge sets the rest
		Visible = false,
		ZIndex = 50,
		Parent = root,
	})
	local bubble: TextLabel = Create("TextLabel", {
		Name = "Bubble",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.ink,
		Text = "Tap to catch!",
		ZIndex = 50,
		Parent = nudge,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIStroke", {
			Color = Theme.colors.outline,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	})
	-- the tutorial's own big gold arrow (drawn pointing down, bobbing toward its tip) in a box of its own
	local slot: Frame = Create("Frame", {
		Name = "ArrowSlot",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(NUDGE_ARROW, NUDGE_ARROW),
		Parent = nudge,
	})
	-- drawn for its direction (no Rotation, so every renderer shows it the same): a gold shaft and head with the dark
	-- outline, like the tutorial's arrow, bobbing toward its tip
	local arrow: Frame = Create("Frame", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 51,
		Parent = slot,
	})
	local shaft: Frame = Create("Frame", {
		Name = "Shaft",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		ZIndex = 51,
		Parent = arrow,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	Outline.border(shaft, 3)
	local head: TextLabel = Create("TextLabel", {
		Name = "Head",
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = NUDGE_ARROW - 8,
		TextColor3 = Theme.colors.gold,
		Text = "▶",
		ZIndex = 52,
		Parent = arrow,
	})
	Outline.text(head, 3)
	self._nudgeShaft = shaft
	self._nudgeHead = head
	self._nudgeBob = nil :: Tween?
	self._nudgeDir = nil :: string?
	-- a new word, or the card moved or popped in: place the bubble again
	local function again()
		if nudge.Visible and self._nudgeMode == "touch" then
			self:_placeNudge()
		end
	end
	local card: Frame = self._card
	local connections: { RBXScriptConnection } = self._connections
	table.insert(connections, bubble:GetPropertyChangedSignal("AbsoluteSize"):Connect(again))
	table.insert(connections, card:GetPropertyChangedSignal("AbsolutePosition"):Connect(again))
	table.insert(connections, card:GetPropertyChangedSignal("AbsoluteSize"):Connect(again))
	self._nudge = nudge
	self._nudgeBubble = bubble
	self._nudgeSlot = slot
	self._nudgeArrow = arrow
	self._nudgeMode = nil :: string?
	self._pulses = {} :: { Tween }
end

-- #4307: the words for the card's kind and the input in hand
function CatchPrompt.nudgeText(kind: Types.PromptKind, padKey: string?): string
	local verb = if kind == "rescue"
		then "rescue"
		elseif kind == "pickup" then "pick up"
		else "catch"
	if padKey ~= nil then
		return "Hold " .. padKey .. " to " .. verb .. "!"
	end
	return "Tap to " .. verb .. "!"
end

-- #4307: point the arrow "right" (at the touch button) or "down" (at the key cap), and bob it toward its tip
function CatchPrompt._pointNudge(self: any, dir: string)
	if self._nudgeDir == dir then
		return
	end
	self._nudgeDir = dir
	local arrow: Frame = self._nudgeArrow
	local shaft: Frame = self._nudgeShaft
	local head: TextLabel = self._nudgeHead
	local bob: Tween? = self._nudgeBob
	if bob then
		bob:Cancel()
	end
	arrow.Position = UDim2.fromOffset(0, 0)
	if dir == "right" then
		shaft.AnchorPoint = Vector2.new(0, 0.5)
		shaft.Position = UDim2.fromScale(0.04, 0.5)
		shaft.Size = UDim2.fromScale(0.5, 0.34)
		head.Text = "▶"
		head.AnchorPoint = Vector2.new(1, 0.5)
		head.Position = UDim2.fromScale(1, 0.5)
		head.Size = UDim2.fromScale(0.62, 1)
	else
		shaft.AnchorPoint = Vector2.new(0.5, 0)
		shaft.Position = UDim2.fromScale(0.5, 0.04)
		shaft.Size = UDim2.fromScale(0.34, 0.5)
		head.Text = "▼"
		head.AnchorPoint = Vector2.new(0.5, 1)
		head.Position = UDim2.fromScale(0.5, 1)
		head.Size = UDim2.fromScale(1, 0.62)
	end
	if GuiService.ReducedMotionEnabled then
		self._nudgeBob = nil
		return
	end
	local tween = TweenService:Create(
		arrow,
		BOB_INFO,
		{ Position = if dir == "right" then UDim2.fromOffset(BOB, 0) else UDim2.fromOffset(0, BOB) }
	)
	tween:Play()
	self._nudgeBob = tween
end

-- #4307: on touch the arrow sits left of the button, level with it, pointing right; the bubble goes left of the arrow,
-- or under it (then above it) where the left would lie on the catch card (a big screen's card reaches that far). On a
-- gamepad the arrow points down at the card's key cap, the bubble right of it.
function CatchPrompt._placeNudge(self: any)
	local nudge: Frame? = self._nudge
	if nudge == nil or not nudge.Visible then
		return
	end
	local bubble: TextLabel = self._nudgeBubble
	local slot: Frame = self._nudgeSlot
	local half = NUDGE_ARROW / 2
	if self._nudgeMode ~= "touch" then
		nudge.Parent = self._card
		slot.AnchorPoint = Vector2.new(0.5, 1)
		slot.Position = UDim2.fromOffset(34, -NUDGE_GAP)
		self:_pointNudge("down")
		bubble.AnchorPoint = Vector2.new(0, 0.5)
		bubble.Position = UDim2.fromOffset(34 + half + NUDGE_GAP, -NUDGE_GAP - half)
		return
	end
	nudge.Parent = self._root
	local grab: TextButton = self._grab
	local x = grab.Position.X.Offset
	local y = grab.Position.Y.Offset + grab.Size.Y.Offset / 2
	slot.AnchorPoint = Vector2.new(1, 0.5)
	local right = x - NUDGE_GAP - BOB -- the bob's reach stays off the button
	slot.Position = UDim2.fromOffset(right, y)
	self:_pointNudge("right")
	self._ripple.Position = UDim2.fromOffset(x + grab.Size.X.Offset / 2, y)
	-- the card's box and the bubble's size in the root's design px
	local root: Frame = self._root
	local scale = self._uiScale.Scale
	if scale <= 0 then
		scale = 1
	end
	local card: Frame = self._card
	local cardAt = (card.AbsolutePosition - root.AbsolutePosition) / scale
	local cardSize = card.AbsoluteSize / scale
	local size = bubble.AbsoluteSize / scale
	local w = if size.X > 0 then size.X else 170
	local h = if size.Y > 0 then size.Y else 40
	local rootH = root.AbsoluteSize.Y / scale
	local function clear(left: number, top: number): boolean
		if left < 0 or top < 0 or top + h > rootH then
			return false
		end
		return left >= cardAt.X + cardSize.X
			or left + w <= cardAt.X
			or top >= cardAt.Y + cardSize.Y
			or top + h <= cardAt.Y
	end
	local spots = {
		{ right - NUDGE_ARROW - NUDGE_GAP - w, y - h / 2 }, -- left of the arrow
		{ right - w, y + half + NUDGE_GAP }, -- under it
		{ right - w, y - half - NUDGE_GAP - h }, -- over it
	}
	local pick = spots[1]
	for _, spot in spots do
		if clear(spot[1], spot[2]) then
			pick = spot
			break
		end
	end
	bubble.AnchorPoint = Vector2.zero
	bubble.Position = UDim2.fromOffset(pick[1], pick[2])
end

function CatchPrompt._stopPulse(self: any)
	for _, tween in self._pulses do
		tween:Cancel()
	end
	table.clear(self._pulses)
	self._ripple.Visible = false
end

-- #4307: a gold ring ripples out of the button (still with Reduce Motion on: a still ring)
function CatchPrompt._startPulse(self: any)
	self:_stopPulse()
	local grab: TextButton = self._grab
	local ripple: Frame = self._ripple
	local size = grab.Size.X.Offset
	local ring = ripple:FindFirstChild("Ring") :: UIStroke
	ripple.Visible = true
	if GuiService.ReducedMotionEnabled then
		ripple.Size = UDim2.fromOffset(size + 12, size + 12)
		ring.Transparency = 0.2
		return
	end
	ripple.Size = UDim2.fromOffset(size, size)
	ring.Transparency = 0
	for _, tween in
		{
			TweenService:Create(
				ripple,
				RIPPLE_INFO,
				{ Size = UDim2.fromOffset(size * 1.5, size * 1.5) }
			),
			TweenService:Create(ring, RIPPLE_INFO, { Transparency = 1 }),
		}
	do
		tween:Play()
		table.insert(self._pulses, tween)
	end
end

-- #4307: show the nudge while the card can be pressed and the player hasn't yet this session
function CatchPrompt._paintNudge(self: any)
	local nudge: Frame? = self._nudge
	if nudge == nil then
		return
	end
	local mode: string? = nil
	if not self._nudged and self.screenGui.Enabled and self:blockedText() == nil then
		if self._grab.Visible then
			mode = "touch"
		elseif string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad" then
			mode = "pad"
		end
	end
	local was = self._nudgeMode
	self._nudgeMode = mode
	nudge.Visible = mode ~= nil
	if mode == nil then
		self:_stopPulse()
		return
	end
	self._nudgeBubble.Text = CatchPrompt.nudgeText(
		self._kind,
		if mode == "pad" then PromptKey.label("Gamepad", self._padKeyName or "ButtonX") else nil
	)
	self:_placeNudge()
	if mode == "touch" and (was ~= "touch" or #self._pulses == 0) then
		self:_startPulse()
	elseif mode ~= "touch" then
		self:_stopPulse()
	end
end

-- #4307: the first press this session; the nudge goes for good
function CatchPrompt._nudgeDone(self: any)
	if not self._nudged then
		self._nudged = true
		self:_paintNudge()
	end
end

function CatchPrompt.nudgeShowing(self: any): boolean
	return self._nudge ~= nil and self._nudge.Visible
end

-- for the gate's scenes: as if the player never pressed
function CatchPrompt.resetNudge(self: any)
	self._nudged = false
	self:_paintNudge()
end

-- #2409: the big touch button shows (the Net button stays away meanwhile)
function CatchPrompt.grabShowing(self: any): boolean
	return self.screenGui.Enabled and self._grab.Visible
end

function CatchPrompt.show(self: any, info: Types.CatchInfo)
	self._failToken += 1
	local kind: Types.PromptKind = info.kind or "swing"
	local rescue = kind == "rescue" -- a plain boolean: chained singleton tests confuse the type checker
	local pickUp = kind == "pickup"
	self._kind = kind
	self._fleeingUntil = if rescue then nil else info.fleeingUntil
	self._retryAt = if rescue then nil else info.retryAt
	self._ownerTurnUntil = if rescue then nil else info.ownerTurnUntil
	self:_paintIdle(info.actionText)
	self._grabLabel.Text = if rescue then "RESCUE" elseif pickUp then "PICK UP" else "CATCH"
	self._holdDuration = info.holdDuration or 0
	-- no charm stars after the name (F97 section 5: stars show nowhere now)
	self._catName.Text = info.catName or ""
	local rarity: string = info.rarity or "Common"
	self._rarity.Text = rarity
	self._rarity.BackgroundColor3 = Theme.rarityColor(rarity)
	self._rarity.TextColor3 = Theme.rarityTextColor(rarity)
	local blocked = self:blockedText()
	-- only a line that says why to wait; the rest is the picture
	local hint: string = if rescue
		then ""
		elseif pickUp and info.returning then "It's walking home. Grab it!"
		elseif pickUp then ""
		elseif blocked == OWNER_TURN then "Its owner gets the first try"
		elseif blocked == "It's running!" then "Wait till it stops"
		else ""
	-- #3529: a kind the player has never owned says so, unless the card has a reason to wait to give
	if hint == "" and not pickUp and info.newKind ~= nil then
		hint = info.newKind
	end
	self._hint.Text = hint
	self._hint.Visible = hint ~= ""
	self._card.Size = UDim2.fromOffset(CARD_W, if hint ~= "" then CARD_HINT_H else CARD_H)
	self._miniBar.Visible = rescue
	self._miniRing.Visible = not rescue and not pickUp
	local key: Enum.KeyCode = info.keyCode or Enum.KeyCode.E
	self._keyName = key.Name
	self._padKeyName = (info.gamepadKeyCode or Enum.KeyCode.ButtonX).Name -- #2874
	self._promptTouch = info.touch
	self:_paintInput()
	if not self.screenGui.Enabled then
		self.screenGui.Enabled = true
		Tween.popIn(self._card, 0.9)
	end
	self:_paintNudge() -- #4307: now the card is on
	if blocked then
		self:_countDown(self._failToken)
		-- turn back to Catch the moment it may be tried, unless anything else changed the card first
		local token = self._failToken
		local ready =
			math.max(self._fleeingUntil or 0, self._retryAt or 0, self._ownerTurnUntil or 0)
		task.delay(ready - Workspace:GetServerTimeNow() + 0.05, function()
			if self._failToken == token and self.screenGui.Enabled then
				self:show(info)
			end
		end)
	end
end

-- #2324: while the miss cooldown runs, repaint the action line each time its seconds go down by one ("Cooling down
-- 3s", "2s", "1s"); show() puts Catch back when it ends. Stops when anything else changes the card (the token).
function CatchPrompt._countDown(self: any, token: number)
	local retryAt: number? = self._retryAt
	local left = if retryAt ~= nil then retryAt - Workspace:GetServerTimeNow() else 0
	if left <= 0 then
		return
	end
	task.delay(Cooldown.nextTick(left) + 0.02, function()
		if self._failToken == token and self.screenGui.Enabled then
			self:_paintIdle(nil)
			self:_countDown(token)
		end
	end)
end

-- retry = true keeps the prompt open: Commons and lured strays, or a rescue the server turned down for
-- now ("Someone else is rescuing it"). Otherwise the card flashes the reason and hides, which is what a
-- fleeing cat looks like.
function CatchPrompt.fail(self: any, reason: string?, retry: boolean?)
	self._failToken += 1
	local token = self._failToken
	local fallback = if retry then "Missed, try again" else "It got away"
	self._action.Text = reason or fallback
	self._action.TextColor3 = Theme.colors.warn
	task.delay(if retry then 1.4 else 0.9, function()
		if self._failToken ~= token then
			return
		end
		if retry then
			self:_paintIdle(nil)
			self:_countDown(token)
		else
			self:hide()
		end
	end)
end

-- The hold began: fill the key cap and the CATCH button over the prompt's HoldDuration.
function CatchPrompt.holdStart(self: any)
	self:_nudgeDone() -- #4307: E, X or the button: the player found it
	local duration: number = self._holdDuration
	if duration <= 0 or self:blockedText() then
		return
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	self._keyFill.Size = UDim2.fromScale(1, 0)
	self._grabFill.Size = UDim2.fromScale(0, 0)
	Tween.to(self._keyFill, info, { Size = UDim2.fromScale(1, 1) })
	Tween.to(self._grabFill, info, { Size = UDim2.fromScale(1, 1) })
end

-- Let go before the hold finished, or the hold triggered: drain both fills.
function CatchPrompt.holdStop(self: any)
	Tween.to(self._keyFill, Tween.FAST, { Size = UDim2.fromScale(1, 0) })
	Tween.to(self._grabFill, Tween.FAST, { Size = UDim2.fromScale(0, 0) })
end

-- The press went to the server; dim the card until the circles or the minigame come.
function CatchPrompt.waiting(self: any)
	self:_nudgeDone()
	self:holdStop()
	self._failToken += 1
	self._action.Text = if self._kind == "pickup" then "Picking up..." else "Get ready..."
	self._action.TextColor3 = Theme.hud.subtext
end

function CatchPrompt.hide(self: any)
	self._failToken += 1
	self._keyFill.Size = UDim2.fromScale(1, 0)
	self._grabFill.Size = UDim2.fromScale(0, 0)
	self.screenGui.Enabled = false
	self:_paintNudge()
end

function CatchPrompt.setClear(self: any, top: number?)
	local foot = CatchPrompt.foot(top)
	if foot ~= self._foot then
		self._foot = foot
		self._card.Position = UDim2.new(0.5, 0, 1, foot)
	end
end

function CatchPrompt.isVisible(self: any): boolean
	return self.screenGui.Enabled
end

function CatchPrompt.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self.holdBegan:DisconnectAll()
	self.holdEnded:DisconnectAll()
	Scale.unbind(self._uiScale)
	self.screenGui:Destroy()
end

return CatchPrompt
