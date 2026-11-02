--!strict
-- Small labels over the life in every cafe (world-and-feel section 4):
--   Rate tags (Steal a Brainrot): the cat's name in white over "+$3/s" in its rarity colour, over each working cat
--   within 40 studs. Cats are the server's models tagged WorkingCat with Rate, Rarity, Napping and DisplayName (the
--   owner's name for it after the server's filter, else the breed; F33) attributes; a napping cat shows no tag.
--   At night (Clock Phase "night") the tag shows the night share behind a moon, "🌙 +$2/s", Rate x
--   NightIncomeMultiplier, the same number as the cafe's name sign (reviewer N88): the cats curl up but still earn.
--   Order bubbles: a white bubble with the customer's order over their head from the counter on, which pops into a
--   heart once they are served, then fades. Customers are this client's own models in Workspace.LocalCustomers with
--   Order and Served attributes (CustomerController). F90 (cats-make-orders.md): Order is a menu id (coffee up to
--   rainbow_cake) and the bubble shows the item's glyph from shared Catalog.getMenuItem, the dish pictures later.
--   Making bubbles (F90, cats-make-orders.md section 2): over a Barista making an order, above its rate tag, the
--   item's glyph in the same white bubble with a gold ring that fills clockwise over MakeSeconds. CafeOrders sets
--   the cat's local Making (menu id) and MakeSeconds attributes while it works; the bubble pops out when Making
--   clears, and starts over when the next order follows. The ding and the puff are VFX's.
-- The labels are parented under the models themselves, so they go when the cat or the customer goes.
--
-- Roblox terms: a BillboardGui parented under a part draws over that part and always faces the camera; its Size
-- in UDim2 scale is in studs, so it shrinks with distance. MaxDistance hides it past that many studs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local ProgressRing = require(script.Parent.Parent.Components.ProgressRing)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type WorldTags = {
	destroy: (self: WorldTags) -> (),
}

local CAT_TAG = "WorkingCat"
local CUSTOMERS = "LocalCustomers"
local MAX_DISTANCE = 40 -- world-and-feel section 4: rate tags within 40 studs
local RATE_SIZE = Vector2.new(4, 1.1) -- studs
local NAME_HEIGHT = 0.7 -- studs, the name line over the rate
local BUBBLE_SIZE = 1.7 -- studs, square
local HEART_SECONDS = 1.6 -- the heart stays this long, then fades
local MAKING_SIZE = 1.5 -- studs, square: the making bubble over a Barista, a little smaller than an order bubble
local RING_THICKNESS = 4 -- pixels
-- Emoji draw in colour in Roblox text, so the bubbles need no image upload. Before F90's menu the orders were these
-- three; a menu id reads its glyph from the catalog (orderGlyph).
local ORDER_ICONS: { [string]: string } = { coffee = "☕", cake = "🍰", milk = "🥛" }
local HEART = "❤"
local MOON = "🌙"
-- data-model NightIncomeMultiplier (1 since F60, 0.6 before): the night share of the day rate; Rate stays the day rate
local NIGHT_TIPS: number = Config.NightIncomeMultiplier

local WorldTags = {}
WorldTags.__index = WorldTags

type Making = {
	billboard: BillboardGui,
	bubble: Frame,
	icon: TextLabel,
	ring: ProgressRing.ProgressRing,
	startAt: number, -- os.clock() when this order began
	seconds: number,
	on: boolean,
}

-- F90: the menu item's glyph for an Order menu id, the old three's, or "?" for an id nobody knows.
local function orderGlyph(order: string): string
	local item = Catalog.getMenuItem(order)
	if item ~= nil and item.glyph ~= "" then
		return item.glyph
	end
	return ORDER_ICONS[order] or "?"
end

-- The part a label hangs from and how far above that part's centre the model's top is.
local function anchorOf(model: Instance): (BasePart?, number)
	local part: BasePart? = nil
	if model:IsA("Model") then
		part = (model :: Model).PrimaryPart
	end
	if not part then
		local found = model:FindFirstChildWhichIsA("BasePart", true)
		part = if found then found :: BasePart else nil
	end
	if not part then
		return nil, 0
	end
	assert(part, "anchor part")
	local top = part.Position.Y + part.Size.Y / 2
	if model:IsA("Model") then
		local boxCFrame, boxSize = (model :: Model):GetBoundingBox()
		top = math.max(top, boxCFrame.Position.Y + boxSize.Y / 2)
	end
	return part, top - part.Position.Y
end

function WorldTags.new(): WorldTags
	local self = setmetatable({}, WorldTags) :: any
	self._connections = {} :: { RBXScriptConnection }
	self._watched = {} :: { [Instance]: { RBXScriptConnection } }
	self._labels = {} :: { [Instance]: BillboardGui }
	self._renders = {} :: { [Instance]: () -> () } -- rate tags redraw when day turns to night
	-- F90: the making bubbles, by cat, and the one Heartbeat that fills their rings while any is filling
	self._making = {} :: { [Instance]: Making }
	self._fill = nil :: RBXScriptConnection?
	self._night = false
	self._destroyed = false

	for _, cat in CollectionService:GetTagged(CAT_TAG) do
		self:_attachCat(cat)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(CAT_TAG):Connect(function(cat: Instance)
			self:_attachCat(cat)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(CAT_TAG):Connect(function(cat: Instance)
			self:_detach(cat)
		end)
	)

	local function watchCustomers(folder: Instance)
		for _, customer in folder:GetChildren() do
			self:_attachCustomer(customer)
		end
		table.insert(
			self._connections,
			folder.ChildAdded:Connect(function(customer: Instance)
				self:_attachCustomer(customer)
			end)
		)
		table.insert(
			self._connections,
			folder.ChildRemoved:Connect(function(customer: Instance)
				self:_detach(customer)
			end)
		)
	end
	-- day and night from the Clock folder (data-model section 9)
	task.spawn(function()
		local clock = ReplicatedStorage:WaitForChild("Clock", 30)
		if not clock or self._destroyed then
			return
		end
		local function read()
			self._night = clock:GetAttribute("Phase") == "night"
			for _, render in self._renders do
				render()
			end
		end
		table.insert(self._connections, clock:GetAttributeChangedSignal("Phase"):Connect(read))
		read()
	end)

	local existing = Workspace:FindFirstChild(CUSTOMERS)
	if existing then
		watchCustomers(existing)
	else
		-- CustomerController makes the folder when the first customer walks in
		local waiting: RBXScriptConnection? = nil
		waiting = Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == CUSTOMERS then
				local connection = waiting
				if connection then
					connection:Disconnect()
				end
				watchCustomers(child)
			end
		end)
		table.insert(self._connections, waiting :: RBXScriptConnection)
	end
	return self :: WorldTags
end

-- Rate tags ------------------------------------------------------------------------------------------------

function WorldTags._attachCat(self: any, cat: Instance)
	if self._labels[cat] then
		return
	end
	local part, height = anchorOf(cat)
	if not part then
		return
	end
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeRateTag",
		Size = UDim2.fromScale(RATE_SIZE.X, RATE_SIZE.Y + NAME_HEIGHT),
		StudsOffsetWorldSpace = Vector3.new(0, height + (RATE_SIZE.Y + NAME_HEIGHT) / 2 + 0.3, 0),
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local nameShare = NAME_HEIGHT / (RATE_SIZE.Y + NAME_HEIGHT)
	local nameLabel: TextLabel = Create("TextLabel", {
		Name = "CatName",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, nameShare),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = billboard,
	})
	Outline.text(nameLabel, 2)
	local label: TextLabel = Create("TextLabel", {
		Name = "Rate",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, nameShare),
		Size = UDim2.fromScale(1, 1 - nameShare),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = billboard,
	})
	Outline.text(label, 2)
	local function render()
		local rate = cat:GetAttribute("Rate")
		local napping = cat:GetAttribute("Napping") == true
		local rarity = cat:GetAttribute("Rarity")
		local show = not napping and type(rate) == "number" and rate > 0
		billboard.Enabled = show
		if show then
			local night: boolean = self._night
			label.Text = if night
				then MOON .. " " .. Format.rate((rate :: number) * NIGHT_TIPS)
				else Format.rate(rate :: number)
			label.TextColor3 = Theme.rarityColor(if type(rarity) == "string" then rarity else nil)
			-- already filtered by the server for everyone (data-model section 4), so it is safe to show as is
			local displayName = cat:GetAttribute("DisplayName")
			nameLabel.Text = if type(displayName) == "string" then displayName else ""
		end
	end
	billboard.Parent = part
	self._labels[cat] = billboard
	self._renders[cat] = render
	local function making()
		self:_renderMaking(cat, part, height + RATE_SIZE.Y + NAME_HEIGHT + 0.3)
	end
	self._watched[cat] = {
		cat:GetAttributeChangedSignal("Rate"):Connect(render),
		cat:GetAttributeChangedSignal("Napping"):Connect(render),
		cat:GetAttributeChangedSignal("Rarity"):Connect(render),
		cat:GetAttributeChangedSignal("DisplayName"):Connect(render),
		cat:GetAttributeChangedSignal("Making"):Connect(making),
	}
	render()
	making()
end

-- Making bubbles (F90) --------------------------------------------------------------------------------------

-- Shows, restarts or pops out a Barista's making bubble from its Making and MakeSeconds attributes. `above` is how
-- far over the anchor part's centre the rate tag ends.
function WorldTags._renderMaking(self: any, cat: Instance, part: BasePart, above: number)
	local item = cat:GetAttribute("Making")
	local entry: Making? = self._making[cat]
	if type(item) ~= "string" then
		if entry and entry.on then
			entry.on = false
			local shown = entry
			Tween.popOut(shown.bubble, function()
				if not shown.on then
					shown.billboard.Enabled = false
				end
			end)
		end
		return
	end
	local bubble: Making = if entry then entry else self:_makingBubble(part, above)
	self._making[cat] = bubble
	local seconds = cat:GetAttribute("MakeSeconds")
	bubble.seconds = if type(seconds) == "number" and seconds > 0 then seconds else 2
	bubble.startAt = os.clock()
	bubble.on = true
	bubble.icon.Text = orderGlyph(item)
	bubble.ring:set(0)
	bubble.billboard.Enabled = true
	Tween.popIn(bubble.bubble, 0.6)
	self:_startFill()
end

function WorldTags._makingBubble(_self: any, part: BasePart, above: number): Making
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeMakingBubble",
		Size = UDim2.fromScale(MAKING_SIZE, MAKING_SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, above + MAKING_SIZE / 2 + 0.1, 0),
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local bubble: Frame = Create("Frame", {
		Name = "Bubble",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Parent = billboard,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local icon: TextLabel = Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.66, 0.66),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.ink,
		Text = "",
		Parent = bubble,
	})
	-- a faint track under the gold, so the ring reads as "this much left"; inset like the ring's circles, so both
	-- strokes end at the bubble's edge
	local track: Frame = Create("Frame", {
		Name = "Track",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(RING_THICKNESS, RING_THICKNESS),
		Size = UDim2.new(1, -2 * RING_THICKNESS, 1, -2 * RING_THICKNESS),
		Parent = bubble,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.ink,
			Transparency = 0.6,
			Thickness = RING_THICKNESS,
		}),
	})
	local ring = ProgressRing.new({
		parent = bubble,
		color = Theme.colors.gold,
		thickness = RING_THICKNESS,
		zIndex = 2,
	})
	track.ZIndex = 1
	billboard.Parent = part
	return {
		billboard = billboard,
		bubble = bubble,
		icon = icon,
		ring = ring,
		startAt = os.clock(),
		seconds = 2,
		on = false,
	}
end

-- One Heartbeat fills every ring that is filling and stops itself when none is.
function WorldTags._startFill(self: any)
	if self._fill ~= nil then
		return
	end
	self._fill = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local busy = false
		for _, entry: Making in self._making do
			if entry.on then
				local progress = (now - entry.startAt) / entry.seconds
				entry.ring:set(progress)
				busy = busy or progress < 1
			end
		end
		if not busy then
			local connection: RBXScriptConnection? = self._fill
			if connection then
				connection:Disconnect()
			end
			self._fill = nil
		end
	end)
end

-- Order bubbles ----------------------------------------------------------------------------------------------

function WorldTags._attachCustomer(self: any, customer: Instance)
	if self._watched[customer] then
		return
	end
	local served = false
	local function render()
		local order = customer:GetAttribute("Order")
		local isServed = customer:GetAttribute("Served") == true
		if type(order) ~= "string" and not isServed then
			return
		end
		local existing: BillboardGui? = self._labels[customer] or self:_bubble(customer)
		if existing == nil then
			return
		end
		local billboard: BillboardGui = existing
		local icon = billboard:FindFirstChild("Icon", true) :: TextLabel?
		local bubble = billboard:FindFirstChild("Bubble") :: Frame?
		if not icon or not bubble then
			return
		end
		if isServed and not served then
			served = true
			icon.Text = HEART
			icon.TextColor3 = Theme.colors.red
			bubble.BackgroundColor3 = Theme.colors.pink
			Tween.popIn(bubble, 1.4)
			task.delay(HEART_SECONDS, function()
				if billboard.Parent then
					Tween.popOut(bubble, function()
						billboard.Enabled = false
					end)
				end
			end)
		elseif not isServed then
			icon.Text = orderGlyph(order :: string)
			Tween.popIn(bubble, 0.6)
		end
	end
	self._watched[customer] = {
		customer:GetAttributeChangedSignal("Order"):Connect(render),
		customer:GetAttributeChangedSignal("Served"):Connect(render),
	}
	render()
end

function WorldTags._bubble(self: any, customer: Instance): BillboardGui?
	local part, height = anchorOf(customer)
	if not part then
		return nil
	end
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeOrderBubble",
		Size = UDim2.fromScale(BUBBLE_SIZE, BUBBLE_SIZE),
		StudsOffsetWorldSpace = Vector3.new(0, height + BUBBLE_SIZE / 2 + 0.4, 0),
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	local bubble: Frame = Create("Frame", {
		Name = "Bubble",
		BackgroundColor3 = Theme.colors.paper,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		Parent = billboard,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(bubble, 2)
	Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.7, 0.7),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.ink,
		Text = "",
		Parent = bubble,
	})
	billboard.Parent = part
	self._labels[customer] = billboard
	return billboard
end

function WorldTags._detach(self: any, model: Instance)
	local connections: { RBXScriptConnection }? = self._watched[model]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	self._watched[model] = nil
	self._renders[model] = nil
	local making: Making? = self._making[model]
	if making then
		making.billboard:Destroy()
	end
	self._making[model] = nil
	local label: BillboardGui? = self._labels[model]
	if label then
		label:Destroy()
	end
	self._labels[model] = nil
end

function WorldTags.destroy(self: any)
	self._destroyed = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local fill: RBXScriptConnection? = self._fill
	if fill then
		fill:Disconnect()
	end
	self._fill = nil
	local models = {}
	for model in self._watched do
		table.insert(models, model)
	end
	for model in self._labels do
		if not self._watched[model] then
			table.insert(models, model)
		end
	end
	for _, model in models do
		self:_detach(model)
	end
end

return WorldTags
