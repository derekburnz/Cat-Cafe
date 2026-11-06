--!strict
-- The crate reel (F103, crate-reel.md section 2) over the Golden Fish Market window: a strip of square tiles slides
-- right to left under a gold marker and lands dead centre on the won piece, the same distance at the same speeds
-- every time (Components/CrateReelLogic). Seven tiles show at once, each in its rarity colour with the piece's own
-- clean decor picture (#1457, the friend 11-05: "a lot of empty panes use actual decor possibilities as shown
-- squares"; before, the fast part showed only a kind glyph and paints their bare swatch). A piece with no picture yet
-- shows its 3D model on the tiles in view at the stop (CrateReelProtectFrom on, never rarer than the prize) and its
-- kind glyph elsewhere. At the stop the marker pulses in the won rarity's
-- colour (a Legendary or Mythical landing tile glows too), and after CrateReelHoldSeconds `onDone` shows the prize
-- card. A tap anywhere skips straight to the landing.
--
-- The server rolled and paid before the reel starts; this only shows it and sends nothing. It fires the client's
-- Moments.CrateReelTick at each tile line that passes the marker (at most one every 0.06 s, Sound-Agent's ticks) and
-- Moments.CrateReelLanded(rarity) at the stop or the skip with the won piece's rarity (Effects/Market opens the
-- counter crate's lid then; Audio plays the rarity sting for Epic and up), when Moments has them.

local RunService = game:GetService("RunService")

local CrateReelLogic = require(script.Parent.Parent.Components.CrateReelLogic)
local Create = require(script.Parent.Parent.Components.Create)
local DecorPieces = require(script.Parent.Parent.Components.DecorPieces)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

local Moments = require(script.Parent.Parent.Parent.Moments) :: any

export type Play = {
	tiles: { CrateReelLogic.Tile },
	timing: CrateReelLogic.Timing,
	decorById: { [string]: Types.DecorDef },
	onLanded: () -> (), -- at the stop, or at once on a skip
	onDone: () -> (), -- CrateReelHoldSeconds later: the prize card
}

export type CrateReel = {
	cover: TextButton,
	playing: (self: CrateReel) -> boolean,
	play: (self: CrateReel, play: Play) -> (),
	skip: (self: CrateReel) -> (),
	stop: (self: CrateReel) -> (),
	destroy: (self: CrateReel) -> (),
}

local TILE = 76
local GAP = 6
local STEP = TILE + GAP
local IN_VIEW = 7
local VIEW_W = IN_VIEW * STEP - GAP
local PAD = 10
local NOTCH = 16
local TICK_GAP = 0.06 -- seconds: at most one tick this often
local Z = 36 -- over the Market's cards (up to 23), under the prize card's cover (30 to 34 sits under it once shown)

local CrateReel = {}
CrateReel.__index = CrateReel

local function fire(name: string, ...: any)
	local moment = Moments[name]
	if moment ~= nil then
		moment:Fire(...)
	end
end

function CrateReel.new(parent: GuiObject): CrateReel
	local self = setmetatable({}, CrateReel) :: any
	self._token = 0
	self._play = nil :: Play?
	self._views = {} :: { Frame }
	self._icons = {} :: { ItemIcon.ItemIcon }
	self._loop = nil :: RBXScriptConnection?

	local cover: TextButton = Create("TextButton", {
		Name = "ReelCover",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Z,
		Visible = false,
		Parent = parent,
	})
	self.cover = cover
	local box: Frame = Create("Frame", {
		Name = "Reel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(VIEW_W + PAD * 2, TILE + PAD * 2 + NOTCH * 2),
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		ZIndex = Z + 1,
		Parent = cover,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(box, Theme.sizes.outline, Theme.colors.gold)
	-- shrinks to fit a narrow window (a phone)
	self._scale = Create("UIScale", { Parent = box }) :: UIScale
	local window: Frame = Create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(VIEW_W, TILE),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = Z + 2,
		Parent = box,
	})
	self._window = window
	self._strip = Create("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(STEP * 40, TILE),
		ZIndex = Z + 2,
		Parent = window,
	}) :: Frame
	-- the marker: a gold notch above and below the middle, and a faint line between them
	local function notch(name: string, y: number, anchorY: number): Frame
		return Create("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, anchorY),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(NOTCH, NOTCH),
			Rotation = 45,
			BackgroundColor3 = Theme.colors.gold,
			BorderSizePixel = 0,
			ZIndex = Z + 4,
			Parent = box,
		})
	end
	self._notches = {
		notch("NotchTop", PAD + NOTCH - 2, 1),
		notch("NotchBottom", PAD + NOTCH + TILE + 2, 0),
	}
	self._line = Create("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, TILE + 8),
		BackgroundColor3 = Theme.colors.gold,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = Z + 4,
		Parent = box,
	}) :: Frame

	cover.Activated:Connect(function()
		self:skip()
	end)
	self._resize = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_fit()
	end)
	return self :: CrateReel
end

function CrateReel._fit(self: any)
	local width = self.cover.AbsoluteSize.X
	local natural = VIEW_W + PAD * 2 + 16
	self._scale.Scale = if width > 0 and width < natural then width / natural else 1
end

function CrateReel.playing(self: any): boolean
	return self._play ~= nil
end

function CrateReel._clear(self: any)
	for _, icon in self._icons do
		icon:destroy()
	end
	table.clear(self._icons)
	for _, view in self._views do
		view:Destroy()
	end
	table.clear(self._views)
end

function CrateReel._build(self: any, play: Play)
	self:_clear()
	local timing = play.timing
	self._strip.Size = UDim2.fromOffset(STEP * #play.tiles, TILE)
	-- #1728: the Market fetched these when it opened; any still missing start now, before the tiles ask one by one
	local images: { string } = {}
	for _, tile in play.tiles do
		local picture = ShopIcons.decor(tile.id)
		if picture then
			table.insert(images, picture)
		end
	end
	IconArt.preload(images)
	for index, tile in play.tiles do
		local decor: Types.DecorDef? = play.decorById[tile.id]
		local piece = DecorPieces.info(decor)
		local color = Theme.rarityColor(tile.rarity)
		local view: Frame = Create("Frame", {
			Name = "Tile" .. index,
			Position = UDim2.fromOffset((index - 1) * STEP, 0),
			Size = UDim2.fromOffset(TILE, TILE),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = Z + 2,
			Parent = self._strip,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }) })
		Outline.border(view, 3, color:Lerp(Theme.colors.ink, 0.35))
		local glyph = DecorPieces.kindIcon(piece.kind, Theme.icons.decor)
		local picture = ShopIcons.decor(tile.id)
		local near = index >= timing.protectFrom
			and index <= math.min(#play.tiles, timing.landing + 4)
		if picture or near then
			-- the piece's clean picture on every tile; the 3D model only for a piece without one, in view at the stop
			local icon = ItemIcon.new({
				parent = view,
				name = "Icon",
				size = UDim2.new(1, -10, 1, -10),
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
			})
			icon.frame.ZIndex = Z + 3
			icon:set(if decor and near then decor.asset else nil, glyph, tile.rarity, picture)
			table.insert(self._icons, icon)
		else
			Create("TextLabel", {
				Name = "Glyph",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Theme.fonts.display,
				TextSize = math.floor(TILE * 0.5),
				Text = glyph,
				ZIndex = Z + 3,
				Parent = view,
			})
		end
		table.insert(self._views, view)
	end
end

-- Puts the tile `at` (a number, 1 = the first tile's centre) under the marker.
function CrateReel._place(self: any, at: number)
	self._strip.Position =
		UDim2.fromOffset(math.floor(VIEW_W / 2 - ((at - 1) * STEP + TILE / 2) + 0.5), 0)
end

function CrateReel.play(self: any, play: Play)
	self:stop()
	self._token += 1
	local token = self._token
	self._play = play
	self._landed = false
	self:_build(play)
	self:_fit()
	for _, part in self._notches do
		part.BackgroundColor3 = Theme.colors.gold
	end
	self._line.BackgroundColor3 = Theme.colors.gold
	self.cover.Visible = true
	local timing = play.timing
	local elapsed = 0
	local last = 1
	local lastTick = -math.huge
	self:_place(1)
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		if self._token ~= token then
			return
		end
		elapsed += dt
		local at = CrateReelLogic.position(elapsed, timing)
		self:_place(at)
		if CrateReelLogic.crossed(last, at) > 0 and elapsed - lastTick >= TICK_GAP then
			lastTick = elapsed
			fire("CrateReelTick")
		end
		last = at
		if elapsed >= timing.stop then
			self:_land(token)
		end
	end)
end

-- The stop (or a skip): the won tile dead centre, the marker pulsing in its colour, the prize card a moment later.
function CrateReel._land(self: any, token: number)
	local play: Play? = self._play
	if play == nil or self._token ~= token or self._landed then
		return
	end
	self._landed = true
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	local timing = play.timing
	self:_place(timing.landing)
	local won = play.tiles[timing.landing]
	local color = Theme.rarityColor(if won then won.rarity else nil)
	for _, part in self._notches do
		part.BackgroundColor3 = color
		Tween.popIn(part, 0.6)
	end
	self._line.BackgroundColor3 = color
	local tile = self._views[timing.landing]
	if tile and won and (won.rarity == "Legendary" or won.rarity == "Mythical") then
		-- the landing tile glows in its rarity colour; nothing hinted at it before the stop
		local glow = tile:FindFirstChildOfClass("UIStroke")
		if glow then
			glow.Color = Theme.colors.white
			glow.Thickness = 5
		end
	end
	fire("CrateReelLanded", if won then won.rarity else nil)
	play.onLanded()
	task.delay(timing.hold, function()
		if self._token == token and self._play == play then
			self._play = nil
			self.cover.Visible = false
			play.onDone()
		end
	end)
end

function CrateReel.skip(self: any)
	if self._play ~= nil and not self._landed then
		self:_land(self._token)
	end
end

-- Stops without the prize card (the window closed, or a newer open).
function CrateReel.stop(self: any)
	self._token += 1
	self._play = nil
	if self._loop then
		self._loop:Disconnect()
		self._loop = nil
	end
	self.cover.Visible = false
end

function CrateReel.destroy(self: any)
	self:stop()
	self._resize:Disconnect()
	self:_clear()
	self.cover:Destroy()
end

return CrateReel
