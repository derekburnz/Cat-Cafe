--!strict
-- The leaderboard crown over a player's head (F98, leaderboards.md section 3): a small gold 👑 floats over anyone in
-- an all time top 10 at the last refresh, from the `Crown` attribute the server sets on their Player. It gives
-- nothing else. This player's own crown shows too.
--
-- Roblox terms: a BillboardGui parented under a part draws over it and always faces the camera; StudsOffset lifts
-- it above the head and MaxDistance hides it far away. It is made here on each client, so it costs the server
-- nothing, and it goes with the character when they respawn.

local Players = game:GetService("Players")

local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Theme = require(script.Parent.Parent.Theme)

export type Crowns = {
	destroy: (self: Crowns) -> (),
}

local NAME = "CatCafeCrown"
local MAX_DISTANCE = 80 -- studs
local LIFT = 3.2 -- studs above the head's centre, over Roblox's own name

local Crowns = {}
Crowns.__index = Crowns

function Crowns.new(): Crowns
	local self = setmetatable({}, Crowns) :: any
	self._connections = {} :: { RBXScriptConnection }
	self._perPlayer = {} :: { [Player]: { RBXScriptConnection } }
	for _, player in Players:GetPlayers() do
		self:_follow(player)
	end
	table.insert(
		self._connections,
		Players.PlayerAdded:Connect(function(player: Player)
			self:_follow(player)
		end)
	)
	table.insert(
		self._connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			self:_forget(player)
		end)
	)
	return self :: Crowns
end

function Crowns._follow(self: any, player: Player)
	if self._perPlayer[player] then
		return
	end
	local connections: { RBXScriptConnection } = {}
	self._perPlayer[player] = connections
	table.insert(
		connections,
		player:GetAttributeChangedSignal("Crown"):Connect(function()
			self:_paint(player)
		end)
	)
	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character: Model)
			-- the head can arrive a moment after the model
			character:WaitForChild("Head", 10)
			self:_paint(player)
		end)
	)
	self:_paint(player)
end

function Crowns._paint(_self: any, player: Player)
	local character = player.Character
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local crowned = player:GetAttribute("Crown") == true
	local existing = head:FindFirstChild(NAME)
	if not crowned then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local gui: BillboardGui = Create("BillboardGui", {
		Name = NAME,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = MAX_DISTANCE,
		Size = UDim2.fromScale(1.4, 1.4),
		StudsOffset = Vector3.new(0, LIFT, 0),
		ResetOnSpawn = false,
	})
	local crown: TextLabel = Create("TextLabel", {
		Name = "Crown",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.gold,
		Text = "👑",
		Parent = gui,
	})
	Outline.text(crown, 2)
	gui.Parent = head
end

function Crowns._forget(self: any, player: Player)
	local connections = self._perPlayer[player]
	if connections == nil then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	self._perPlayer[player] = nil
end

function Crowns.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	local players: { Player } = {}
	for player in self._perPlayer do
		table.insert(players, player)
	end
	for _, player in players do
		self:_forget(player)
		local character = player.Character
		local head = if character ~= nil then character:FindFirstChild("Head") else nil
		local crown = if head ~= nil then head:FindFirstChild(NAME) else nil
		if crown then
			crown:Destroy()
		end
	end
end

return Crowns
