--!strict
-- #4251 Harvest Hollow's arch sign in the Town Square (harvest-hollow-spec section 1): "HARVEST HOLLOW" and a small
-- line under it that changes: "Opens Wed 3 PM" in the player's own time, a calm "Opens in 5h 12m" in the last day,
-- "Open until Sun Dec 6", "Opens at Tier 2" below the tier, and "Back next autumn" once it has closed
-- (Components/HarvestLogic.signLine). The arch is Model-Agent's CatCafe_Harvest_Arch, tagged HarvestArch by
-- World/HarvestWorld; its Screen part (CatCafe_Harvest_Arch_Screen, 8.0 x 2.6 studs) faces front (-Z) on a night-blue
-- face, so the gui has no background of its own. The line follows the server's clock, this player's tier and the
-- harvestHollow switch attribute.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- sign's Screen; when the arch streams out and back in, the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local HarvestLogic = require(script.Parent.Parent.Components.HarvestLogic)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

local HarvestHollow =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HarvestHollow"))

export type HarvestSign = {
	destroy: (self: HarvestSign) -> (),
}

type Face = {
	model: Instance,
	gui: SurfaceGui,
	line: TextLabel,
}

local TAG = "HarvestArch"
local PIXELS_PER_STUD = 100 -- the 8.0 x 2.6 stud Screen is 800 x 260
local MAX_DISTANCE = 140 -- studs; past this the face is not drawn
local TICK_SECONDS = 5

local HarvestSign = {}
HarvestSign.__index = HarvestSign

local function isScreen(child: Instance): boolean
	return child:IsA("BasePart") and (child.Name == "Screen" or child.Name:match("_Screen$") ~= nil)
end

local function screenOf(model: Instance): BasePart?
	for _, child in model:GetDescendants() do
		if isScreen(child) then
			return child :: BasePart
		end
	end
	return nil
end

-- The opening in the player's own time ("Wed 3 PM"), or the UTC words if the engine cannot format it.
local function opensText(): string
	local ok, text = pcall(function()
		return DateTime.fromUnixTimestamp(HarvestHollow.OPENS_AT)
			:FormatLocalTime("ddd h A", "en-us")
	end)
	return if ok and type(text) == "string" and text ~= "" then text else "Wed 20:00 UTC"
end

-- `tierOf` reads this player's tier (UI.getState) at each paint.
function HarvestSign.new(parent: Instance, tierOf: () -> number?): HarvestSign
	local self = setmetatable({}, HarvestSign) :: any
	self._parent = parent
	self._tierOf = tierOf
	self._opens = opensText()
	self._faces = {} :: { [Instance]: Face }
	self._waiting = {} :: { [Instance]: RBXScriptConnection }
	self._connections = {} :: { RBXScriptConnection }
	self._alive = true
	for _, model in CollectionService:GetTagged(TAG) do
		self:_attach(model)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model: Instance)
			self:_attach(model)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model: Instance)
			self:_detach(model)
		end)
	)
	table.insert(
		self._connections,
		ReplicatedStorage:GetAttributeChangedSignal(HarvestLogic.FLAG_ATTRIBUTE):Connect(function()
			self:_renderAll()
		end)
	)
	task.spawn(function()
		while self._alive do
			if next(self._faces) ~= nil then
				self:_renderAll()
			end
			task.wait(TICK_SECONDS)
		end
	end)
	return self :: HarvestSign
end

function HarvestSign._attach(self: any, model: Instance)
	if self._faces[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part can stream in after the tag fires: wait for it, then attach
		if self._waiting[model] == nil then
			self._waiting[model] = model.DescendantAdded:Connect(function(child: Instance)
				if isScreen(child) then
					local waiting = self._waiting[model]
					if waiting then
						waiting:Disconnect()
						self._waiting[model] = nil
					end
					if self._alive then
						self:_attach(model)
					end
				end
			end)
		end
		return
	end
	local gui: SurfaceGui = Create("SurfaceGui", {
		Name = "HarvestSignFace",
		Adornee = screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._parent,
	})
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -48, 0, 120),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.gold,
		Text = HarvestLogic.PUMPKIN
			.. " "
			.. HarvestLogic.SIGN_TITLE
			.. " "
			.. HarvestLogic.PUMPKIN,
		Parent = gui,
	})
	Outline.text(title, 4)
	local line: TextLabel = Create("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Size = UDim2.new(1, -200, 0, 66), -- smaller than the title, with room at the frame's edges
		FontFace = Theme.fonts.bodyBold,
		TextScaled = true,
		TextColor3 = Theme.colors.cream,
		Text = "",
		Parent = gui,
	})
	Outline.text(line, 3)
	local face: Face = { model = model, gui = gui, line = line }
	self._faces[model] = face
	self:_paint(face)
end

function HarvestSign._detach(self: any, model: Instance)
	local waiting = self._waiting[model]
	if waiting then
		waiting:Disconnect()
		self._waiting[model] = nil
	end
	local face: Face? = self._faces[model]
	if face then
		face.gui:Destroy()
		self._faces[model] = nil
	end
end

function HarvestSign._line(self: any): string
	return HarvestLogic.signLine(
		Workspace:GetServerTimeNow(),
		self._tierOf(),
		ReplicatedStorage:GetAttribute(HarvestLogic.FLAG_ATTRIBUTE),
		self._opens
	)
end

function HarvestSign._paint(self: any, face: Face)
	face.line.Text = self:_line()
end

function HarvestSign._renderAll(self: any)
	local text = self:_line()
	for _, face in self._faces do
		face.line.Text = text
	end
end

function HarvestSign.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	for _, waiting in self._waiting do
		waiting:Disconnect()
	end
	table.clear(self._waiting)
	for model in self._faces do
		self:_detach(model)
	end
end

return HarvestSign
