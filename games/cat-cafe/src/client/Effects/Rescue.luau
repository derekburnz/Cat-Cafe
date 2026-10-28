--!strict
-- Rescue traps (effects list section 4; Derek 2026-10-28 01:01: "rescue mini games like stuck in trash and others
-- should have a red exclamation mark coming out"): a red "!" pops up out of each trap that holds a stuck cat and
-- bobs over it, so players spot a rescue they can see. Only one in view shows (Derek 12:13: "red exclamation marks
-- should only show if in view"): on screen, within 100 studs and not behind a wall, building or rock, and walls in
-- front of it hide it as they would the trap. It goes as soon as the cat is rescued or the trap empties at dusk, and
-- hides while someone is rescuing that cat or once you are close enough for its Rescue card. The stuck poses are
-- Animation-Engineer's. The cat's rarity gem hovers just above the "!" (Derek 12:14: "gems should also appear over
-- rescue cats just hover it above exclamation mark"), the same gem strays wear (Rarity.buildGem), in view the same.
--
-- Source: the StuckCat tag RescueService puts on the cat model in a trap, and that model's `LockedBy` and `Rarity`; the camera
-- and a ray from it to the mark for "in view". Listening only. Numbers in Presets.stuckMark.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local Rarity = require(script.Parent.Rarity)

local Rescue = {}

type Mark = {
	gui: BillboardGui,
	anchor: Attachment,
	gem: boolean, -- the cat's rarity gem sits above the "!"
	glint: Frame?,
	tweens: { Tween },
	shown: boolean,
}

local marks: { [Model]: Mark } = {}
local seen: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any -- os.clock() each was last in view
local started = false
local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude

-- The mark's size at `k` of full: studs plus pixels, so it never shrinks to a dot far away. With a gem the billboard
-- grows upward to hold it over the "!", keeping the same pixels to a stud so the two never overlap.
local function markSize(k: number, gem: boolean): UDim2
	local m = Presets.stuckMark
	local wide, tall = m.size * 0.6, m.size
	if gem then
		wide = math.max(wide, m.gem)
		tall += m.gem + m.gemGap
	end
	local perStud = m.pixels / m.size
	return UDim2.new(
		wide * k,
		math.floor(wide * perStud * k),
		tall * k,
		math.floor(tall * perStud * k)
	)
end

-- The top of a stuck cat (whatever pokes out of the trap, its back end or the whole cat upside down), or nil while
-- it has not streamed in.
local function topOf(model: Model): Vector3?
	if model:FindFirstChildWhichIsA("BasePart", true) == nil then
		return nil
	end
	local frame, size = model:GetBoundingBox()
	return frame.Position + Vector3.new(0, Logic.halfExtents(frame, size).Y, 0)
end

local function makeMark(model: Model): Mark?
	local top = topOf(model)
	if top == nil then
		return nil
	end
	local m = Presets.stuckMark
	local rarity = model:GetAttribute("Rarity")
	local gem = type(rarity) == "string" and Presets.rarityMark.shows[rarity] == true
	local anchor = Particles.anchor("EffectsStuckMark", top + Vector3.new(0, m.above, 0))
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsStuckMark"
	gui.Adornee = anchor
	gui.Size = markSize(1, gem)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false -- walls and buildings in front hide it, as they hide the trap
	gui.MaxDistance = m.maxDistance * 1.2 -- the check hides it first; this only stops a stale one drawing
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	local glint: Frame? = nil
	if gem then
		-- the "!" along the bottom, the gem in a square over it; the billboard is raised by the gem's share so the
		-- "!" stays where it stands without one
		local wide, tall = math.max(m.size * 0.6, m.gem), m.size + m.gem + m.gemGap
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.fromScale(0.5, 1)
		label.Size = UDim2.fromScale(m.size * 0.6 / wide, m.size / tall)
		gui.SizeOffset = Vector2.new(0, 0.5 - m.size / (2 * tall))
		local holder = Instance.new("Frame")
		holder.Name = "Gem"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.fromScale(0.5, 0)
		holder.Size = UDim2.fromScale(m.gem / wide, m.gem / tall)
		holder.Parent = gui
		local built, spark = Rarity.buildGem(holder, rarity :: string)
		gem = built
		glint = spark
	end
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = "!"
	label.TextScaled = true
	label.TextColor3 = m.colour
	local stroke = Instance.new("UIStroke")
	stroke.Color = m.outline
	stroke.Thickness = m.outlinePixels
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = Context.folder()
	return { gui = gui, anchor = anchor, gem = gem, glint = glint, tweens = {}, shown = false }
end

local function stopTweens(mark: Mark)
	for _, tween in mark.tweens do
		tween:Cancel()
	end
	table.clear(mark.tweens)
end

-- Pops the mark up out of the trap, then bobs it.
local function show(mark: Mark)
	if mark.shown then
		return
	end
	mark.shown = true
	stopTweens(mark)
	local m = Presets.stuckMark
	local gui = mark.gui
	gui.Enabled = true
	local up = Vector3.new(0, m.rise, 0)
	local glint = mark.glint
	if Context.reducedMotion() then
		gui.Size = markSize(1, mark.gem)
		gui.StudsOffsetWorldSpace = up
		if glint ~= nil then
			Rarity.stillGlint(glint)
		end
		return
	end
	if glint ~= nil then
		table.insert(mark.tweens, Rarity.playGlint(glint))
	end
	gui.Size = markSize(0.2, mark.gem)
	gui.StudsOffsetWorldSpace = Vector3.zero
	local pop = TweenService:Create(
		gui,
		TweenInfo.new(m.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = markSize(1, mark.gem), StudsOffsetWorldSpace = up }
	)
	pop.Completed:Connect(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or not mark.shown then
			return
		end
		local bob = TweenService:Create(
			gui,
			TweenInfo.new(m.bobSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ StudsOffsetWorldSpace = up + Vector3.new(0, m.bob, 0) }
		)
		bob:Play()
		table.insert(mark.tweens, bob)
	end)
	pop:Play()
	table.insert(mark.tweens, pop)
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
	mark.anchor:Destroy()
end

-- Whether the mark's spot over `model` is on screen with nothing solid between the camera and it. A see-through
-- part (glass, a leaf card, water) does not block it.
local function inView(model: Model, point: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return false
	end
	local _, onScreen = camera:WorldToViewportPoint(point)
	if not onScreen then
		return false
	end
	local from = camera.CFrame.Position
	local skip: { Instance } = { model, Context.folder() }
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(skip, character)
	end
	for _ = 1, Presets.stuckMark.seeThrough + 1 do
		sight.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(from, point - from, sight)
		if hit == nil then
			return true
		end
		if hit.Instance.Transparency < 0.5 then
			return false
		end
		table.insert(skip, hit.Instance)
	end
	return false
end

-- Where the mark stands (or will) over `model`, popped up: the point the camera has to see.
local function markPoint(model: Model, mark: Mark?): Vector3?
	local m = Presets.stuckMark
	if mark ~= nil then
		return mark.anchor.WorldPosition + Vector3.new(0, m.rise, 0)
	end
	local top = topOf(model)
	return if top ~= nil then top + Vector3.new(0, m.above + m.rise, 0) else nil
end

local function check()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local m = Presets.stuckMark
	local now = os.clock()
	local candidates: { Logic.Candidate<Model> } = {}
	for _, instance in CollectionService:GetTagged("StuckCat") do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			local model = instance :: Model
			local distance = (model:GetPivot().Position - focus).Magnitude
			local mark = marks[model]
			if
				Logic.stuckMarkShows(
					model:GetAttribute("LockedBy"),
					distance,
					mark ~= nil and mark.shown
				)
			then
				table.insert(candidates, { key = model, distance = distance })
			end
		end
	end
	local wanted: { [Model]: boolean } = {}
	for _, model in Logic.nearest(candidates, m.maxDistance, m.most) do
		local point = markPoint(model, marks[model])
		if point ~= nil and inView(model, point) then
			seen[model] = now
		end
		-- a moment's grace, so a lamp post or a passing player does not make it pop again and again
		if Logic.stillInView(seen[model], now, m.lostAfter) then
			wanted[model] = true
		end
	end
	for model, mark in marks do
		if model.Parent == nil or not CollectionService:HasTag(model, "StuckCat") then
			remove(model)
		elseif not wanted[model] then
			hide(mark)
		end
	end
	for model in wanted do
		local mark = marks[model] or makeMark(model)
		if mark ~= nil then
			marks[model] = mark
			show(mark)
		end
	end
end

function Rescue.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceRemovedSignal("StuckCat"):Connect(remove) -- rescued: gone at once
	task.spawn(function()
		while true do
			check()
			task.wait(Presets.stuckMark.checkEvery)
		end
	end)
end

return Rescue
