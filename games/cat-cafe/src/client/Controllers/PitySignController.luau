--!strict
-- The pity cat's sign in the Town Square (#1753, luck-and-rare-moments.md 1h): Model-Agent's CatCafe_Square_PitySign,
-- placed and tagged "PitySign" by WorldBuilder. Its Screen part (5.6 x 2.8 studs, the model's PrimaryPart, facing
-- front -Z) carries three lines from shared/Pity.signLines, refreshed every second: "Legendary cat in 12:30",
-- "Mythical cat in 1:42:10", and "Now in the Woods!" while a pity cat is out or "Caught by Sam" after. The countdowns
-- come from the shared clock (Workspace:GetServerTimeNow() - Config.ClockEpoch), so every client and server agrees
-- with no message; the last line reads ReplicatedStorage.Pity's State, Area and Winner (PityService).
--
-- Roblox terms: a SurfaceGui is 2D UI drawn on one face of a part. It lives in PlayerGui with its Adornee set to the
-- sign's Screen; when the sign streams out and back in, the tag fires again and the face is hung on the new copy.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pity = require(Shared:WaitForChild("Pity"))

local PitySignController = {}

local TAG = "PitySign"
local PIXELS_PER_STUD = 50 -- the 5.6 x 2.8 stud Screen is 280 x 140
local MAX_DISTANCE = 120 -- studs; past this the face is not drawn
local TICK_SECONDS = 1
local FONT = Font.new(
	"rbxasset://fonts/families/FredokaOne.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)
local WHITE = Color3.fromHex("FFFFFF")
local GOLD = Color3.fromHex("FFC94D")
local OUTLINE = Color3.fromHex("5A3A1E") -- dark caramel, so the words read on the board's caramel face

type Face = { gui: SurfaceGui, lines: { TextLabel } }

local faces: { [Instance]: Face } = {}
local playerGui: Instance? = nil -- set in start

-- The sign's Screen: a part named "Screen" if the model has one, else its PrimaryPart (the export's Screen).
local function screenOf(model: Instance): BasePart?
	local named = model:FindFirstChild("Screen", true)
	if named ~= nil and named:IsA("BasePart") then
		return named :: BasePart
	end
	if model:IsA("Model") and model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	return nil
end

local function line(gui: SurfaceGui, order: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. order
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 10, 0, 8 + (order - 1) * 42)
	label.Size = UDim2.new(1, -20, 0, 40)
	label.FontFace = FONT
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = false
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Parent = label
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 30
	size.Parent = label
	label.Parent = gui
	return label
end

local function render(face: Face)
	local folder = ReplicatedStorage:FindFirstChild(Pity.FOLDER)
	local state = if folder ~= nil then folder:GetAttribute("State") else nil
	local area = if folder ~= nil then folder:GetAttribute("Area") else nil
	local winner = if folder ~= nil then folder:GetAttribute("Winner") else nil
	local t = Workspace:GetServerTimeNow() - Config.ClockEpoch
	local lines = Pity.signLines(
		t,
		if type(state) == "string" then state else nil,
		if type(area) == "string" then area else nil,
		if type(winner) == "string" then winner else nil
	)
	for index, label in face.lines do
		label.Text = lines[index] or ""
	end
end

local function attach(model: Instance)
	if faces[model] ~= nil or not model:IsDescendantOf(Workspace) then
		return
	end
	local screen = screenOf(model)
	if screen == nil or playerGui == nil then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PitySignFace"
	gui.Adornee = screen
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local face: Face =
		{ gui = gui, lines = { line(gui, 1, GOLD), line(gui, 2, GOLD), line(gui, 3, WHITE) } }
	gui.Parent = playerGui
	faces[model] = face
	render(face)
end

local function detach(model: Instance)
	local face = faces[model]
	if face ~= nil then
		faces[model] = nil
		face.gui:Destroy()
	end
end

function PitySignController.start()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, model in CollectionService:GetTagged(TAG) do
		attach(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for model, face in faces do
				if model.Parent == nil then
					detach(model)
				else
					render(face)
				end
			end
		end
	end)
end

return PitySignController
