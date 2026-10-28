--!strict
-- Hands each loaded player a plot on the street and frees it when they leave. The sign above an owned cafe shows
-- its tier and tips, behind a moon at night: cafes keep earning after dark (common-features note 1, reviewer S41).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeName = require(ReplicatedStorage.Shared.CafeName)
local ClockService = require(script.Parent.ClockService)
local Net = require(script.Parent.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PlotService = {}

local world: WorldBuilder.World? = nil
local owners: { [number]: Player } = {} -- plot index -> player
local plotOf: { [Player]: WorldBuilder.Plot } = {}
local infoLine: { [Player]: string } = {} -- the sign's second line: tier name and tips per second
local MOON = "🌙" -- the same night mark as the UI's CafeSigns

local function signText(player: Player, phase: Types.ClockPhase): string
	local name = CafeName.title(player.DisplayName)
	local line = infoLine[player]
	if line == nil then
		return name
	end
	return name .. "\n" .. (if phase == "night" then MOON .. " " .. line else line)
end

function PlotService.start(builtWorld: WorldBuilder.World)
	world = builtWorld
	Players.PlayerRemoving:Connect(PlotService.release)
	ClockService.changed:Connect(function(phase: Types.ClockPhase)
		for player, plot in plotOf do
			plot.sign.Text = signText(player, phase)
			WorldBuilder.setClosedSign(plot, phase == "night") -- the cafe closes at night (F44)
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
			-- capped, so the UI's sign (CafeSigns: headshot and "<OwnerName>'s Cafe") fits a long name too
			plot.model:SetAttribute("OwnerName", CafeName.shown(player.DisplayName))
			plot.sign.Text = signText(player, ClockService.phase())
			WorldBuilder.setClosedSign(plot, ClockService.phase() == "night")
			-- every client hears the shutters roll up and sees the shop open, at the shop front (F38)
			Net.fireAll("PlotOpened", plot.door.Position, plot.index)
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
	infoLine[player] = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.model:SetAttribute("OwnerName", "")
	plot.model:SetAttribute("Tier", 0)
	plot.model:SetAttribute("TierName", "")
	plot.model:SetAttribute("Rate", 0)
	plot.sign.Text = "Cafe for rent"
	plot.cats:ClearAllChildren()
	plot.decor:ClearAllChildren()
	plot.tables:ClearAllChildren()
	plot.bait:ClearAllChildren()
	plot.model:SetAttribute("BaitReadyAt", 0)
	-- RichTipService has already missed any open tip (unclaimed tips are never paid); the marker and its outcome
	-- must not outlive the owner (review N232)
	plot.model:SetAttribute("RichTipOutcome", nil)
	plot.model:SetAttribute("RichTipAmount", 0)
	plot.model:SetAttribute("RichTipExpiresAt", 0)
	local espresso = plot.model:FindFirstChild("Espresso")
	if espresso ~= nil then
		espresso:Destroy()
	end
	for _, expansion in plot.expansions do
		WorldBuilder.setExpansionOpen(expansion, false)
	end
	WorldBuilder.setBackDoorOpen(plot, false)
	WorldBuilder.setDressing(plot, 0)
	WorldBuilder.setClosedSign(plot, false)
end

-- What the street sees of an owned cafe (F36 name sign, F37 rate tags): the plot's TierName and Rate (tips per
-- second) attributes and the sign's second line. CafeService calls it on every sync.
function PlotService.setShowcase(player: Player, tierName: string, rate: number, line: string)
	local plot = plotOf[player]
	if plot == nil then
		return
	end
	plot.model:SetAttribute("TierName", tierName)
	plot.model:SetAttribute("Rate", rate)
	infoLine[player] = line
	plot.sign.Text = signText(player, ClockService.phase())
end

function PlotService.get(player: Player): WorldBuilder.Plot?
	return plotOf[player]
end

return PlotService
