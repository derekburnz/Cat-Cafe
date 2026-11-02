--!strict
-- The front lawn in the world (F91, front-lawn.md): the plot owner's piece on each lawn spot, their path style over
-- the shell's own path and their fence along the sidewalk, in the plot's Lawn folder, and the display-only plot
-- attributes every client reads (Lawn_<spotId>, LawnPath, LawnFence). Nothing happens until the lawn's art is in
-- (WorldBuilder.lawnLive). A model already standing is kept, so a refresh only touches what changed. CafeService
-- calls refresh with every plot refresh; PlotService calls clear when the owner leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetRegistry = require(script.Parent.AssetRegistry)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Lawn = require(ReplicatedStorage.Shared.Lawn)
local Layout = require(script.Parent.Layout)
local Types = require(ReplicatedStorage.Shared.Types)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LawnBuilder = {}

-- Stands `asset` as Lawn/<name> at `at`, keeping the one there when it is the same asset; nil, or art that is not in
-- ReplicatedStorage.Assets, takes it away. Each carries Asset and LawnId (the piece or style id, for the client's
-- effects: the Mailbox flag, the night glows). Returns whether the model stands.
local function show(
	plot: WorldBuilder.Plot,
	name: string,
	asset: string?,
	id: string?,
	at: CFrame
): boolean
	local existing = plot.lawn:FindFirstChild(name)
	if existing ~= nil and (asset == nil or existing:GetAttribute("Asset") ~= asset) then
		existing:Destroy()
		existing = nil
	end
	if existing ~= nil then
		return true
	end
	if asset == nil or not AssetRegistry.has(asset) then
		return false
	end
	local model = AssetRegistry.clone(asset)
	model.Name = name
	model:SetAttribute("Asset", asset)
	model:SetAttribute("LawnId", id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- a piece streams in whole
	model:PivotTo(at)
	model.Parent = plot.lawn
	return true
end

local function pointAt(
	plot: WorldBuilder.Plot,
	x: number,
	y: number,
	z: number,
	rotY: number
): CFrame
	return plot.cframe * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotY), 0)
end

-- Puts the shell's own path back (nil parent while a path style lies over it).
local function showShellPath(plot: WorldBuilder.Plot, shown: boolean)
	local path, shell = plot.shellPath, plot.shell
	if path ~= nil and shell ~= nil then
		path.Parent = if shown then shell else nil
	end
end

function LawnBuilder.refresh(plot: WorldBuilder.Plot, profile: Types.PlayerProfile)
	if not WorldBuilder.lawnLive() then
		return
	end
	for _, spot in Layout.plot.lawnSpots do
		local pieceId = profile.lawn[spot.id]
		local piece = if pieceId ~= nil then Catalog.getLawn(pieceId) else nil
		show(
			plot,
			spot.id,
			if piece ~= nil then piece.model else nil,
			pieceId,
			pointAt(plot, spot.x, spot.y, spot.z, spot.rotY)
		)
		plot.model:SetAttribute(Lawn.spotAttribute(spot.id), if piece ~= nil then pieceId else nil)
	end
	local styles = profile.lawnStyles
	local path = Catalog.getLawnStyle(styles.path)
	local pathPoint = Layout.plot.lawnPath
	local laid = show(
		plot,
		"Path",
		if path ~= nil then path.model else nil,
		styles.path,
		pointAt(plot, pathPoint.x, pathPoint.y, pathPoint.z, 0)
	)
	showShellPath(plot, not laid)
	plot.model:SetAttribute(Lawn.PATH_ATTRIBUTE, styles.path)
	local fence = if styles.fence ~= nil then Catalog.getLawnStyle(styles.fence) else nil
	local line = Layout.plot.fenceLine
	show(
		plot,
		"Fence",
		if fence ~= nil then fence.model else nil,
		styles.fence,
		pointAt(plot, line.x, line.y, line.z, 0)
	)
	plot.model:SetAttribute(Lawn.FENCE_ATTRIBUTE, styles.fence)
end

-- An empty plot's lawn: no pieces, path or fence of an owner, the shell's own path, and no attributes.
function LawnBuilder.clear(plot: WorldBuilder.Plot)
	plot.lawn:ClearAllChildren()
	showShellPath(plot, true)
	for _, spot in Layout.plot.lawnSpots do
		plot.model:SetAttribute(Lawn.spotAttribute(spot.id), nil)
	end
	plot.model:SetAttribute(Lawn.PATH_ATTRIBUTE, nil)
	plot.model:SetAttribute(Lawn.FENCE_ATTRIBUTE, nil)
end

return LawnBuilder
