--!strict
-- Cafe name signs (world-and-feel section 3, copied from the Steal a Brainrot base signs): over every cafe door the
-- owner's avatar headshot, "Derek's Cafe" and a line with the tier name and the cafe's tips per second
-- ("Cozy Cafe  ·  +$42/s"). At night the cafe closes but keeps earning the night share, so the line reads
-- "🌙 Closed  ·  +$25/s" (data-model section 11). An empty plot reads FOR RENT. Your own cafe gets a gold edge so you can spot it down the street.
--
-- Plots are the server's models tagged "Plot" with OwnerUserId, OwnerName, TierName and Rate attributes. The sign
-- board is the shell's SignBoard part, else the code-built Sign part. This draws a local SurfaceGui on its street
-- face and hides the server's plain SignGui on this client only, so the server's text stays as the fallback.
--
-- Roblox terms: a SurfaceGui draws 2D UI flat on one face of a part. With PixelsPerStud sizing, its canvas is the
-- face's size in studs times that number, so the layout below works in scale and fits any board.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Parent.Components.Create)
local Format = require(script.Parent.Parent.Components.Format)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type CafeSigns = {
	destroy: (self: CafeSigns) -> (),
}

local TAG = "Plot"
local BOARD_NAMES = { "SignBoard", "Sign" }
local PIXELS_PER_STUD = 50
local MAX_DISTANCE = 150
local WATCHED = { "OwnerUserId", "OwnerName", "TierName", "Rate" }
-- data-model NightIncomeMultiplier (0.6): the night share of the day rate; the plot's Rate stays the day rate
local NIGHT_TIPS: number = Config.NightIncomeMultiplier
local MOON = "🌙"

type Sign = {
	plot: Instance,
	gui: SurfaceGui,
	card: Frame,
	border: UIStroke,
	headshot: ImageLabel,
	name: TextLabel,
	info: TextLabel,
	board: BasePart?,
	serverGui: SurfaceGui?,
	connections: { RBXScriptConnection },
}

local CafeSigns = {}
CafeSigns.__index = CafeSigns

local function findBoard(plot: Instance): BasePart?
	for _, name in BOARD_NAMES do
		local found = plot:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found :: BasePart
		end
	end
	return nil
end

local function label(props: { [string]: any }, outline: number): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local created: TextLabel = Create("TextLabel", merged)
	Outline.text(created, outline)
	return created
end

-- Puts the sign on the board (the shell's SignBoard wins over the code-built Sign) and hides the server's text.
local function hang(sign: Sign)
	local board = findBoard(sign.plot)
	if board == sign.board then
		return
	end
	local old: SurfaceGui? = sign.serverGui
	if old then
		old.Enabled = true
	end
	sign.board = board
	sign.serverGui = nil
	sign.gui.Adornee = board :: any
	sign.gui.Enabled = board ~= nil
	if board then
		-- the server's text sits on the code-built Sign, which may stay beside a shell's SignBoard
		local found = sign.plot:FindFirstChild("SignGui", true)
		if found and found:IsA("SurfaceGui") then
			local serverGui = found :: SurfaceGui
			sign.serverGui = serverGui
			serverGui.Enabled = false
		end
	end
end

function CafeSigns.new(parent: Instance): CafeSigns
	local self = setmetatable({}, CafeSigns) :: any
	self._parent = parent
	self._signs = {} :: { [Instance]: Sign }
	self._connections = {} :: { RBXScriptConnection }
	self._night = false

	for _, plot in CollectionService:GetTagged(TAG) do
		self:_attach(plot)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(plot: Instance)
			self:_attach(plot)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(plot: Instance)
			self:_detach(plot)
		end)
	)

	-- day and night from the Clock folder (data-model section 9)
	task.spawn(function()
		local clock = ReplicatedStorage:WaitForChild("Clock", 30)
		if not clock or self._destroyed then
			return
		end
		local function read()
			self._night = clock:GetAttribute("Phase") == "night"
			for _, sign in self._signs do
				self:_render(sign)
			end
		end
		table.insert(self._connections, clock:GetAttributeChangedSignal("Phase"):Connect(read))
		read()
	end)
	return self :: CafeSigns
end

function CafeSigns._attach(self: any, plot: Instance)
	if self._signs[plot] then
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "CafeSign_" .. plot.Name,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		ClipsDescendants = true,
		ResetOnSpawn = false,
		Enabled = false,
		ZOffset = 1, -- in front of the server's SignGui if it shows for a moment after a stream-in
		Parent = self._parent,
	})
	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.colors.cocoaDeep,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.97, 0.9),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
	local border = Outline.border(card, 6, Theme.colors.caramel)
	Outline.shade(card, 0.25)
	-- the owner's face on the left, square, like the base signs it copies
	local headshot: ImageLabel = Create("ImageLabel", {
		Name = "Headshot",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.025, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Image = "",
		Parent = card,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(headshot, 4)
	local name = label({
		Name = "Name",
		Position = UDim2.fromScale(0.22, 0.08),
		Size = UDim2.fromScale(0.75, 0.5),
	}, 4)
	name.Parent = card
	local info = label({
		Name = "Info",
		Position = UDim2.fromScale(0.22, 0.58),
		Size = UDim2.fromScale(0.75, 0.32),
		TextColor3 = Theme.hud.income,
	}, 3)
	info.Parent = card

	local sign: Sign = {
		plot = plot,
		gui = gui,
		card = card,
		border = border,
		headshot = headshot,
		name = name,
		info = info,
		board = nil,
		serverGui = nil,
		connections = {},
	}
	self._signs[plot] = sign
	for _, attribute in WATCHED do
		table.insert(
			sign.connections,
			plot:GetAttributeChangedSignal(attribute):Connect(function()
				self:_render(sign)
			end)
		)
	end
	-- the shell or its sign part can stream in after the plot model
	table.insert(
		sign.connections,
		plot.DescendantAdded:Connect(function(descendant: Instance)
			if table.find(BOARD_NAMES, descendant.Name) and descendant:IsA("BasePart") then
				hang(sign)
			elseif descendant.Name == "SignGui" and descendant:IsA("SurfaceGui") and sign.board then
				-- a board's children can replicate after the board itself (reviewer N66)
				local serverGui = descendant :: SurfaceGui
				sign.serverGui = serverGui
				serverGui.Enabled = false
			end
		end)
	)
	hang(sign)
	self:_render(sign)
end

function CafeSigns._render(self: any, sign: Sign)
	local plot = sign.plot
	local userId = plot:GetAttribute("OwnerUserId")
	local owned = type(userId) == "number" and userId > 0
	if not owned then
		sign.headshot.Visible = false
		sign.name.Position = UDim2.fromScale(0.05, 0.08)
		sign.name.Size = UDim2.fromScale(0.9, 0.5)
		sign.info.Position = UDim2.fromScale(0.05, 0.58)
		sign.info.Size = UDim2.fromScale(0.9, 0.32)
		sign.name.TextXAlignment = Enum.TextXAlignment.Center
		sign.info.TextXAlignment = Enum.TextXAlignment.Center
		sign.name.Text = "FOR RENT"
		sign.info.Text = "A cosy spot for a new cafe"
		sign.info.TextColor3 = Theme.colors.cream
		sign.border.Color = Theme.colors.caramel
		return
	end
	assert(type(userId) == "number", "owner id")
	sign.headshot.Visible = true
	sign.headshot.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
	sign.name.Position = UDim2.fromScale(0.22, 0.08)
	sign.name.Size = UDim2.fromScale(0.75, 0.5)
	sign.info.Position = UDim2.fromScale(0.22, 0.58)
	sign.info.Size = UDim2.fromScale(0.75, 0.32)
	sign.name.TextXAlignment = Enum.TextXAlignment.Left
	sign.info.TextXAlignment = Enum.TextXAlignment.Left

	local ownerName = plot:GetAttribute("OwnerName")
	if type(ownerName) ~= "string" or ownerName == "" then
		local player = Players:GetPlayerByUserId(userId)
		ownerName = if player then player.DisplayName else "Someone"
	end
	sign.name.Text = ("%s's Cafe"):format(ownerName :: string)

	local tierName = plot:GetAttribute("TierName")
	local rate = plot:GetAttribute("Rate")
	local parts: { string } = {}
	-- v0.5 (data-model section 11): the cafe closes at night and the sign says so with a moon, but the cats keep
	-- earning the night share (reviewer S41), so the rate stays
	if self._night then
		table.insert(parts, MOON .. " Closed")
	elseif type(tierName) == "string" and tierName ~= "" then
		table.insert(parts, tierName)
	end
	if type(rate) == "number" and rate > 0 then
		table.insert(parts, Format.rate(if self._night then rate * NIGHT_TIPS else rate))
	end
	sign.info.TextColor3 = if self._night then Theme.colors.sky else Theme.hud.income
	sign.info.Text = table.concat(parts, "  ·  ")

	local mine = Players.LocalPlayer ~= nil and Players.LocalPlayer.UserId == userId
	sign.border.Color = if mine then Theme.colors.gold else Theme.colors.caramel
end

function CafeSigns._detach(self: any, plot: Instance)
	local sign: Sign? = self._signs[plot]
	if not sign then
		return
	end
	self._signs[plot] = nil
	for _, connection in sign.connections do
		connection:Disconnect()
	end
	local serverGui = sign.serverGui
	if serverGui then
		serverGui.Enabled = true
	end
	sign.gui:Destroy()
end

function CafeSigns.destroy(self: any)
	self._destroyed = true
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local plots = {}
	for plot in self._signs do
		table.insert(plots, plot)
	end
	for _, plot in plots do
		self:_detach(plot)
	end
end

return CafeSigns
