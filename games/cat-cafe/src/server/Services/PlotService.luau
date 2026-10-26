--!strict
-- Hands each loaded player a plot on the street and frees it when they leave. The sign above an owned cafe
-- follows the clock: open by day, Closed at night (features F20).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClockService = require(script.Parent.ClockService)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PlotService = {}

local world: WorldBuilder.World? = nil
local owners: { [number]: Player } = {} -- plot index -> player
local plotOf: { [Player]: WorldBuilder.Plot } = {}

local function signText(player: Player, phase: Types.ClockPhase): string
	local name = player.DisplayName .. "'s Cafe"
	return if phase == "night" then name .. "\nClosed" else name
end

function PlotService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Players.PlayerRemoving:Connect(PlotService.release)
	ClockService.changed:Connect(function(phase: Types.ClockPhase)
		for player, plot in plotOf do
			plot.sign.Text = signText(player, phase)
		end
	end)
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
			plot.sign.Text = signText(player, ClockService.phase())
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
	plot.model:SetAttribute("Tier", 0)
	plot.sign.Text = "Cafe for rent"
	plot.cats:ClearAllChildren()
	plot.decor:ClearAllChildren()
	plot.tables:ClearAllChildren()
	local espresso = plot.model:FindFirstChild("Espresso")
	if espresso ~= nil then
		espresso:Destroy()
	end
	for _, expansion in plot.expansions do
		WorldBuilder.setExpansionOpen(expansion, false)
	end
	WorldBuilder.setBackDoorOpen(plot, false)
end

function PlotService.get(player: Player): WorldBuilder.Plot?
	return plotOf[player]
end

return PlotService
