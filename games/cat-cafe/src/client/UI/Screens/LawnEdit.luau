--!strict
-- The front lawn's edit view (F91, front-lawn.md section 3). Edit lawn in the Decor screen's Front lawn tab swings the
-- camera to a view of the player's cafe front and shows a ring over each lawn spot: a "+" on an open empty spot, a
-- pencil on one with a piece, a lock and "Tier 3" on a spot the cafe has not opened yet. Tapping a ring opens the
-- picker along the bottom: the piece on that spot, the other pieces of its size the player owns (Place, or Move here
-- when it stands elsewhere), then the shop's (buying one puts it right there) and the ones a later tier sells. Clear
-- spot empties it and keeps the piece. Done goes back to the Decor screen; walking more than WALK_OFF studs away
-- (keyboard or gamepad), or the character going, ends the view without it. The HUD and Roblox's touch controls (the
-- thumbstick and jump button) hide while the view is up, so the picker's buttons are never under a thumb (review S121).
--
--   bind(plot)       the player's own plot (UI.richTip.bind passes it); its LawnSpots/<spotId> parts carry the rings
--   canStart()       true, or false and the line to toast (no plot or character yet, or too far from the cafe)
--   start()          the camera and rings; false when canStart says no
--   pick(spotId)     opens the picker for a spot (a ring's tap)
--   stop(reopen)     the camera back to the player; `reopen` asks for the Decor screen again (Done)
--
-- Roblox terms: a Scriptable camera stays where the script puts it until CameraType goes back to Custom, when
-- Roblox's own camera script follows the character again. GuiService.TouchControlsEnabled = false hides the phone's
-- thumbstick and jump button until it is set back. Each ring is a BillboardGui (2D UI drawn at a 3D point)
-- adorned to its spot's part, Active so its button takes taps.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local LawnLogic = require(script.Parent.Parent.Components.LawnLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	buyLawn: (id: string, spotId: string?) -> (),
	setLawnSpot: (spotId: string, pieceId: string) -> (), -- "" clears the spot
	shown: (editing: boolean) -> (), -- the view opened or closed: init hides the HUD while it is up
	done: () -> (), -- Done: init opens the Decor screen on its Front lawn tab
}

export type LawnEdit = {
	bind: (self: LawnEdit, plot: Instance?) -> (),
	render: (self: LawnEdit, state: Types.PlayerState) -> (),
	canStart: (self: LawnEdit) -> (boolean, string?),
	start: (self: LawnEdit) -> boolean,
	pick: (self: LawnEdit, spotId: string?) -> (),
	stop: (self: LawnEdit, reopen: boolean) -> (),
	isEditing: (self: LawnEdit) -> boolean,
	destroy: (self: LawnEdit) -> (),
}

local RANGE = 80 -- studs from the lawn's middle the character may be to start
local WALK_OFF = 14 -- studs walked from where the view started that end it
local CHECK_STEP = 0.2 -- seconds between walk-off checks
local SWING = 0.6 -- seconds the camera takes to swing over
local PIECE_RADIUS = 3 -- studs past a spot's centre the framing keeps in view
local LOOK_AHEAD = 4 -- studs toward the camera the view aims, so the lawn sits above the picker

local RING = 64
local RING_LABEL_H = 26
local BAR_W = 560
local BAR_H = 64
local PICK_CARD_W = 160
local DONE_W = 120

local LawnEdit = {}
LawnEdit.__index = LawnEdit

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root :: BasePart else nil
end

function LawnEdit.new(parent: Instance, callbacks: Callbacks): LawnEdit
	local self = setmetatable({}, LawnEdit) :: any
	self._callbacks = callbacks
	self._plot = nil :: Instance?
	self._state = nil :: Types.PlayerState?
	self._editing = false
	self._picked = nil :: string?
	self._rings = {} :: { [string]: any }
	self._pickCards = {} :: { any }
	self._loop = nil :: RBXScriptConnection?
	self._from = nil :: Vector3?
	self._cameraType = Enum.CameraType.Custom
	self._touchControls = true -- GuiService.TouchControlsEnabled before the view, put back by stop
	self._actionHeight = Scale.tapHeight(Theme.sizes.touchMin, Theme.sizes.buttonDepth)
	self._parent = parent
	-- the picker's header: room for Clear spot and the close X at a full tap height
	local header = self._actionHeight + 12

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeLawnEdit",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 16, -- over the HUD (10 to 15), under the windows (20) and toasts (30)
		Enabled = false,
		Parent = parent,
	})
	self._screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	-- the bar along the top: what to do, and Done
	local bar: Frame = Create("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -24, 0, BAR_H),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(BAR_W, BAR_H) }),
	})
	Outline.border(bar)
	text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -(DONE_W + 40), 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Text = "Edit lawn",
		Parent = bar,
	})
	text({
		Name = "Hint",
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -(DONE_W + 40), 0, 20),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = "Tap a ring to choose what goes there.",
		Parent = bar,
	})
	self._done = Button.new({
		name = "Done",
		text = "Done",
		style = "gold",
		size = UDim2.fromOffset(DONE_W, BAR_H - 16),
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = bar,
		onClick = function()
			self:stop(true)
		end,
	})

	-- the picker along the bottom, for the spot whose ring was tapped
	local pickH = header + 76 + 26 + self._actionHeight + 30
	local picker: Frame = Create("Frame", {
		Name = "Picker",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, pickH),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(780, pickH) }),
	})
	Outline.border(picker)
	self._picker = picker
	self._pickTitle = text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -(self._actionHeight + 170), 0, header - 12),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		Parent = picker,
	})
	self._clear = Button.new({
		name = "Clear",
		text = "Clear spot",
		style = "ghost",
		size = UDim2.fromOffset(130, self._actionHeight),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(self._actionHeight + 14), 0, 6),
		textSize = Theme.sizes.textSmall,
		parent = picker,
		onClick = function()
			local spotId = self._picked
			if spotId ~= nil then
				callbacks.setLawnSpot(spotId, "")
			end
		end,
	})
	self._close = Button.new({
		name = "Close",
		text = "✕",
		style = "ghost",
		size = UDim2.fromOffset(self._actionHeight, self._actionHeight),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -6, 0, 6),
		textSize = Theme.sizes.textBody,
		parent = picker,
		onClick = function()
			self:pick(nil)
		end,
	})
	self._row = Create("ScrollingFrame", {
		Name = "Row",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, header),
		Size = UDim2.new(1, -24, 1, -(header + 8)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.colors.caramel,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = picker,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.sizes.gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingBottom = UDim.new(0, 6) }),
	})

	-- a ring for each lawn spot; adorned once a plot is bound
	for _, spot in LawnLogic.SPOTS do
		self:_ring(spot)
	end

	return self :: LawnEdit
end

function LawnEdit._ring(self: any, spot: Types.LawnSpot)
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeLawnRing_" .. spot.id,
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = 200,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(120, RING + RING_LABEL_H + 6),
		StudsOffset = Vector3.new(0, 0.6, 0),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._parent,
	})
	local disc: TextButton = Create("TextButton", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(RING, RING),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.colors.paper,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		FontFace = Theme.fonts.display,
		TextSize = 34,
		TextColor3 = Theme.colors.goldDark,
		Text = "+",
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	local stroke: UIStroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.colors.gold,
		Thickness = 4,
		Parent = disc,
	})
	local label = text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, RING + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, RING_LABEL_H),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.outline,
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = billboard,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = label })
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = label,
	})
	local connection = disc.Activated:Connect(function()
		local state: Types.PlayerState? = self._state
		if state ~= nil and state.tier >= spot.tier then
			self:pick(if self._picked == spot.id then nil else spot.id)
		end
	end)
	self._rings[spot.id] = {
		spot = spot,
		billboard = billboard,
		disc = disc,
		stroke = stroke,
		label = label,
		connection = connection,
	}
end

function LawnEdit.bind(self: any, plot: Instance?)
	if plot == self._plot then
		return
	end
	if self._editing then
		self:stop(false)
	end
	self._plot = plot
	for id, ring in self._rings do
		ring.billboard.Adornee = self:_anchor(id)
	end
end

-- The spot's part under the plot's LawnSpots folder, or nil.
function LawnEdit._anchor(self: any, spotId: string): BasePart?
	local plot: Instance? = self._plot
	local folder = if plot ~= nil then plot:FindFirstChild("LawnSpots") else nil
	local part = if folder ~= nil then folder:FindFirstChild(spotId) else nil
	return if part ~= nil and part:IsA("BasePart") then part :: BasePart else nil
end

-- The middle of every lawn spot, the way to the street and the half width to keep in view, or nil without anchors.
function LawnEdit._lawnFrame(self: any): (Vector3?, CFrame?, number)
	local sum = Vector3.zero
	local count = 0
	local basis: CFrame? = nil
	for _, spot in LawnLogic.SPOTS do
		local part = self:_anchor(spot.id)
		if part ~= nil then
			sum += part.Position
			count += 1
			basis = basis or part.CFrame
		end
	end
	if count == 0 or basis == nil then
		return nil, nil, 0
	end
	local middle = sum / count
	local frame = CFrame.fromMatrix(middle, basis.RightVector, basis.UpVector)
	local half = 0
	for _, spot in LawnLogic.SPOTS do
		local part = self:_anchor(spot.id)
		if part ~= nil then
			half = math.max(half, math.abs(frame:PointToObjectSpace(part.Position).X))
		end
	end
	return middle, frame, half + PIECE_RADIUS
end

function LawnEdit.canStart(self: any): (boolean, string?)
	local middle = self:_lawnFrame()
	local state: Types.PlayerState? = self._state
	if middle == nil or state == nil then
		return false, "Your lawn is not ready yet."
	end
	-- no character (respawning): the walk-off check has nowhere to measure from (review N342)
	local root = rootPart()
	if root == nil then
		return false, "Wait a moment, then try again."
	end
	if (root.Position - middle).Magnitude > RANGE then
		return false, "Walk to your cafe to edit the lawn."
	end
	return true, nil
end

function LawnEdit.start(self: any): boolean
	if self._editing then
		return true
	end
	local ok = self:canStart()
	local middle, frame, half = self:_lawnFrame()
	local camera = Workspace.CurrentCamera
	if not ok or middle == nil or frame == nil or camera == nil then
		return false
	end
	self._editing = true
	local root = rootPart()
	self._from = if root ~= nil then root.Position else nil
	-- the phone's thumbstick and jump button hide, so the picker's buttons are clear of them; Done ends the view
	self._touchControls = GuiService.TouchControlsEnabled
	GuiService.TouchControlsEnabled = false
	-- the camera: back toward the street and up, far enough that every spot fits the screen's width
	local viewport = camera.ViewportSize
	local aspect = if viewport.Y > 0 then viewport.X / viewport.Y else 16 / 9
	local back = LawnLogic.editDistance(half, camera.FieldOfView, aspect)
	local street = frame.LookVector -- the plot's -Z, out of the front door to the street
	local eye = middle + street * back + frame.UpVector * (back * LawnLogic.EDIT_RISE)
	local target = middle + street * LOOK_AHEAD
	local goal = CFrame.lookAt(eye, target)
	self._cameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	if GuiService.ReducedMotionEnabled then
		camera.CFrame = goal
	else
		local swing = TweenService:Create(
			camera,
			TweenInfo.new(SWING, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = goal }
		)
		swing:Play()
		self._swing = swing
	end
	self._screenGui.Enabled = true
	self:_renderRings()
	self._callbacks.shown(true)
	local waited = 0
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		waited += dt
		if waited < CHECK_STEP then
			return
		end
		waited = 0
		local from: Vector3? = self._from
		local now = rootPart()
		if from == nil or now == nil or (now.Position - from).Magnitude > WALK_OFF then
			self:stop(false)
		end
	end)
	return true
end

function LawnEdit.stop(self: any, reopen: boolean)
	if not self._editing then
		return
	end
	self._editing = false
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local swing: Tween? = self._swing
	if swing then
		swing:Cancel()
		self._swing = nil
	end
	GuiService.TouchControlsEnabled = self._touchControls
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = if self._cameraType == Enum.CameraType.Scriptable
			then Enum.CameraType.Custom
			else self._cameraType
	end
	self:pick(nil)
	self._screenGui.Enabled = false
	for _, ring in self._rings do
		ring.billboard.Enabled = false
	end
	self._callbacks.shown(false)
	if reopen then
		self._callbacks.done()
	end
end

function LawnEdit.isEditing(self: any): boolean
	return self._editing
end

-- Each ring from the state: hidden without its part; a lock and the tier on a closed spot; "+" and the spot's size on
-- an empty one; a pencil and the piece's name on a filled one; white round the one being picked for.
function LawnEdit._renderRings(self: any)
	local state: Types.PlayerState? = self._state
	local lawn = if state ~= nil then state.lawn or {} else {}
	for id, ring in self._rings do
		local spot: Types.LawnSpot = ring.spot
		ring.billboard.Enabled = self._editing and ring.billboard.Adornee ~= nil
		local open = state ~= nil and state.tier >= spot.tier
		local pieceId = lawn[id]
		local piece = if pieceId ~= nil then LawnLogic.getPiece(pieceId) else nil
		local picked = self._picked == id
		ring.disc.Active = open
		ring.disc.Text = if not open then Theme.icons.lock elseif piece ~= nil then "✏️" else "+"
		ring.disc.TextSize = if open and piece == nil then 34 else 24
		ring.disc.BackgroundColor3 = if open then Theme.colors.paper else Theme.colors.disabled
		ring.stroke.Color = if picked
			then Theme.colors.white
			elseif open then Theme.colors.gold
			else Theme.colors.disabledDark
		ring.stroke.Thickness = if picked then 6 else 4
		ring.label.Text = if not open
			then ("Tier %d"):format(spot.tier)
			elseif piece ~= nil then piece.name
			else LawnLogic.sizeName(spot.size)
	end
end

-- The picker for `spotId`, or closed with nil.
function LawnEdit.pick(self: any, spotId: string?)
	local spot = if spotId ~= nil then LawnLogic.getSpot(spotId) else nil
	local state: Types.PlayerState? = self._state
	if spot == nil or state == nil or not self._editing then
		self._picked = nil
		self._picker.Visible = false
		self:_renderRings()
		return
	end
	local opening = self._picked ~= spotId
	self._picked = spotId
	self:_renderPicker()
	self:_renderRings()
	if opening then
		self._row.CanvasPosition = Vector2.zero
		self._picker.Visible = true
		Tween.popIn(self._picker, 0.92)
	end
end

function LawnEdit._clearCards(self: any)
	for _, card in self._pickCards do
		card.icon:destroy()
		card.button:destroy()
		card.frame:Destroy()
	end
	table.clear(self._pickCards)
end

function LawnEdit._renderPicker(self: any)
	local spotId: string? = self._picked
	local state: Types.PlayerState? = self._state
	local spot = if spotId ~= nil then LawnLogic.getSpot(spotId) else nil
	if spotId == nil or spot == nil or state == nil then
		return
	end
	local lawn = state.lawn or {}
	local here = lawn[spotId]
	local herePiece = if here ~= nil then LawnLogic.getPiece(here) else nil
	self._pickTitle.Text = if herePiece
		then ("%s: %s"):format(LawnLogic.sizeName(spot.size), herePiece.name)
		else LawnLogic.sizeName(spot.size)
	self._clear.instance.Visible = herePiece ~= nil
	self:_clearCards()
	local callbacks: Callbacks = self._callbacks
	for order, choice in LawnLogic.spotChoices(state, spotId) do
		local piece = choice.piece
		local action = choice.action
		local card: Frame = Create("Frame", {
			Name = piece.id,
			LayoutOrder = order,
			BackgroundColor3 = Theme.modal.card,
			BorderSizePixel = 0,
			Size = UDim2.new(0, PICK_CARD_W, 1, 0),
			Parent = self._row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
			Create("UIStroke", {
				Color = if action.mode == "here" then Theme.colors.gold else Theme.modal.cardStroke,
				Thickness = if action.mode == "here"
					then Theme.sizes.stroke + 1
					else Theme.sizes.stroke,
			}),
		})
		local icon = ItemIcon.new({
			parent = card,
			size = UDim2.fromOffset(72, 72),
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 6),
		})
		icon:set(piece.model, "🌷", nil)
		text({
			Name = "Name",
			Position = UDim2.fromOffset(8, 80),
			Size = UDim2.new(1, -16, 0, 22),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textSmall + 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = piece.name,
			Parent = card,
		})
		local button = Button.new({
			name = "Action",
			text = action.text,
			style = action.style :: any,
			size = UDim2.new(1, -16, 0, self._actionHeight),
			position = UDim2.new(0, 8, 1, -(self._actionHeight + 8)),
			textSize = Theme.sizes.textSmall + 1,
			enabled = action.enabled,
			parent = card,
			onClick = function()
				if not action.enabled then
					return
				end
				if action.mode == "buy" then
					callbacks.buyLawn(piece.id, spotId)
				elseif action.mode == "place" then
					callbacks.setLawnSpot(spotId, piece.id)
				end
			end,
		})
		table.insert(self._pickCards, { frame = card, icon = icon, button = button })
	end
end

function LawnEdit.render(self: any, state: Types.PlayerState)
	self._state = state
	if not self._editing then
		return
	end
	self:_renderRings()
	if self._picked ~= nil then
		self:_renderPicker()
	end
end

function LawnEdit.destroy(self: any)
	self:stop(false)
	self:_clearCards()
	for _, ring in self._rings do
		ring.connection:Disconnect()
		ring.billboard:Destroy()
	end
	self._done:destroy()
	self._clear:destroy()
	self._close:destroy()
	Scale.unbind(self._uiScale)
	self._screenGui:Destroy()
end

return LawnEdit
