--!strict
-- Hands each loaded player a plot on the street and frees it when they leave.

local Players = game:GetService("Players")

local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PlotService = {}

local world: WorldBuilder.World? = nil
local owners: { [number]: Player } = {} -- plot index -> player
local plotOf: { [Player]: WorldBuilder.Plot } = {}

function PlotService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Players.PlayerRemoving:Connect(PlotService.release)
end

function PlotService.world(): WorldBuilder.World
	return world :: WorldBuilder.World
end

function PlotService.assign(player: Player): WorldBuilder.Plot?
	local existing = plotOf[player]
	if existing ~= nil then
		return existing
	end
	for _, plot in (world :: WorldBuilder.World).plots do
		local owner: Player? = owners[plot.index]
		if owner == nil then
			owners[plot.index] = player
			plotOf[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.sign.Text = player.DisplayName .. "'s Cafe"
			return plot
		end
	end
	warn("[PlotService] no free plot for", player.UserId)
	return nil
end

function PlotService.release(player: Player)
	local plot = plotOf[player]
	if plot == nil then
		return
	end
	plotOf[player] = nil
	owners[plot.index] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.sign.Text = "Cafe for rent"
	plot.cats:ClearAllChildren()
	plot.decor:ClearAllChildren()
	plot.tables:ClearAllChildren()
	local espresso = plot.model:FindFirstChild("Espresso")
	if espresso ~= nil then
		espresso:Destroy()
	end
end

function PlotService.get(player: Player): WorldBuilder.Plot?
	return plotOf[player]
end

return PlotService
