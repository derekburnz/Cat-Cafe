--!strict
-- The fairground's bulbs chase (#4070: "ride lamps chase slowly"). Model-Agent's booths, wall boards, hedges and the
-- camp's ticket front each carry their bulbs in a `_Bulbs` Model. On the rows nearest you, every few bulbs wears a
-- brighter cover and the lit ones step along the row (round the frame, where the bulbs ring one), so any one bulb
-- lights well under once a second. It runs by day too, at half the pace: the areas close at night and everyone is
-- sent home, so a chase kept for the night would never be seen in the Water Park (Review-QA, #4206). At night
-- WorldController makes the bulbs themselves glow and the chase runs over that. The bulbs are never changed: the
-- covers are this client's own parts. None with Reduce Motion or in Low performance. Listening only. Numbers in
-- Presets.bulbChase.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local BulbChase = {}

type Row = {
	model: Model,
	bulbs: { BasePart }, -- in chase order
	covers: { Part },
	on: boolean,
	offset: number, -- so two rows never step as one
}

local rows: { [Instance]: Row } = {}
local started = false

-- Whether a Model's name marks a row of bulbs that chases.
function BulbChase.isRow(name: string): boolean
	for _, piece in Presets.bulbChase.pieces do
		if #name >= #piece and string.sub(name, -#piece) == piece then
			return true
		end
	end
	return false
end

-- The order the chase runs through bulbs at `points`: along the line they make, or round their middle when they
-- spread across a second axis too (a frame of bulbs). Returns the points' indexes.
function BulbChase.order(points: { Vector3 }): { number }
	local n = #points
	local order: { number } = {}
	if n == 0 then
		return order
	end
	-- each point as { x, y, z }, their middle and how far they spread along each axis
	local at: { { number } } = {}
	local low = { math.huge, math.huge, math.huge }
	local high = { -math.huge, -math.huge, -math.huge }
	local middle = { 0, 0, 0 }
	for i, point in points do
		order[i] = i
		at[i] = { point.X, point.Y, point.Z }
		for axis = 1, 3 do
			low[axis] = math.min(low[axis], at[i][axis])
			high[axis] = math.max(high[axis], at[i][axis])
			middle[axis] += at[i][axis] / n
		end
	end
	local axes = { 1, 2, 3 }
	table.sort(axes, function(a: number, b: number): boolean
		local spanA, spanB = high[a] - low[a], high[b] - low[b]
		if spanA ~= spanB then
			return spanA > spanB
		end
		return a < b
	end)
	local first, second = axes[1], axes[2]
	local widest = high[first] - low[first]
	local round = widest > 0 and (high[second] - low[second]) / widest >= Presets.bulbChase.round
	local key: { number } = {}
	for i = 1, n do
		key[i] = if round
			then math.atan2(at[i][second] - middle[second], at[i][first] - middle[first])
			else at[i][first]
	end
	table.sort(order, function(a: number, b: number): boolean
		if key[a] ~= key[b] then
			return key[a] < key[b]
		end
		return a < b
	end)
	return order
end

-- Which bulb (1 to `count`) the `k`th cover sits on at `step`.
function BulbChase.lit(k: number, step: number, count: number): number
	return ((k - 1) * Presets.bulbChase.gap + step) % count + 1
end

-- How many covers a row of `count` bulbs wears.
function BulbChase.covers(count: number): number
	return math.floor(count / Presets.bulbChase.gap)
end

local function stop(row: Row)
	for _, cover in row.covers do
		cover:Destroy()
	end
	table.clear(row.covers)
	table.clear(row.bulbs)
	row.on = false
end

local function bulbsOf(model: Model): { BasePart }
	local found: { BasePart } = {}
	local points: { Vector3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(found, d :: BasePart)
			table.insert(points, (d :: BasePart).Position)
		end
	end
	local bulbs: { BasePart } = {}
	for i, index in BulbChase.order(points) do
		bulbs[i] = found[index]
	end
	return bulbs
end

local function light(row: Row)
	local o = Presets.bulbChase
	row.bulbs = bulbsOf(row.model)
	for _ = 1, BulbChase.covers(#row.bulbs) do
		local cover = Context.effectPart("EffectsBulbCover", Vector3.one, o.on)
		cover.Material = Enum.Material.Neon
		cover.Shape = Enum.PartType.Ball
		cover.Parent = Context.folder()
		table.insert(row.covers, cover)
	end
	row.on = true
end

local function step(row: Row, now: number)
	local o = Presets.bulbChase
	local count = #row.bulbs
	if count == 0 then
		return
	end
	local at = math.floor((now + row.offset) * (if Context.isNight() then o.hz else o.hzDay))
	for k, cover in row.covers do
		local bulb = row.bulbs[BulbChase.lit(k, at, count)]
		if bulb.Parent ~= nil then
			local size = bulb.Size * o.grow
			local widest = math.max(size.X, size.Y, size.Z)
			cover.Size = Vector3.new(widest, widest, widest)
			cover.CFrame = bulb.CFrame
		end
	end
end

local function consider(instance: Instance)
	if instance:IsA("Model") and rows[instance] == nil and BulbChase.isRow(instance.Name) then
		rows[instance] = {
			model = instance :: Model,
			bulbs = {},
			covers = {},
			on = false,
			offset = math.random() * 10,
		}
	end
end

local chosen: { [Row]: boolean } = {}

local function pick()
	local o = Presets.bulbChase
	table.clear(chosen)
	local still = Context.reducedMotion() or Context.lowPerformance
	local candidates: { Logic.Candidate<Row> } = {}
	for model, row in rows do
		if not model:IsDescendantOf(Workspace) then
			stop(row)
			rows[model] = nil
		elseif not still then
			local part = model:FindFirstChildWhichIsA("BasePart", true)
			if part ~= nil then
				table.insert(candidates, { key = row, distance = Context.distance(part.Position) })
			end
		end
	end
	local most = if Context.lite then o.mostLite else o.most
	for _, row in Logic.nearest(candidates, o.within, most) do
		chosen[row] = true
		if not row.on then
			light(row)
		end
	end
	for _, row in rows do
		if row.on and not chosen[row] then
			stop(row)
		end
	end
end

function BulbChase.start()
	if started then
		return
	end
	started = true
	for _, descendant in Workspace:GetDescendants() do
		consider(descendant)
	end
	Workspace.DescendantAdded:Connect(function(descendant: Instance)
		local parent = descendant.Parent
		local known: Row? = if parent ~= nil then rows[parent] else nil
		if known ~= nil and known.on and descendant:IsA("BasePart") then
			stop(known) -- more of its bulbs streamed in: order them again at the next pick
		elseif descendant:IsA("Model") then
			consider(descendant)
		end
	end)
	task.spawn(function()
		while true do
			pick()
			task.wait(Presets.bulbChase.pick)
		end
	end)
	task.spawn(function()
		while true do
			local now = os.clock()
			for row in chosen do
				if row.on then
					step(row, now)
				end
			end
			task.wait(1 / Presets.bulbChase.hz / 2)
		end
	end)
end

return BulbChase
