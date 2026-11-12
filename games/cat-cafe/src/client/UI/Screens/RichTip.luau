--!strict
-- Rich tip marker (F31, data-model section 12; #3360 rich-money-bags.md). Now and then by day a rich customer leaves
-- a money bag at your cafe. A gold bubble floats over the waiting bag nearest to you with its amount and a draining
-- timer, a line for what all the bags hold when more than one waits, and a green Collect button under it, like the
-- cash pads and coin drops in Steal a Brainrot and Pet Simulator 99. Collect works within RichTipRangeStuds (12) of
-- that bag; further away it reads "Walk closer". Walking right up to a bag (TOUCH studs) collects it too. A bag pays
-- only when collected (Derek 2026-10-28: "if you miss it you miss it"): the server writes "claimed" or "missed" to the
-- bag's record (the plot's RichBags/<bagId>, attribute Outcome) just before the record goes; `collected` fires on
-- "claimed" so the caller can float "+$X", `missed` on "missed".
--
--   bind(plot)  watch this plot's RichBags records (Amount, ExpiresAt as server os.time(), Position, Outcome); nil
--                stops
--   preview(position, amount)  #2395: the same bubble over a world point, timer full and Collect inert, for the
--                intro's rich-tip shot; nil hides it (Gameplay-Engineer, with UI-Engineer's OK)
--
-- Roblox terms: the records are display copies the server keeps in step with its own table; the button is inside a
-- BillboardGui, which only passes taps and clicks to its children when Active.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local RichTipState = require(script.Parent.Parent.Components.RichTipState)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RichBags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RichBags"))

-- data-model section 12: ClaimRichTip within 12 studs of the anchor; #3360: a money bag waits RichBagSeconds (180)
local RANGE: number = Config.RichTipRangeStuds
local STAY: number = Config.RichBagSeconds
local PENDING_SECONDS = 3 -- Collect shows "Collecting..." this long unless the tip clears first
local OFFSET = 3.2 -- studs above the bag
local TOUCH = 4 -- studs: this close to a bag collects it without the button (rich-money-bags.md section 4)
-- #3633 (Derek 2026-11-12: "make the rich tip pop up like 50-75% smaller it takes up too much screen"): the bubble
-- and its button took 220 x 168 px. Now 136 x 90 with one bag (about two thirds less screen): the amount, one thin
-- timer with the clock beside it, and a shorter Collect. The "RICH TIP" heading is gone; the gold says it.
local WIDTH = 136 -- the billboard's width in px
local BUBBLE_WIDTH = 132
local BUBBLE_ONE = 46 -- the bubble's height in px with one bag waiting
local BUBBLE_MANY = 60 -- and with the "in N bags" line
local BUTTON = Vector2.new(112, 36)
local BUTTON_GAP = 6
local HIT_ROOM = 12 -- under the button: its touch pad reaches 12 px past it on phones (Button's 45 px pad at 0.75 scale)
local BOB = 0.18 -- studs of gentle bobbing (off with Reduced Motion)

export type Callbacks = {
	collect: (bagId: string) -> (),
	-- the bag was claimed: its amount and where it sat, for a "+$X" pop and a toast
	collected: (amount: number, position: Vector3?) -> (),
	missed: () -> (), -- a bag left unclaimed (its time ran out), so nothing was paid
}

export type RichTip = {
	bind: (self: RichTip, plot: Instance?) -> (),
	preview: (self: RichTip, position: Vector3?, amount: number?) -> (),
	destroy: (self: RichTip) -> (),
}

type Waiting = {
	id: string,
	amount: number,
	expiresAt: number,
	position: Vector3,
	distance: number?,
}

local RichTip = {}
RichTip.__index = RichTip

function RichTip.new(parent: Instance, callbacks: Callbacks): RichTip
	local self = setmetatable({}, RichTip) :: any
	self._callbacks = callbacks
	self._plot = nil :: Instance?
	self._anchor = nil :: BasePart?
	self._plotConnections = {} :: { RBXScriptConnection }
	self._loop = nil :: RBXScriptConnection?
	self._folder = nil :: Instance? -- the plot's RichBags folder
	self._folderConnections = {} :: { RBXScriptConnection }
	self._recordConnections = {} :: { [Instance]: RBXScriptConnection }
	self._reported = {} :: { [Instance]: boolean } -- records whose outcome was told (or was there at bind)
	self._picked = nil :: Waiting? -- the bag the bubble sits on
	self._many = false
	self._pendingUntil = 0
	self._shown = false
	self._previewPart = nil :: BasePart? -- #2395: the intro's staged point while a preview shows

	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeRichTip",
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = 150,
		ResetOnSpawn = false,
		-- HIT_ROOM under the button for its touch pad, which reaches past its face
		Size = UDim2.fromOffset(WIDTH, BUBBLE_MANY + BUTTON_GAP + BUTTON.Y + HIT_ROOM),
		StudsOffset = Vector3.new(0, OFFSET, 0),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	self._billboard = billboard

	local bubble: Frame = Create("Frame", {
		Name = "Bubble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(BUBBLE_WIDTH, BUBBLE_ONE),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
	})
	Outline.border(bubble)
	Outline.shade(bubble)
	self._bubble = bubble

	local amount: TextLabel = Create("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Theme.fonts.display,
		TextSize = 21,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = bubble,
	})
	Outline.text(amount)
	self._amount = amount
	-- #3360: what every waiting bag holds together, shown only with more than one
	self._more = Create("TextLabel", {
		Name = "More",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = Theme.fonts.display,
		TextSize = 12,
		TextColor3 = Theme.colors.goldText,
		Text = "",
		Visible = false,
		Parent = bubble,
	})

	-- the draining timer along the bottom, the clock at its right end
	local track: Frame = Create("Frame", {
		Name = "Timer",
		Position = UDim2.new(0, 10, 1, -14),
		Size = UDim2.new(1, -54, 0, 7),
		BackgroundColor3 = Theme.colors.goldDark,
		BorderSizePixel = 0,
		Parent = bubble,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Outline.border(track, 2)
	self._fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.colors.white,
		BorderSizePixel = 0,
		Parent = track,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	self._title = Create("TextLabel", {
		Name = "Clock",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 1, -11),
		Size = UDim2.fromOffset(32, 14),
		FontFace = Theme.fonts.display,
		TextSize = 12,
		TextColor3 = Theme.colors.goldText,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = bubble,
	})

	self._button = Button.new({
		name = "Collect",
		text = "Collect",
		style = "primary",
		size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		position = UDim2.new(0.5, 0, 0, BUBBLE_ONE + BUTTON_GAP),
		anchorPoint = Vector2.new(0.5, 0),
		textSize = Theme.sizes.textBody,
		parent = billboard,
		onClick = function()
			self:_collect()
		end,
	})
	return self :: RichTip
end

-- The coin pile part: the plot's RichTipAnchor, found again if it streams in later.
function RichTip._findAnchor(self: any): BasePart?
	local anchor: BasePart? = self._anchor
	if anchor and anchor.Parent then
		return anchor
	end
	local plot: Instance? = self._plot
	if not plot then
		return nil
	end
	local found = (plot :: Instance):FindFirstChild("RichTipAnchor", true)
	if found and found:IsA("BasePart") then
		local part = found :: BasePart
		self._anchor = part
		return part
	end
	self._anchor = nil
	return nil
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

-- The plot's waiting bags: a record with no outcome yet, an amount and time left. `distance` is from the player.
function RichTip._bags(self: any): { Waiting }
	local out: { Waiting } = {}
	local folder: Instance? = self._folder
	if folder == nil or folder.Parent == nil then
		return out
	end
	local now = Workspace:GetServerTimeNow()
	local from = rootPosition()
	for _, record in folder:GetChildren() do
		local amount = record:GetAttribute("Amount")
		local expiresAt = record:GetAttribute("ExpiresAt")
		local position = record:GetAttribute("Position")
		if
			record:GetAttribute("Outcome") == nil
			and type(amount) == "number"
			and amount > 0
			and type(expiresAt) == "number"
			and expiresAt > now
			and typeof(position) == "Vector3"
		then
			table.insert(out, {
				id = record.Name,
				amount = amount,
				expiresAt = expiresAt,
				position = position,
				distance = if from ~= nil then (from - position).Magnitude else nil,
			})
		end
	end
	return out
end

function RichTip._collect(self: any)
	if self._previewPart ~= nil then
		return -- #2395: a preview pays nothing
	end
	local bag: Waiting? = self._picked
	if bag == nil then
		return
	end
	local from = rootPosition()
	if from ~= nil and (from - bag.position).Magnitude > RANGE then
		return
	end
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self._button:setText("Collecting...")
	self._button:setEnabled(false)
	self._callbacks.collect(bag.id)
end

-- The bubble's height and the button under it, with or without the "in N bags" line.
function RichTip._layout(self: any, many: boolean)
	if self._many == many then
		return
	end
	self._many = many
	local height = if many then BUBBLE_MANY else BUBBLE_ONE
	self._bubble.Size = UDim2.fromOffset(BUBBLE_WIDTH, height)
	self._button.instance.Position = UDim2.new(0.5, 0, 0, height + BUTTON_GAP)
	self._more.Visible = many
end

-- Every frame while shown: which bag, its timer, the range check on Collect, the walk-in collect and the bob.
function RichTip._tick(self: any)
	local bags: { Waiting } = self:_bags()
	local index, total = RichTipState.pick(bags :: any)
	local bag: Waiting? = if index ~= nil then bags[index] else nil
	local anchor = self:_findAnchor()
	local view = if bag ~= nil
		then RichTipState.read(bag.amount, bag.expiresAt, Workspace:GetServerTimeNow(), STAY)
		else nil
	if bag == nil or view == nil or anchor == nil then
		-- the clock ran out here first; the bag leaves unpaid and the server clears its record next
		self._picked = nil
		self:_hide()
		return
	end
	self._picked = bag
	self._amount.Text = "💰 " .. Format.money(bag.amount)
	self._title.Text = RichTipState.clock(view.left)
	self._fill.Size = UDim2.fromScale(view.fraction, 1)
	self:_layout(#bags > 1)
	if #bags > 1 then
		self._more.Text = string.format("%s in %d bags", Format.money(total), #bags)
	end
	if self._billboard.Adornee ~= anchor then
		self._billboard.Adornee = anchor
	end
	self._billboard.StudsOffsetWorldSpace = bag.position - anchor.Position
	if os.clock() >= self._pendingUntil then
		local distance = bag.distance
		local near = distance == nil or distance <= RANGE
		self._button:setText(if near then "Collect" else "Walk closer")
		self._button:setEnabled(near)
		if distance ~= nil and distance <= TOUCH then
			self:_collect() -- walked into the bag
		end
	end
	if not GuiService.ReducedMotionEnabled then
		local bob = math.sin(os.clock() * 2.4) * BOB
		self._billboard.StudsOffset = Vector3.new(0, OFFSET + bob, 0)
	end
end

function RichTip._show(self: any)
	if self._shown then
		return
	end
	self._shown = true
	self._pendingUntil = 0
	self._billboard.Enabled = true
	Tween.popIn(self._bubble, 0.5)
	self._loop = RunService.Heartbeat:Connect(function()
		self:_tick()
	end)
	self:_tick()
end

function RichTip._hide(self: any)
	if not self._shown then
		return
	end
	self._shown = false
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	local billboard: BillboardGui = self._billboard
	Tween.popOut(self._bubble, function()
		if not self._shown then
			billboard.Enabled = false
		end
	end)
end

-- A record's outcome landed: tell the caller once, and let Collect work again for the next bag.
function RichTip._report(self: any, record: Instance)
	local outcome = record:GetAttribute("Outcome")
	if outcome == nil or self._reported[record] then
		return
	end
	self._reported[record] = true
	self._pendingUntil = 0
	if outcome == "missed" then
		self._callbacks.missed()
	elseif outcome == "claimed" then
		local amount = record:GetAttribute("Amount")
		local position = record:GetAttribute("Position")
		self._callbacks.collected(
			if type(amount) == "number" then amount else 0,
			if typeof(position) == "Vector3" then position else nil
		)
	end
end

-- A record came, went or ended: show the bubble while a bag waits, hide it with none.
function RichTip._refresh(self: any)
	if self._previewPart ~= nil then
		return -- #2395: the intro's preview keeps the bubble; preview(nil) refreshes again
	end
	local bags: { Waiting } = self:_bags()
	if #bags > 0 and self:_findAnchor() ~= nil then
		self:_show()
	else
		self:_hide()
	end
end

function RichTip._watchRecord(self: any, record: Instance, old: boolean)
	if self._recordConnections[record] ~= nil then
		return
	end
	if old and record:GetAttribute("Outcome") ~= nil then
		self._reported[record] = true -- ended before we bound: never reported
	end
	self._recordConnections[record] = record:GetAttributeChangedSignal("Outcome"):Connect(function()
		self:_report(record)
		self:_refresh()
	end)
end

-- The plot's RichBags folder (the server makes it with the first bag): watch its records come and go.
function RichTip._watchFolder(self: any, folder: Instance)
	if self._folder == folder then
		return
	end
	self:_unwatchFolder()
	self._folder = folder
	for _, record in folder:GetChildren() do
		self:_watchRecord(record, true)
	end
	table.insert(
		self._folderConnections,
		folder.ChildAdded:Connect(function(record: Instance)
			self:_watchRecord(record, false)
			self:_refresh()
		end)
	)
	table.insert(
		self._folderConnections,
		folder.ChildRemoved:Connect(function(record: Instance)
			local connection: RBXScriptConnection? = self._recordConnections[record]
			if connection then
				connection:Disconnect()
				self._recordConnections[record] = nil
			end
			self._reported[record] = nil
			self:_refresh()
		end)
	)
end

function RichTip._unwatchFolder(self: any)
	for _, connection in self._folderConnections do
		connection:Disconnect()
	end
	table.clear(self._folderConnections)
	for _, connection in self._recordConnections do
		connection:Disconnect()
	end
	table.clear(self._recordConnections)
	table.clear(self._reported)
	self._folder = nil
end

function RichTip.bind(self: any, plot: Instance?)
	for _, connection in self._plotConnections do
		connection:Disconnect()
	end
	table.clear(self._plotConnections)
	self:_unwatchFolder()
	self._plot = plot
	self._anchor = nil
	self._picked = nil
	if plot == nil then
		self:_hide()
		return
	end
	assert(plot, "plot")
	table.insert(
		self._plotConnections,
		plot.ChildAdded:Connect(function(child: Instance)
			if child.Name == RichBags.FOLDER then
				self:_watchFolder(child)
				self:_refresh()
			end
		end)
	)
	-- the anchor can stream in after the records
	table.insert(
		self._plotConnections,
		plot.DescendantAdded:Connect(function(child: Instance)
			if child.Name == "RichTipAnchor" then
				self:_refresh()
			end
		end)
	)
	local folder = plot:FindFirstChild(RichBags.FOLDER)
	if folder ~= nil then
		self:_watchFolder(folder)
	end
	-- a bag already waiting when we bind is shown, never reported as collected
	self:_refresh()
end

-- #2395: the intro's staged rich tip. Shows the bubble over `position` with `amount`, the timer full and Collect
-- inert, on a local invisible part; nil hides it and gives the bubble back to a real tip if one shows.
function RichTip.preview(self: any, position: Vector3?, amount: number?)
	local old: BasePart? = self._previewPart
	if position == nil then
		if old == nil then
			return
		end
		self._previewPart = nil
		old:Destroy()
		if self._shown then
			self._shown = false -- the real tip's _show adorns its anchor again
			self:_refresh()
			if not self._shown then
				local billboard: BillboardGui = self._billboard
				Tween.popOut(self._bubble, function()
					if not self._shown and self._previewPart == nil then
						billboard.Enabled = false
					end
				end)
			end
		end
		return
	end
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect() -- the real tip's ticks would take the bubble back
		self._loop = nil
	end
	local part = old
	if part == nil then
		local made = Instance.new("Part")
		made.Name = "CatCafeRichTipPreview"
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.Transparency = 1
		made.Size = Vector3.new(0.2, 0.2, 0.2)
		made.Parent = Workspace
		self._previewPart = made
		part = made
	end
	assert(part, "preview part")
	part.Position = position
	self._amount.Text = "💰 " .. Format.money(amount or 0)
	self._title.Text = RichTipState.clock(STAY)
	self._fill.Size = UDim2.fromScale(1, 1)
	self._button:setText("Collect")
	self._button:setEnabled(true)
	self:_layout(false)
	self._billboard.StudsOffset = Vector3.new(0, OFFSET, 0)
	self._billboard.StudsOffsetWorldSpace = Vector3.zero
	self._billboard.Adornee = part
	if not self._shown or old == nil then
		self._shown = true
		self._billboard.Enabled = true
		Tween.popIn(self._bubble, 0.5)
	end
end

function RichTip.destroy(self: any)
	self:preview(nil)
	self:bind(nil)
	local loop: RBXScriptConnection? = self._loop
	if loop then
		loop:Disconnect()
		self._loop = nil
	end
	self._button:destroy()
	self._billboard:Destroy()
end

return RichTip
