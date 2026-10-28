--!strict
-- A stray's rarity from a distance (Derek 2026-10-28 01:25: "have some sort indicator of what rarity the cat is
-- before going up to it and looking at the name"): a small gem in the rarity colour bobs over every stray, so
-- players can pick their target from across the area (Common too since Derek 12:15: "common ones should also have a
-- gem"; the nearest Rare and better take the 12 slots first and Commons fill the rest), and a Mythical gem glints
-- now and then. It hides while someone is catching that cat and once you are close enough for its Catch card, which
-- names it. Gold cats keep their gold sparkle as well. Rescue.luau puts the same gem over a stuck cat's red "!"
-- (`Rarity.buildGem`).
--
-- Source: the Stray tag CatService puts on each stray model, and its `Rarity` and `LockedBy`. The gem rides the
-- cat's body part, so it follows a walking or fleeing cat with nothing to move each frame. Listening only. Numbers
-- in Presets.rarityMark.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)

local Rarity = {}

type Mark = {
	gui: BillboardGui,
	body: BasePart, -- what the gem rides; a cat streamed out and back in gets a new one
	glint: Frame?,
	tweens: { Tween },
	height: number, -- studs over the body part
	shown: boolean,
}

local marks: { [Model]: Mark } = {}
local started = false

local function bodyOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local part = model:FindFirstChildWhichIsA("BasePart", true)
	return if part ~= nil then part :: BasePart else nil
end

-- Builds a gem in `rarity`'s colour into `parent`, which is square on screen, and returns its glint for a rarity
-- that glints. Builds nothing and returns false for a rarity with no colour.
function Rarity.buildGem(parent: Instance, rarity: string): (boolean, Frame?)
	local colour: Color3? = Presets.rarity[rarity]
	if colour == nil then
		return false, nil
	end
	local r = Presets.rarityMark
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromScale(r.gem, r.gem)
	gem.Rotation = 45
	gem.BackgroundColor3 = Color3.new(1, 1, 1)
	gem.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(r.corner, 0)
	corner.Parent = gem
	-- lit from the top: the gradient runs from the top corner to the bottom one of the turned square
	local shading = Instance.new("UIGradient")
	shading.Rotation = 45
	shading.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour:Lerp(Color3.new(1, 1, 1), r.light)),
		ColorSequenceKeypoint.new(0.5, colour),
		ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), r.dark)),
	})
	shading.Parent = gem
	local stroke = Instance.new("UIStroke")
	stroke.Color = r.outline
	stroke.Thickness = r.outlinePixels
	stroke.Parent = gem
	gem.Parent = parent
	local glint: Frame? = nil
	if r.glints[rarity] then
		local spark = Instance.new("Frame")
		spark.Name = "Glint"
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromScale(0.78, 0.2)
		spark.Size = UDim2.fromScale(0, 0)
		spark.Rotation = 45
		spark.BackgroundColor3 = Color3.new(1, 1, 1)
		spark.BorderSizePixel = 0
		spark.ZIndex = 2
		spark.Parent = parent
		glint = spark
	end
	return true, glint
end

-- Glints `glint` (from buildGem) now and then, for as long as the returned tween runs.
function Rarity.playGlint(glint: Frame): Tween
	local r = Presets.rarityMark
	glint.Size = UDim2.fromScale(0, 0)
	local tween = TweenService:Create(
		glint,
		TweenInfo.new(
			r.glintSeconds,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			-1,
			true,
			r.glintEvery - 2 * r.glintSeconds
		),
		{ Size = UDim2.fromScale(r.glintSize, r.glintSize) }
	)
	tween:Play()
	return tween
end

-- A glint held still, for Reduce Motion.
function Rarity.stillGlint(glint: Frame)
	local r = Presets.rarityMark
	glint.Size = UDim2.fromScale(r.glintSize * 0.6, r.glintSize * 0.6)
end

local function makeMark(model: Model, rarity: string): Mark?
	local body = bodyOf(model)
	if body == nil then
		return nil -- not streamed in yet
	end
	local r = Presets.rarityMark
	local frame, size = model:GetBoundingBox()
	local top = frame.Position.Y + Logic.halfExtents(frame, size).Y
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsRarityMark"
	gui.Adornee = body
	gui.Size = UDim2.new(r.size, r.pixels, r.size, r.pixels)
	gui.LightInfluence = 0
	gui.MaxDistance = r.maxDistance * 1.2 -- the check hides it first; this only stops a stale one drawing
	gui.Enabled = false
	local built, glint = Rarity.buildGem(gui, rarity)
	if not built then
		gui:Destroy()
		return nil
	end
	gui.Parent = Context.folder()
	return {
		gui = gui,
		body = body,
		glint = glint,
		tweens = {},
		height = top - body.Position.Y + r.above,
		shown = false,
	}
end

local function stopTweens(mark: Mark)
	for _, tween in mark.tweens do
		tween:Cancel()
	end
	table.clear(mark.tweens)
end

local function play(mark: Mark, instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	table.insert(mark.tweens, tween)
end

local function show(mark: Mark)
	if mark.shown then
		return
	end
	mark.shown = true
	stopTweens(mark)
	local r = Presets.rarityMark
	local up = Vector3.new(0, mark.height, 0)
	mark.gui.StudsOffsetWorldSpace = up
	mark.gui.Enabled = true
	local glint = mark.glint
	if Context.reducedMotion() then
		if glint ~= nil then
			Rarity.stillGlint(glint)
		end
		return
	end
	play(
		mark,
		mark.gui,
		TweenInfo.new(r.bobSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffsetWorldSpace = up + Vector3.new(0, r.bob, 0) }
	)
	if glint ~= nil then
		table.insert(mark.tweens, Rarity.playGlint(glint))
	end
end

local function hide(mark: Mark)
	if not mark.shown then
		return
	end
	mark.shown = false
	stopTweens(mark)
	mark.gui.Enabled = false
end

local function remove(model: Instance)
	local mark: Mark? = marks[model :: Model]
	if mark == nil then
		return
	end
	marks[model :: Model] = nil
	stopTweens(mark)
	mark.gui:Destroy()
end

local function check()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local r = Presets.rarityMark
	local candidates: { Logic.Candidate<Model> } = {}
	local commons: { Logic.Candidate<Model> } = {} -- behind the rest for the `most` slots, so a Rare still shows
	for _, instance in CollectionService:GetTagged("Stray") do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local model = instance :: Model
			local mark = marks[model]
			local distance = (model:GetPivot().Position - focus).Magnitude
			local rarity = model:GetAttribute("Rarity")
			if
				Logic.rarityMarkShows(
					rarity,
					model:GetAttribute("LockedBy"),
					distance,
					mark ~= nil and mark.shown
				)
			then
				table.insert(
					if rarity == "Common" then commons else candidates,
					{ key = model, distance = distance }
				)
			end
		end
	end
	local wanted: { [Model]: boolean } = {}
	for _, model in Logic.nearestFirst(candidates, commons, r.maxDistance, r.most) do
		wanted[model] = true
	end
	for model, mark in marks do
		if
			model.Parent == nil
			or not CollectionService:HasTag(model, "Stray")
			or not mark.body:IsDescendantOf(model)
		then
			remove(model)
		elseif not wanted[model] then
			hide(mark)
		end
	end
	for model in wanted do
		local mark = marks[model] or makeMark(model, model:GetAttribute("Rarity") :: string)
		if mark ~= nil then
			marks[model] = mark
			show(mark)
		end
	end
end

function Rarity.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal("Stray"):Connect(remove) -- caught or gone: at once
	task.spawn(function()
		while true do
			check()
			task.wait(Presets.rarityMark.checkEvery)
		end
	end)
end

return Rarity
