--!strict
-- Petting a cat in your cafe (#3651, Derek 2026-11-12: "make it have an animation/sound/vfx also"). The player's
-- free left arm reaches down and strokes twice (the right keeps the net), the cat perks up, a few pink hearts puff
-- over its head and it purrs for a moment. When the heart moves from another cat, a small pink heart arcs
-- from the old cat to the new one first and the puff plays as it lands.
--   PetCat.pet(userId, cat, from)   plays the whole moment for the player `userId` petting `cat`; `from` is the
--                                   cat that had the heart before, or nil
--   PetCat.layer(userId, rig)       the petting arm for Tackle's frame, like PalWave.layer
--   PetCat.onBeat(listener)         "pet" (the hand reaches the cat) and "heart" (the moved heart lands), each with
--                                   the place, for the sounds (Audio follows them)
-- Source: Gameplay-Engineer's `Moments.CatPetted(userId, cat, from)`, or until Moments has it the server's
-- `CatPetted(userId, cat, from)` remote once it exists. Every client near the cafe may play it, so visitors see it
-- too. A character carrying a cat keeps its arms on the cat (Tackle). Reduce Motion keeps the hearts and the purr and
-- drops the arm, the perk and the flying heart. Listening only: nothing here fires a remote or changes game state.

local RunService = game:GetService("RunService")

local Avatar = require(script.Parent.Avatar)
local Cats = require(script.Parent.Cats)
local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local PetCat = {}

local starts: { [number]: number } = {} -- each petting player's UserId, and the os.clock() the reach starts
local started = false

local listeners: { (beat: string, at: Vector3) -> () } = {}

function PetCat.onBeat(listener: (beat: string, at: Vector3) -> ())
	table.insert(listeners, listener)
end

local function beat(name: string, at: Vector3)
	for _, listener in listeners do
		task.spawn(listener, name, at)
	end
end

-- Where the hearts go over a cat: its Head's BubbleAnchor, else `up` studs over its pivot.
local function over(cat: Model): Vector3?
	if cat.Parent == nil then
		return nil
	end
	local head = cat:FindFirstChild("Head", true)
	local anchor = if head ~= nil then head:FindFirstChild("BubbleAnchor") else nil
	if anchor ~= nil and anchor:IsA("Attachment") then
		return (anchor :: Attachment).WorldPosition
	end
	return cat:GetPivot().Position + Vector3.new(0, Presets.petCat.up, 0)
end

-- One heart on a billboard: the ♥ glyph in the heart colour with a dark edge, `size` studs tall, at `at`.
local function heart(at: Vector3, size: number, colour: Color3): (Part, BillboardGui, TextLabel)
	local part = Context.effectPart("PetHeart", Vector3.one * 0.2, colour)
	part.Transparency = 1
	part.Position = at
	local gui = Instance.new("BillboardGui")
	gui.Name = "Heart"
	gui.Size = UDim2.fromScale(size, size)
	gui.LightInfluence = 0
	gui.MaxDistance = Presets.petCat.range
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "♥"
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeColor3 = Presets.petCat.edge
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = part
	part.Parent = Context.folder()
	return part, gui, label
end

-- The heart puff: `count` hearts float up from `at`, fanned out, growing a little and fading (Logic.petHeart).
local function hearts(at: Vector3, count: number, colour: Color3)
	local p = Presets.petCat
	local made: { { gui: BillboardGui, label: TextLabel } } = {}
	local anchor: Part? = nil
	for index = 1, count do
		local part, gui, label = heart(at, p.heartSize, colour)
		if anchor == nil then
			anchor = part
		else
			gui.Adornee = anchor
			gui.Parent = anchor
			part:Destroy()
		end
		made[index] = { gui = gui, label = label }
	end
	if anchor == nil then
		return
	end
	local holder: Part = anchor
	local began = os.clock()
	local step: RBXScriptConnection? = nil
	step = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - began) / p.heartSeconds
		if u >= 1 or holder.Parent == nil then
			if step ~= nil then
				step:Disconnect()
				step = nil
			end
			holder:Destroy()
			return
		end
		for index, one in made do
			local offset, scale, fade = Logic.petHeart(index, count, u, p.heartRise, p.heartFan)
			one.gui.StudsOffset = offset
			one.gui.Size = UDim2.fromScale(p.heartSize * scale, p.heartSize * scale)
			one.label.TextTransparency = fade
			one.label.TextStrokeTransparency = 0.4 + 0.6 * fade
		end
	end)
end

local function puff(cat: Model)
	local p = Presets.petCat
	local at = over(cat)
	if at == nil then
		return
	end
	hearts(at, math.max(1, math.ceil(p.hearts * Context.budget.burstScale)), p.colour)
	if not Context.reducedMotion() then
		Cats.react(cat, "perk")
	end
	beat("pet", at)
end

-- The heart's move from the old cat to the new one: one grey heart fades up off the old cat while a pink heart
-- arcs over to the new one, then `done()`.
local function move(from: Model, to: Model, done: () -> ())
	local p = Presets.petCat
	local start = over(from)
	if start == nil or Context.reducedMotion() then
		done()
		return
	end
	local a: Vector3 = start
	hearts(a, 1, p.lost)
	local part = heart(a, p.move.size, p.colour)
	local began = os.clock()
	local step: RBXScriptConnection? = nil
	step = RunService.Heartbeat:Connect(function()
		local alpha = (os.clock() - began) / p.move.seconds
		local target = over(to)
		if alpha >= 1 or target == nil or part.Parent == nil then
			if step ~= nil then
				step:Disconnect()
				step = nil
			end
			part:Destroy()
			if target ~= nil then
				beat("heart", target)
			end
			done()
			return
		end
		part.Position = Logic.hopArc(a, target, p.move.height, alpha)
	end)
end

function PetCat.pet(userId: number?, cat: Model, from: Model?)
	local p = Presets.petCat
	local at = cat:GetPivot().Position
	if Context.distance(at) > p.range then
		return
	end
	if userId ~= nil and not Context.reducedMotion() then
		starts[userId] = os.clock()
	end
	-- the puff waits for the hand to reach the cat, and for the moved heart when there is one
	local reach = if Context.reducedMotion() then 0 else p.raise
	local function land()
		if cat.Parent ~= nil then
			puff(cat)
		end
	end
	task.delay(reach, function()
		if from ~= nil and from ~= cat and from.Parent ~= nil then
			move(from, cat, land)
		else
			land()
		end
	end)
end

-- The petting arm over a player's character this frame: its left arm's Transforms and how much of them to show,
-- or nil and 0 when that player is not petting.
function PetCat.layer(userId: number, rig: Avatar.Rig): ({ [Avatar.Joint]: CFrame }?, number)
	local at = starts[userId]
	if at == nil then
		return nil, 0
	end
	local p = Presets.petCat
	local weight, stroke = Logic.petAt(os.clock() - at, p.raise, p.strokes, p.every, p.lower)
	if weight <= 0 then
		if os.clock() - at > 0 then
			starts[userId] = nil
		end
		return nil, 0
	end
	return Avatar.petArm(rig, stroke), weight
end

local function petted(userId: unknown, cat: unknown, from: unknown)
	if typeof(cat) ~= "Instance" or not (cat :: Instance):IsA("Model") then
		return
	end
	local old: Model? = nil
	if typeof(from) == "Instance" and (from :: Instance):IsA("Model") then
		old = from :: Model
	end
	PetCat.pet(if type(userId) == "number" then userId else nil, cat :: Model, old)
end

function PetCat.start()
	if started then
		return
	end
	started = true
	local moment = (Moments :: any).CatPetted
	if moment ~= nil then
		moment:Connect(petted)
	else
		Context.whenRemote("CatPetted", function(remote: RemoteEvent)
			remote.OnClientEvent:Connect(petted)
		end)
	end
end

return PetCat
