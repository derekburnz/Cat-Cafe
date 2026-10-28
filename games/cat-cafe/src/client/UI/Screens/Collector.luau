--!strict
-- The Cat Collector's card (F63, data-model section 12b, Gavin's round 3 Q6). By day he sometimes comes to your cafe
-- and waits by the counter for 3 minutes, asking for one of your resting, unlocked cats. The server toasts that he
-- came; the rest is here, on the owner's screen only, kept brief (Derek 2026-10-28 01:09):
--   * a tag over him, outlined text with no box: "🧐 Cat Collector" and the time he has left. A tap opens his card.
--   * his card, opened by walking within CollectorRangeStuds (12) of him and closed a stud past it, like the code
--     box: the cat he wants (its picture, its name and "Gold Rare"), an arrow, his offer as little pictures
--     (Components/PrizeChips), "Your Index keeps this cat", and No thanks and Trade.
-- Trade asks for a second tap from Rare up and for a gold cat ("Tap again to trade"), as Sell does. A press fires
-- `answer(accept)` and greys both buttons until the visit ends (CollectorOffer "") or 3 s pass, since a refused
-- trade is the server's toast and he waits on. Away from him the buttons read "Walk closer". X closes the card until
-- the player walks away and back, or taps the tag. A trade plays uiTrade; the server's toast says what it paid.
--
--   bind(plot)                               your own plot model, for its CollectorSpot; nil stops
--   offer(catUid, offer?, endsAt, traded?)   from CollectorOffer; catUid "" ends the visit
--
-- Roblox terms: the tag is a BillboardGui on an Attachment this client puts in Terrain over the spot, so it needs
-- nothing from his model (CustomerController's), which streams in and out.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local CatVariant = require(script.Parent.Parent.Components.CatVariant)
local CollectorLogic = require(script.Parent.Parent.Components.CollectorLogic)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

export type Callbacks = {
	answer: (accept: boolean) -> (),
	open: (force: boolean) -> (), -- open the card's window; unless forced (a tap on the tag), not over another one
	close: () -> (), -- close the card's window if it is the open one
}

export type Collector = {
	frame: Frame,
	setCatalog: (self: Collector, catalog: Types.Catalog) -> (),
	render: (self: Collector, state: Types.PlayerState) -> (),
	bind: (self: Collector, plot: Instance?) -> (),
	offer: (
		self: Collector,
		catUid: string,
		offer: Types.CollectorOffer?,
		endsAt: number,
		traded: boolean?
	) -> (),
	onOpen: (self: Collector) -> (),
	onClose: (self: Collector) -> (),
	destroy: (self: Collector) -> (),
}

type Visit = { catUid: string, offer: Types.CollectorOffer, endsAt: number }

local NOTE = "Your Index keeps this cat"
local MAX_SIZE = Vector2.new(440, 320)
local LEFT_WIDTH = 140 -- the cat's picture, name and rarity
local ART = 100
local NAME_HEIGHT = 22
local LINE_HEIGHT = 18
local ARROW_WIDTH = 40
local TILE = 52 -- an offer picture
local NOTE_HEIGHT = 20
local ROW = 50 -- No thanks and Trade
local GAP = Theme.sizes.gap
local PENDING_SECONDS = 3
local CONFIRM_SECONDS = 3
local CHECK_SECONDS = 0.25 -- how often the range check and the timers run while he is here
local TAG_OFFSET = 4 -- studs over the spot; he sits, and his bowler tops out at 2.7 (Model-Agent #532)
local TAG_DISTANCE = 120

local Collector = {}
Collector.__index = Collector

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

function Collector.new(parent: Instance, callbacks: Callbacks): Collector
	local self = setmetatable({}, Collector) :: any
	self._callbacks = callbacks
	self._alive = true
	self._catById = {} :: { [string]: Types.CatDef }
	self._state = nil :: Types.PlayerState?
	self._plot = nil :: Model?
	self._visit = nil :: Visit?
	self._near = false
	self._dismissed = false -- X closed the card while near: it waits until the player walks away and back
	self._open = false
	self._confirmUntil = 0 -- os.clock() until which a second Trade tap trades
	self._pendingUntil = 0 -- os.clock() until which an answer waits for the visit to end
	self._loop = nil :: RBXScriptConnection?
	self._elapsed = 0
	self._shownKey = "" -- the cat and offer on the card, so a render does not rebuild the picture

	local panel = Panel.new({
		name = "Collector",
		title = "Cat Collector",
		subtitle = "",
		color = Theme.colors.cocoa,
		icon = "🧐",
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	panel.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.frame.Position = UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	-- the cat he wants
	local disc: Frame = Create("Frame", {
		Name = "Cat",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(LEFT_WIDTH / 2, 0),
		Size = UDim2.fromOffset(ART, ART),
		Parent = content,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	self._discStroke = Outline.border(disc, Theme.sizes.outline, Theme.rarityColor("Common"))
	self._portrait = CatPortrait.new({ parent = disc, size = UDim2.fromScale(1, 1) })
	self._name = text({
		Name = "CatName",
		Position = UDim2.fromOffset(0, ART + 2),
		Size = UDim2.fromOffset(LEFT_WIDTH, NAME_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		Parent = content,
	})
	self._rarity = text({
		Name = "Rarity",
		Position = UDim2.fromOffset(0, ART + 2 + NAME_HEIGHT),
		Size = UDim2.fromOffset(LEFT_WIDTH, LINE_HEIGHT),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		Parent = content,
	})

	local arrow = text({
		Name = "Arrow",
		Position = UDim2.fromOffset(LEFT_WIDTH, ART / 2 - 16),
		Size = UDim2.fromOffset(ARROW_WIDTH, 32),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textTitle + 4,
		TextColor3 = Theme.colors.paper,
		Text = "➜",
		Parent = content,
	})
	Outline.text(arrow, Theme.sizes.textOutline)

	-- his offer, shrunk to fit beside the arrow
	local offerLeft = LEFT_WIDTH + ARROW_WIDTH
	local offerArea: Frame = Create("Frame", {
		Name = "Offer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(offerLeft, 0),
		Size = UDim2.new(1, -offerLeft, 0, ART),
		Parent = content,
	})
	self._chips = PrizeChips.new({
		parent = offerArea,
		tile = TILE,
		textSize = Theme.sizes.textBody,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		align = Enum.HorizontalAlignment.Center,
		fitTo = offerArea,
		fitPad = 4,
	})

	local noteTop = ART + 2 + NAME_HEIGHT + LINE_HEIGHT + GAP
	text({
		Name = "Note",
		Position = UDim2.fromOffset(0, noteTop),
		Size = UDim2.new(1, 0, 0, NOTE_HEIGHT),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = NOTE,
		Parent = content,
	})

	local rowTop = noteTop + NOTE_HEIGHT + GAP
	self._decline = Button.new({
		name = "NoThanks",
		text = "No thanks",
		style = "ghost",
		size = UDim2.new(0.5, -GAP / 2, 0, ROW),
		position = UDim2.fromOffset(0, rowTop),
		parent = content,
		onClick = function()
			self:_answer(false)
		end,
	})
	self._trade = Button.new({
		name = "Trade",
		text = "Trade",
		style = "primary",
		size = UDim2.new(0.5, -GAP / 2, 0, ROW),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, rowTop),
		parent = content,
		onClick = function()
			self:_pressTrade()
		end,
	})

	-- the tag over him
	self._anchor = Create("Attachment", { Name = "CatCafeCollectorTag" }) :: Attachment
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeCollectorTag",
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = TAG_DISTANCE,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(200, 52),
		StudsOffset = Vector3.new(0, TAG_OFFSET, 0),
		Adornee = self._anchor,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	self._billboard = billboard
	local tagButton: TextButton = Create("TextButton", {
		Name = "Tag",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Parent = billboard,
	})
	self._tagButton = tagButton
	local tagName = text({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Text = "🧐 Cat Collector",
		Parent = tagButton,
	})
	Outline.text(tagName, Theme.sizes.textOutline)
	self._tagTime = text({
		Name = "Time",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.colors.gold,
		Parent = tagButton,
	})
	Outline.text(self._tagTime, Theme.sizes.textOutline)
	self._tagClick = tagButton.Activated:Connect(function()
		if self._visit then
			Sound.play("uiClick")
			self._dismissed = false
			callbacks.open(true)
		end
	end)

	self:_refresh()
	return self :: Collector
end

function Collector.setCatalog(self: any, catalog: Types.Catalog)
	table.clear(self._catById)
	for _, def in catalog.cats do
		self._catById[def.id] = def
	end
	self._chips:setCatalog(catalog)
	self._shownKey = ""
	self:_refresh()
end

function Collector.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_refresh()
end

function Collector.bind(self: any, plot: Instance?)
	self._plot = if plot and plot:IsA("Model") then plot :: Model else nil
	self:_check()
end

-- The wanted cat as the player's save has it, and its catalog entry.
function Collector._cat(self: any): (Types.CatInstance?, Types.CatDef?)
	local visit: Visit? = self._visit
	local state: Types.PlayerState? = self._state
	local cats = if state then state.cats else nil
	local instance = if visit and cats then cats[visit.catUid] else nil
	local def: Types.CatDef? = if instance then self._catById[instance.catId] else nil
	return instance, def
end

function Collector.offer(
	self: any,
	catUid: string,
	offer: Types.CollectorOffer?,
	endsAt: number,
	traded: boolean?
)
	if catUid == "" or offer == nil then
		local had = self._visit ~= nil
		self._visit = nil
		self._pendingUntil = 0
		self._confirmUntil = 0
		if had and traded == true then
			Sound.play("uiTrade")
		end
		if self._open then
			self._callbacks.close()
		end
		self:_stopLoop()
		self:_check()
		return
	end
	local fresh = self._visit == nil or (self._visit :: Visit).catUid ~= catUid
	self._visit = { catUid = catUid, offer = offer, endsAt = endsAt }
	if fresh then
		self._near = false -- the first check opens the card if the player already stands by him
		self._dismissed = false
		self._pendingUntil = 0
		self._confirmUntil = 0
	end
	self._shownKey = ""
	self:_startLoop()
	self:_refresh()
	self:_check()
end

function Collector._startLoop(self: any)
	if self._loop then
		return
	end
	self._elapsed = 0
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		self._elapsed += dt
		if self._elapsed >= CHECK_SECONDS then
			self._elapsed = 0
			self:_check()
		end
	end)
end

function Collector._stopLoop(self: any)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
end

-- The spot he stands on, while he is here and the plot is bound.
function Collector._spot(self: any): BasePart?
	local plot: Model? = self._plot
	if self._visit == nil or plot == nil then
		return nil
	end
	local spot = plot:FindFirstChild("CollectorSpot")
	return if spot and spot:IsA("BasePart") then spot :: BasePart else nil
end

-- Runs every CHECK_SECONDS while he is here: the tag, the range and the timers.
function Collector._check(self: any)
	local visit: Visit? = self._visit
	local spot = self:_spot()
	local left = if visit then visit.endsAt - Workspace:GetServerTimeNow() else 0
	if visit and left <= 0 then
		-- his time is up; the server's CollectorOffer "" follows within a second
		left = 0
	end
	local showTag = visit ~= nil and spot ~= nil and left > 0
	if showTag and spot then
		self._anchor.WorldPosition = spot.Position
		if self._anchor.Parent == nil then
			self._anchor.Parent = Workspace.Terrain
		end
		self._tagTime.Text = CollectorLogic.clock(left)
	end
	if self._billboard.Enabled ~= showTag then
		self._billboard.Enabled = showTag
		if showTag then
			Tween.popIn(self._tagButton, 0.6)
		end
	end

	local position = rootPosition()
	local distance = if spot and position then (position - spot.Position).Magnitude else nil
	local wasNear = self._near
	local near = showTag and CollectorLogic.near(distance, wasNear)
	self._near = near
	if near and not wasNear and not self._dismissed then
		self._callbacks.open(false)
	elseif wasNear and not near then
		self._dismissed = false
		if self._open then
			self._callbacks.close()
		end
	end
	if self._open then
		self._panel:setTitle("Cat Collector", "Leaves in " .. CollectorLogic.clock(left))
		self:_refreshButtons()
	end
end

-- The card's cat and offer, rebuilt only when they change.
function Collector._refresh(self: any)
	local visit: Visit? = self._visit
	if visit == nil then
		self:_refreshButtons()
		return
	end
	local instance, def = self:_cat()
	local key = visit.catUid
		.. "|"
		.. (if def then def.id else "?")
		.. "|"
		.. (if instance then instance.variant or "" else "")
		.. "|"
		.. (if instance then instance.name or "" else "")
	if key ~= self._shownKey then
		self._shownKey = key
		local variant = if instance then instance.variant else nil
		self._portrait:set(def, CatVariant.isGold(variant))
		self._discStroke.Color = Theme.rarityColor(if def then def.rarity else nil)
		local custom = if instance then instance.name else nil
		local breed = if def then def.name else "Your cat"
		self._name.Text = if custom and custom ~= "" then custom else breed
		self._rarity.Text = CollectorLogic.catLine(if def then def.rarity else nil, variant)
		self._rarity.TextColor3 = Theme.rarityInk(if def then def.rarity else nil)
		self._chips:set(CollectorLogic.prize(visit.offer, if def then def.area else nil))
	end
	self:_refreshButtons()
end

function Collector._refreshButtons(self: any)
	local now = os.clock()
	local pending = now < self._pendingUntil
	local live = self._visit ~= nil and not pending
	if not self._near and self._visit ~= nil then
		self._decline:setText("No thanks")
		self._trade:setText("Walk closer")
		self._trade:setStyle("primary")
		self._decline:setEnabled(false)
		self._trade:setEnabled(false)
		return
	end
	self._decline:setText("No thanks")
	self._decline:setEnabled(live)
	if pending then
		self._trade:setText("...")
		self._trade:setStyle("primary")
	elseif now < self._confirmUntil then
		self._trade:setText("Tap again to trade")
		self._trade:setStyle("gold")
	else
		self._trade:setText("Trade")
		self._trade:setStyle("primary")
	end
	self._trade:setEnabled(live)
end

function Collector._pressTrade(self: any)
	if self._visit == nil or not self._near or os.clock() < self._pendingUntil then
		return
	end
	local instance, def = self:_cat()
	local confirm = CollectorLogic.needsConfirm(
		if def then def.rarity else nil,
		if instance then instance.variant else nil
	)
	if confirm and os.clock() >= self._confirmUntil then
		self._confirmUntil = os.clock() + CONFIRM_SECONDS
		self:_refreshButtons()
		task.delay(CONFIRM_SECONDS, function()
			if self._alive then
				self:_refreshButtons()
			end
		end)
		return
	end
	self:_answer(true)
end

function Collector._answer(self: any, accept: boolean)
	if self._visit == nil or not self._near or os.clock() < self._pendingUntil then
		return
	end
	self._confirmUntil = 0
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self:_refreshButtons()
	self._callbacks.answer(accept)
	task.delay(PENDING_SECONDS, function()
		if self._alive then
			self:_refreshButtons() -- refused: the server's toast said why, and he waits on
		end
	end)
end

function Collector.onOpen(self: any)
	self._open = true
	self._confirmUntil = 0
	self:_refresh()
	self:_check()
end

-- X while near keeps it shut until the player walks away and back (or taps the tag).
function Collector.onClose(self: any)
	self._open = false
	self._confirmUntil = 0
	if self._near then
		self._dismissed = true
	end
end

function Collector.destroy(self: any)
	self._alive = false
	self:_stopLoop()
	self._tagClick:Disconnect()
	self._decline:destroy()
	self._trade:destroy()
	self._chips:destroy()
	self._portrait:destroy()
	self._panel:destroy()
	self._billboard:Destroy()
	self._anchor:Destroy()
end

return Collector
