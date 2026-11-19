--!strict
-- #5471 (Derek 2026-11-19: "cat paw path in town square still not loading in"), switch `townPawsLocal` (off by
-- default): the Town Square's paw print path is built here, on this client, from the list the server writes
-- (shared/TownGround.PAWS_VALUE), so streaming never takes a print away or feeds it in late. The server's own
-- PawPaths parts are faded on this client (LocalTransparencyModifier 1) as they stream in, so nothing doubles; with
-- the switch off the local prints go and the server's come back. Every print is a pad and four toes, flat, not
-- colliding, queried or touched, as WorldBuilder.buildPawPaths makes them. Listening only.
--
-- Roblox terms: parts a client makes itself exist only on that client and are never streamed out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
local TownGround = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TownGround"))

local TownPaws = {}

local CHECK = 2 -- seconds between reads of the switch and the list
local FOLDER = "CatCafeTownPaws"

local started = false
local built: Folder? = nil
local builtFrom = ""
local faded: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local fading: RBXScriptConnection? = nil
local watched: Instance? = nil -- the server PawPaths being faded

-- Pure: the CFrame of a print's piece `x`, `z` studs off its middle, laid flat (a cylinder's axis is its X, so a
-- quarter turn about Z lays it down).
function TownPaws.piece(paw: TownGround.Print, x: number, z: number): CFrame
	return CFrame.new(paw.x, paw.y, paw.z)
		* CFrame.Angles(0, math.rad(paw.rotY), 0)
		* CFrame.new(x, 0, z)
		* CFrame.Angles(0, 0, math.rad(90))
end

local function disc(name: string, diameter: number, at: CFrame, colour: Color3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.03, diameter, diameter)
	p.CFrame = at
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.Parent = parent
end

local function build(text: string)
	if built ~= nil then
		built:Destroy()
		built = nil
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, paw in TownGround.decode(text) do
		local colour = Color3.fromRGB(paw.r, paw.g, paw.b)
		disc("PawPad", TownGround.PAD, TownPaws.piece(paw, 0, 0), colour, folder)
		for _, toe in TownGround.TOES do
			disc("PawToe", TownGround.TOE, TownPaws.piece(paw, toe[1], toe[2]), colour, folder)
		end
	end
	folder.Parent = Workspace
	built = folder
	builtFrom = text
end

local function fade(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	local part = item :: BasePart
	if not faded[part] then
		faded[part] = true
		part.LocalTransparencyModifier = 1
	end
end

local function serverPaths(): Instance?
	local world = Workspace:FindFirstChild("World")
	return if world ~= nil then world:FindFirstChild(TownGround.PATHS_NAME) else nil
end

local function hideServer(paths: Instance)
	for _, item in paths:GetDescendants() do
		fade(item)
	end
	if fading == nil then
		fading = paths.DescendantAdded:Connect(fade)
	end
end

local function showServer()
	if fading ~= nil then
		fading:Disconnect()
		fading = nil
	end
	for part in faded do
		part.LocalTransparencyModifier = 0
	end
	table.clear(faded)
	watched = nil
end

local function check()
	local on = ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. TownGround.LOCAL_FLAG)
		== true
	local value = ReplicatedStorage:FindFirstChild(TownGround.PAWS_VALUE)
	local text = if value ~= nil and value:IsA("StringValue")
		then (value :: StringValue).Value
		else ""
	-- nothing to build from (an older server): leave the server's prints as they are
	if not on or text == "" then
		if built ~= nil then
			built:Destroy()
			built = nil
			builtFrom = ""
		end
		showServer()
		return
	end
	if built == nil or built.Parent == nil or text ~= builtFrom then
		build(text)
	end
	local paths = serverPaths()
	if paths ~= nil then
		if paths ~= watched then
			showServer() -- the world was rebuilt (or a first look): watch this PawPaths
			watched = paths
		end
		hideServer(paths)
	end
end

function TownPaws.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(function(): string?
				check()
				return nil -- CI's luau-lsp wants two values from pcall
			end)
			if not ok then
				warn("[TownPaws] " .. tostring(err))
			end
			task.wait(CHECK)
		end
	end)
end

return TownPaws
