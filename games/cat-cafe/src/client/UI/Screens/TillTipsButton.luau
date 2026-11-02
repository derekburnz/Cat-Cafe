--!strict
-- The till's tip button (F61, data-model section 12). By day customers leave tip piles on your tables (the coins
-- are CustomerController's); walking near one collects them all. While at least one waits and you stand on your own
-- plot, one green pill floats over the till on your counter, "💰 Collect $120", and a press collects every pile from
-- anywhere in the cafe. Off your plot it hides, since the server only pays there; nothing else shows, so the cafe
-- stays clear (Derek 2026-10-28: brief and easy on the eyes). The "+$X" when they are collected is
-- CustomerController's too.
--
--   bind(plot)  watch this plot's TipPiles and TipPilesAmount; nil stops
--
-- Roblox terms: the button sits in a BillboardGui on an Attachment this client puts in Terrain at the till, so it
-- needs nothing from the counter model (which streams, and is away while the For Rent set stands).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Theme = require(script.Parent.Parent.Theme)
local TillTips = require(script.Parent.Parent.Components.TillTips)
local Tween = require(script.Parent.Parent.Components.Tween)

local PENDING_SECONDS = 3 -- the pill reads "Collecting..." this long unless the piles clear first
local CHECK_SECONDS = 0.25 -- how often the on-plot check runs while tips wait
local OFFSET = 2.4 -- studs above the till

export type Callbacks = {
	collect: () -> (),
}

export type TillTipsButton = {
	bind: (self: TillTipsButton, plot: Instance?) -> (),
	destroy: (self: TillTipsButton) -> (),
}

local TillTipsButton = {}
TillTipsButton.__index = TillTipsButton

function TillTipsButton.new(parent: Instance, callbacks: Callbacks): TillTipsButton
	local self = setmetatable({}, TillTipsButton) :: any
	self._callbacks = callbacks
	self._plot = nil :: Model?
	self._plotConnections = {} :: { RBXScriptConnection }
	self._loop = nil :: RBXScriptConnection?
	self._amount = 0
	self._pendingUntil = 0
	self._shown = false

	self._anchor = Create("Attachment", { Name = "CatCafeTillTips" }) :: Attachment
	local billboard: BillboardGui = Create("BillboardGui", {
		Name = "CatCafeTillTips",
		AlwaysOnTop = true,
		Active = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = 80,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(200, 56),
		StudsOffset = Vector3.new(0, OFFSET, 0),
		Adornee = self._anchor,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	self._billboard = billboard

	self._button = Button.new({
		name = "Collect",
		text = "Collect",
		icon = "💰",
		style = "primary",
		size = UDim2.fromOffset(184, 46),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		textSize = Theme.sizes.textLarge - 2,
		parent = billboard,
		onClick = function()
			self:_collect()
		end,
	})
	return self :: TillTipsButton
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

function TillTipsButton._collect(self: any)
	if os.clock() < self._pendingUntil then
		return
	end
	self._pendingUntil = os.clock() + PENDING_SECONDS
	self._button:setText("Collecting...")
	self._button:setEnabled(false)
	self._callbacks.collect()
end

-- Shows the pill while tips wait and this player stands on the plot; hides it otherwise.
function TillTipsButton._check(self: any)
	local plot: Model? = self._plot
	local position = rootPosition()
	local pivot = if plot then plot:GetPivot() else nil
	local show = self._amount > 0
		and pivot ~= nil
		and position ~= nil
		and TillTips.onPlot((pivot :: CFrame):PointToObjectSpace(position :: Vector3))
	if show and pivot then
		self._anchor.WorldPosition = pivot:PointToWorldSpace(TillTips.TILL)
		if os.clock() >= self._pendingUntil then
			self._button:setText("Collect " .. Format.money(self._amount))
			self._button:setEnabled(true)
		end
	end
	if show == self._shown then
		return
	end
	self._shown = show
	if show then
		self._anchor.Parent = Workspace.Terrain
		self._billboard.Enabled = true
		Tween.popIn(self._button.instance, 0.6)
	else
		local billboard: BillboardGui = self._billboard
		Tween.popOut(self._button.instance, function()
			if not self._shown then
				billboard.Enabled = false
			end
		end)
	end
end

-- Runs the check while tips wait, and stops it (hiding the pill) when they clear.
function TillTipsButton._refresh(self: any)
	local plot: Model? = self._plot
	local amount = if plot
		then TillTips.amount(plot:GetAttribute("TipPiles"), plot:GetAttribute("TipPilesAmount"))
		else 0
	if amount < self._amount or amount == 0 then
		self._pendingUntil = 0 -- collected (or gone): the next pile starts fresh
	end
	self._amount = amount
	if amount > 0 and self._loop == nil then
		local elapsed = CHECK_SECONDS
		self._loop = RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed >= CHECK_SECONDS then
				elapsed = 0
				self:_check()
			end
		end)
	elseif amount == 0 then
		local loop: RBXScriptConnection? = self._loop
		if loop then
			loop:Disconnect()
			self._loop = nil
		end
	end
	self:_check()
end

function TillTipsButton.bind(self: any, plot: Instance?)
	for _, connection in self._plotConnections do
		connection:Disconnect()
	end
	table.clear(self._plotConnections)
	self._plot = if plot and plot:IsA("Model") then plot :: Model else nil
	self._pendingUntil = 0
	local watched: Model? = self._plot
	if watched then
		local function refresh()
			self:_refresh()
		end
		table.insert(
			self._plotConnections,
			watched:GetAttributeChangedSignal("TipPiles"):Connect(refresh)
		)
		table.insert(
			self._plotConnections,
			watched:GetAttributeChangedSignal("TipPilesAmount"):Connect(refresh)
		)
	end
	self:_refresh()
end

function TillTipsButton.destroy(self: any)
	self:bind(nil)
	self._button:destroy()
	self._billboard:Destroy()
	self._anchor:Destroy()
end

return TillTipsButton
