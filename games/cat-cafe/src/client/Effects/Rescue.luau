--!strict
-- Rescue traps (effects list section 4; Derek 2026-10-28 01:01: "rescue mini games like stuck in trash and others
-- should have a red exclamation mark coming out"): a red "!" pops up out of each trap that holds a stuck cat and
-- bobs over it, so players spot a rescue from across the area. It goes as soon as the cat is rescued or the trap
-- empties at dusk, and hides while someone is rescuing that cat or once you are close enough for its Rescue card.
-- The stuck poses are Animation-Engineer's.
--
-- Source: the StuckCat tag RescueService puts on the cat model in a trap, and that model's `LockedBy`. Listening
-- only. Numbers in Presets.stuckMark.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Rescue = {}

type Mark = {
	gui: BillboardGui,
	anchor: Attachment,
	tweens: { Tween },
	shown: boolean,
}

local marks: { [Model]: Mark } = {}
local started = false

-- The mark's size at `k` of full: studs tall plus pixels, so it never shrinks to a dot far away.
local function markSize(k: number): UDim2
	local m = Presets.stuckMark
	return UDim2.new(
		m.size * 0.6 * k,
		math.floor(m.pixels * 0.6 * k),
		m.size * k,
		math.floor(m.pixels * k)
	)
end

-- The top of a stuck cat (its head pokes out of the trap), or nil while it has not streamed in.
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
	local anchor = Particles.anchor("EffectsStuckMark", top + Vector3.new(0, m.above, 0))
	local gui = Instance.new("BillboardGui")
	gui.Name = "EffectsStuckMark"
	gui.Adornee = anchor
	gui.Size = markSize(1)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true -- seen over the bin's rim and across the area, like a quest marker
	gui.MaxDistance = m.maxDistance * 1.2 -- the check hides it first; this only stops a stale one drawing
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
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
	return { gui = gui, anchor = anchor, tweens = {}, shown = false }
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
	if Context.reducedMotion() then
		gui.Size = markSize(1)
		gui.StudsOffsetWorldSpace = up
		return
	end
	gui.Size = markSize(0.2)
	gui.StudsOffsetWorldSpace = Vector3.zero
	local pop = TweenService:Create(
		gui,
		TweenInfo.new(m.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = markSize(1), StudsOffsetWorldSpace = up }
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

local function check()
	local focus = Context.focus()
	if focus == nil then
		return
	end
	local m = Presets.stuckMark
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
		wanted[model] = true
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
