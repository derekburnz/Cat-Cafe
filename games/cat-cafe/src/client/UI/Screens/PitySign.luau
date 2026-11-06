--!strict
-- The pity cat's sign in the Town Square (#1572, luck-and-rare-moments.md 1h): "PITY CAT", then "Legendary cat in
-- 12:30" and "Mythical cat in 1:42:10" in their rarity colours, counted on this client from the shared clock, and a
-- status pill while a pity cat is out ("Now in the Woods!") or after its catch ("Caught by Sam"). The board is
-- Model-Agent's CatCafe_Square_PitySign (#1592), tagged "PitySign" by WorldBuilder; its Screen part, 5.6 x 2.8 studs,
-- faces front (-Z) on a night-blue face, so the gui has no background of its own. The state comes from the
-- ReplicatedStorage.Pity folder's attributes (PityService), so a late joiner reads it too.
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- sign's Screen; when the sign streams out and back in, the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local PityLogic = require(script.Parent.Parent.Components.PityLogic)
local Theme = require(script.Parent.Parent.Theme)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pity = require(Shared:WaitForChild("Pity"))

export type PitySign = {
	destroy: (self: PitySign) -> (),
}

type Face = {
	model: Instance,
	gui: SurfaceGui,
	legendary: TextLabel,
	mythical: TextLabel,
	status: TextLabel,
}

local TAG = "PitySign"
local PIXELS_PER_STUD = 100 -- the 5.6 x 2.8 stud Screen is 560 x 280
local MAX_DISTANCE = 120 -- studs; past this the face is not drawn
local TICK_SECONDS = 1

local PitySign = {}
PitySign.__index = PitySign

local function screenOf(model: Instance): BasePart?
	local screen = model:FindFirstChild("Screen", true)
	if screen ~= nil and screen:IsA("BasePart") then
		return screen :: BasePart
	end
	-- an export may name the part after its sign ("..._PitySign_Screen")
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child.Name:match("_Screen$") then
			return child :: BasePart
		end
	end
	return nil
end

local function isScreen(child: Instance): boolean
	return child:IsA("BasePart") and (child.Name == "Screen" or child.Name:match("_Screen$") ~= nil)
end

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.display,
		TextColor3 = Theme.colors.white,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

local function attr(folder: Instance?, name: string): string
	local value = if folder ~= nil then folder:GetAttribute(name) else nil
	return if type(value) == "string" then value else ""
end

function PitySign.new(parent: Instance): PitySign
	local self = setmetatable({}, PitySign) :: any
	self._parent = parent
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
	task.spawn(function()
		while self._alive do
			if next(self._faces) ~= nil then
				self:_renderAll()
			end
			task.wait(TICK_SECONDS)
		end
	end)
	return self :: PitySign
end

function PitySign._attach(self: any, model: Instance)
	if self._faces[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil then
		-- the Screen part can stream in after the tag fires (#1803): wait for it, then attach
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
		Name = "PitySignFace",
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
	local title = text({
		Name = "Title",
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 46),
		TextSize = 40,
		Text = "⭐ " .. PityLogic.TITLE .. " ⭐",
		Parent = gui,
	})
	Outline.text(title, 3)
	local legendary = text({
		Name = "Legendary",
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 46),
		TextSize = 36,
		TextColor3 = Theme.rarityColor("Legendary"),
		Parent = gui,
	})
	Outline.text(legendary, 3)
	local mythical = text({
		Name = "Mythical",
		Position = UDim2.fromOffset(20, 124),
		Size = UDim2.new(1, -40, 0, 46),
		TextSize = 36,
		TextColor3 = Theme.rarityColor("Mythical"),
		Parent = gui,
	})
	Outline.text(mythical, 3)
	local status = text({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.new(1, -60, 0, 64),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.rarityColor("Legendary"),
		FontFace = Theme.fonts.bodyBold,
		TextSize = 32,
		Visible = false,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = status })
	local face: Face =
		{ model = model, gui = gui, legendary = legendary, mythical = mythical, status = status }
	self._faces[model] = face
	self:_render(face)
end

function PitySign._detach(self: any, model: Instance)
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

function PitySign._state(_self: any): PityLogic.State?
	local folder = ReplicatedStorage:FindFirstChild(Pity.FOLDER)
	if folder == nil then
		return nil
	end
	return {
		kind = attr(folder, "Kind"),
		area = attr(folder, "Area"),
		state = attr(folder, "State"),
		winner = attr(folder, "Winner"),
	}
end

local function paint(face: Face, view: PityLogic.View)
	face.legendary.Text = view.legendary
	face.mythical.Text = view.mythical
	face.status.Visible = view.status ~= nil
	face.status.Text = view.status or ""
	local kind = view.statusKind or "Legendary"
	face.status.BackgroundColor3 = Theme.rarityColor(kind)
	face.status.TextColor3 = Theme.rarityTextColor(kind)
end

function PitySign._view(self: any): PityLogic.View
	return PityLogic.view(Workspace:GetServerTimeNow() - Config.ClockEpoch, self:_state())
end

function PitySign._render(self: any, face: Face)
	paint(face, self:_view())
end

function PitySign._renderAll(self: any)
	local view = self:_view()
	for _, face in self._faces do
		paint(face, view)
	end
end

function PitySign.destroy(self: any)
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

return PitySign
