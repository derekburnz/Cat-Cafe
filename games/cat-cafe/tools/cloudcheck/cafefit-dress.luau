--[[
	Cafe fit dresser (QA, 2026-11-02, for the bigger cafes): dresses each plot of a built world the way the server
	does for an owner, so cafefit.mjs can scan the rooms full. Called with (Shim, world, builder, options):

	  options.tiers   the tier for each plot in order (0 is For Rent: nothing else goes in)
	  options.pieces  the crate decor assets to stand at the decor spots: plot p's spot n gets
	                  pieces[(p + n) % #pieces + 1], so eight plots stand every piece at every spot once there are
	                  at least as many plots as pieces

	An owned plot gets what CafeService puts in at its fullest: every table with both chairs and the customers' way
	points (Aisle and Approach, as refreshTables sets them), the top espresso machine, the Lucky Cat at level 5, every
	shop decor piece on its own anchor, the crate decor above at all eight spots, and a front lawn as LawnBuilder
	draws it with every spot open at the tier filled and a path and fence that change from plot to plot.

	Returns one line per plot and per chair for cafefit.mjs (tab separated, world studs):
	  PLOT  p  tier  cframe (12 numbers)
	  CHAIR p  table  seat  pivot (3)  aisle (3)  approach (3)
	  WAY   p  Entry|Door|Order  position (3)   the customers' waypoints (CustomerWaypoints)
	  BACKDOOR p  cframe (12)                     the back door panel
  CAM   p  shot  cut  from|via|to  position (3)  look (3)   the intro's camera places (Intro.shots, new save)
]]

local Shim, world, builder, options = ...
local find = function(path)
	return (Shim.find(path))
end
local require = Shim.require

local Catalog = require(find("ReplicatedStorage.Shared.Catalog"))
local Lawn = require(find("ReplicatedStorage.Shared.Lawn"))
local Layout = require(find("ServerScriptService.Server.World.Layout"))
local AssetRegistry = require(find("ServerScriptService.Server.World.AssetRegistry"))
local LawnBuilder = require(find("ServerScriptService.Server.World.LawnBuilder"))

local lines = {}
local function cf(c)
	local parts = { c:GetComponents() }
	for i, v in parts do
		parts[i] = string.format("%.4f", v)
	end
	return table.concat(parts, "\t")
end
local function v3(v)
	return string.format("%.4f\t%.4f\t%.4f", v.X, v.Y, v.Z)
end

local function placeAt(asset, at, parent, name)
	if not AssetRegistry.has(asset) then
		return nil
	end
	local model = AssetRegistry.clone(asset)
	model.Name = name or asset
	model:PivotTo(at)
	model.Parent = parent
	return model
end

-- Lawn pieces by size and the styles by kind, in catalog order.
local small, big, paths, fences = {}, {}, {}, {}
for _, piece in Catalog.lawn or {} do
	table.insert(if piece.spot == "big" then big else small, piece.id)
end
for _, style in Catalog.lawnStyles or {} do
	table.insert(if style.kind == "path" then paths else fences, style.id)
end

local pieces = options.pieces
local plots = world.plots
for p, plot in plots do
	local tier = options.tiers[p] or 5
	builder.setDressing(plot, tier)
	builder.setBackDoorOpen(plot, tier >= 1)
	for n, expansion in plot.expansions do
		builder.setExpansionOpen(expansion, tier >= n + 1)
	end
	table.insert(lines, string.format("PLOT\t%d\t%d\t%s", p, tier, cf(plot.cframe)))
	local waypoints = plot.model:FindFirstChild("CustomerWaypoints")
	for _, name in { "Entry", "Door", "Order" } do
		local point = if waypoints ~= nil then waypoints:FindFirstChild(name) else nil
		if point ~= nil then
			table.insert(lines, string.format("WAY\t%d\t%s\t%s", p, name, v3(point.Position)))
		end
	end
	table.insert(lines, string.format("BACKDOOR\t%d\t%s", p, cf(plot.backDoor.CFrame)))
	if tier < 1 then
		continue
	end
	-- tables and chairs with the customers' way points (CafeService refreshTables)
	for i, anchor in plot.tableAnchors do
		local spot = Layout.plot.tables[i]
		local group = Instance.new("Model")
		group.Name = "table_" .. i
		placeAt("CatCafe_Furniture_TableRound", anchor.CFrame, group)
		for s, offset in Layout.plot.seatOffsets do
			local at = anchor.CFrame
				* CFrame.new(offset.x, offset.y, offset.z)
				* CFrame.Angles(0, math.rad(offset.rotY or 0), 0)
			local chair = placeAt("CatCafe_Furniture_Chair", at, group, "Chair_" .. s)
			if chair ~= nil and spot ~= nil then
				local x = spot.x + offset.x
				local side = if x < 0 then -1 else 1
				local aisle = (plot.cframe * CFrame.new(side * Layout.plot.aisleX, 0, spot.lane)).Position
				local approach = (plot.cframe * CFrame.new(x, 0, spot.lane)).Position
				table.insert(
					lines,
					string.format(
						"CHAIR\t%d\t%d\t%d\t%s\t%s\t%s",
						p,
						i,
						s,
						v3(chair:GetPivot().Position),
						v3(aisle),
						v3(approach)
					)
				)
			end
		end
		group.Parent = plot.tables
	end
	placeAt("CatCafe_Furniture_EspressoMachine_L3", plot.espresso.CFrame, plot.model, "Espresso")
	placeAt("CatCafe_Plot_LuckyCat_5", plot.luckyCat.CFrame, plot.model, "LuckyCat")
	-- shop pieces on their own anchors (the plants, the rug, the neon sign, the Index boards)
	for _, def in Catalog.decor do
		local anchor = plot.decorAnchors[def.id]
		if anchor ~= nil and def.asset ~= nil then
			placeAt(def.asset, anchor.CFrame, plot.decor, def.id)
		end
	end
	-- crate decor at the decor spots
	for n, spot in plot.decorSpots do
		local asset = pieces[(p + n) % #pieces + 1]
		placeAt(asset, spot.CFrame, plot.decor, "Spot" .. n .. "_" .. asset)
	end
	-- the front lawn, every spot open at the tier filled, a path and fence that change from plot to plot
	local lawn = {}
	local nextSmall, nextBig = p, p
	for _, spot in Lawn.SPOTS do
		if tier >= spot.tier then
			if spot.size == "big" and #big > 0 then
				lawn[spot.id] = big[nextBig % #big + 1]
				nextBig += 3
			elseif spot.size ~= "big" and #small > 0 then
				lawn[spot.id] = small[nextSmall % #small + 1]
				nextSmall += 5
			end
		end
	end
	if #paths > 0 and #fences > 0 then
		LawnBuilder.refresh(plot, {
			lawn = lawn,
			lawnStyles = { path = paths[p % #paths + 1], fence = fences[p % #fences + 1] },
		})
	end
end

-- The intro's camera places for each cafe as a new save sees it (Intro.shots with the Codes Cat and the Alleyway's camp
-- streamed in), for cafefit.mjs to check that no camera stands inside a part or looks through a wall.
local Intro = require(find("ReplicatedStorage.Shared.Intro"))
for p = 1, #plots do
	local ok, shots = pcall(Intro.shots, Intro.plot(p), true, true)
	if not ok then
		table.insert(lines, string.format("CAMERR\t%d\t%s", p, tostring(shots)))
		continue
	end
	for _, shot in shots do
		for c, cut in shot.cuts do
			for _, which in { "from", "via", "to" } do
				local key = cut[which]
				if key ~= nil then
					table.insert(
						lines,
						string.format(
							"CAM\t%d\t%d\t%d\t%s\t%s\t%s",
							p,
							shot.index,
							c,
							which,
							v3(key.position),
							v3(key.look)
						)
					)
				end
			end
		end
	end
end

return table.concat(lines, "\n")
