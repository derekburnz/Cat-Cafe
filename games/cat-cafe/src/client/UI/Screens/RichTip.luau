--!strict
-- Rich tip marker (F31, data-model section 12). Now and then by day a rich customer leaves a big tip at your cafe.
-- A gold bubble floats over the plot's RichTipAnchor (the coin pile) with the amount and a draining timer, and a
-- green Collect button under it, like the cash pads and coin drops in Steal a Brainrot and Pet Simulator 99.
-- Collect works within RichTipRangeStuds (12) of the anchor; further away it reads "Walk closer". When the tip
-- clears (claimed, or paid into the till at expiry) the marker pops away and `collected` fires so the caller can
-- float "+$X" and toast it. The server pays either way, so the marker never has to be pressed.
--
--   bind(plot)  watch this plot's RichTipAmount and RichTipExpiresAt (server os.time()); nil stops watching
--
-- Roblox terms: the plot attributes are display copies the server keeps in step with its own record; the button is
-- inside a BillboardGui, which only passes taps and clicks to its children when Active.

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

-- data-model section 12: ClaimRichTip within 12 studs of the anchor; a tip stays RichTipStaySeconds (90)
local RANGE: number = (Config :: any).RichTipRangeStuds or 12
local STAY: number = (Config :: any).RichTipStaySeconds or 90
local PENDING_SECONDS = 3 -- Collect shows "Collecting..." this long unless the tip clears first
local OFFSET = 3.2 -- studs above the anchor
local BOB = 0.18 -- studs of gentle bobbing (off with Reduced Motion)

export type Callbacks = {
	collect: () -> (),
	-- the tip cleared: its amount and where the coin pile was, for a "+$X" pop and a toast
	collected: (amount: number, position: Vector3?) -> (),
}

export type RichTip = {
	bind: (self: RichTip, plot: Instance?) -> (),
	destroy: (self: RichTip) -> (),
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
	self._lastAmount = 0
	self._pendingUntil = 0
	self._shown = false

	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeRichTip",
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = 150,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(220, 150),
		StudsOffset = Vector3.new(0, OFFSET, 0),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	self._billboard = billboard

	local bubble: Frame = Create("Frame", {
		Name = "Bubble",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(204, 88),
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Parent = billboard,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 18) }),
	})
	Outline.border(bubble)
	Outline.shade(bubble)
	self._bubble = bubble

	self._title = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.goldText,
		Text = "RICH TIP",
		Parent = bubble,
	})
	local amount: TextLabel = Create("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 36),
		FontFace = Theme.fonts.display,
		TextSize = 32,
		TextColor3 = Theme.colors.white,
		Text = "",
		Parent = bubble,
	})
	Outline.text(amount)
	self._amount = amount

	local track: Frame = Create("Frame", {
		Name = "Timer",
		Position = UDim2.new(0, 16, 1, -20),
		Size = UDim2.new(1, -32, 0, 10),
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

	self._button = Button.new({
		name = "Collect",
		text = "Collect",
		icon = "💰",
		style = "primary",
		size = UDim2.fromOffset(160, 46),
		position = UDim2.new(0.5, 0, 0, 98),
		anchorPoint = Vector2.new(0.5, 0),
		textSize = Theme.sizes.textLarge - 2,
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

function RichTip._view(self: any): RichTipState.View?
	local plot: Instance? = self._plot
	if not plot then
		return nil
	end
	return RichTipState.read(
		(plot :: Instance):GetAttribute("RichTipAmount"),
		(plot :: Instance):GetAttribute("RichTipExpiresAt"),
		Workspace:GetServerTimeNow(),
		STAY
	)
end

local function distanceTo(part: BasePart): number?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return ((root :: BasePart).Position - part.Position).Magnitude
	end
	return nil
end

function RichTip._collect(self: any)
	local anchor = self:_findAnchor()
	local distance = if anchor then distanceTo(anchor) else nil
	if distance and distance > RANGE then
		return
	end
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self._button:setText("Collecting...")
	self._button:setEnabled(false)
	self._callbacks.collect()
end

-- Every frame while shown: the timer, the range check on Collect and the bob.
function RichTip._tick(self: any)
	local view = self:_view()
	local anchor = self:_findAnchor()
	if view == nil or anchor == nil then
		-- the clock ran out here first; the server pays it into the till and clears the attributes next
		self:_hide()
		return
	end
	self._title.Text = "RICH TIP  ·  " .. RichTipState.clock(view.left)
	self._fill.Size = UDim2.fromScale(view.fraction, 1)
	if self._billboard.Adornee ~= anchor then
		self._billboard.Adornee = anchor
	end
	if os.clock() >= self._pendingUntil then
		local distance = distanceTo(anchor)
		local near = distance == nil or distance <= RANGE
		self._button:setText(if near then "Collect" else "Walk closer")
		self._button:setEnabled(near)
	end
	if not GuiService.ReducedMotionEnabled then
		local bob = math.sin(os.clock() * 2.4) * BOB
		self._billboard.StudsOffset = Vector3.new(0, OFFSET + bob, 0)
	end
end

function RichTip._show(self: any, view: RichTipState.View, anchor: BasePart)
	self._amount.Text = "💰 " .. Format.money(view.amount)
	self._billboard.Adornee = anchor
	if self._shown then
		return
	end
	self._shown = true
	self._pendingUntil = 0
	self._billboard.Enabled = true
	Tween.popIn(self._bubble, 0.5)
	self:_tick()
	self._loop = RunService.Heartbeat:Connect(function()
		self:_tick()
	end)
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

-- An attribute changed: show, update or hide, and report a tip that cleared.
function RichTip._refresh(self: any)
	local plot: Instance? = self._plot
	local raw = if plot then (plot :: Instance):GetAttribute("RichTipAmount") else nil
	local amount = if type(raw) == "number" and raw > 0 then raw else 0
	if amount == 0 and self._lastAmount > 0 then
		local anchor = self:_findAnchor()
		self._callbacks.collected(self._lastAmount, if anchor then anchor.Position else nil)
	end
	self._lastAmount = amount
	local view = self:_view()
	local anchor = self:_findAnchor()
	if view and anchor then
		self:_show(view, anchor)
	else
		self:_hide()
	end
end

function RichTip.bind(self: any, plot: Instance?)
	for _, connection in self._plotConnections do
		connection:Disconnect()
	end
	table.clear(self._plotConnections)
	self._plot = plot
	self._anchor = nil
	self._lastAmount = 0
	if plot == nil then
		self:_hide()
		return
	end
	assert(plot, "plot")
	local function refresh()
		self:_refresh()
	end
	table.insert(
		self._plotConnections,
		plot:GetAttributeChangedSignal("RichTipAmount"):Connect(refresh)
	)
	table.insert(
		self._plotConnections,
		plot:GetAttributeChangedSignal("RichTipExpiresAt"):Connect(refresh)
	)
	-- the coin pile can stream in after the attributes
	table.insert(
		self._plotConnections,
		plot.DescendantAdded:Connect(function(child: Instance)
			if child.Name == "RichTipAnchor" then
				refresh()
			end
		end)
	)
	-- a tip already waiting when we bind is shown, never reported as collected
	local raw = plot:GetAttribute("RichTipAmount")
	self._lastAmount = if type(raw) == "number" and raw > 0 then raw else 0
	refresh()
end

function RichTip.destroy(self: any)
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
