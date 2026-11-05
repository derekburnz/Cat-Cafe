--!strict
-- The Cat Whistle's marker (corner-shop-v2.md section 4, corner-shop.md's v2 note): while the cat_whistle buff runs,
-- every 0.5 s the nearest stray or trapped cat in reach gets a WorldMarker paw over it, and the local attribute
-- WhistleTarget = true (cleared on the one before), which VFX-Agent's ring effect reads. Client only: it shows what
-- the server already replicates, so it changes nothing about catching.
-- #1458 (the friend 11-05: "increase the stray nearby pop up with potion because gem stones appear first"): the reach
-- is 1,000 studs (it was 600, and its marker drew only within 500), the marker draws as far as the reach
-- (CatWhistle.REACH, passed to WorldMarker.new), and it looks every 0.25 s, so the paw is up well before any rarity
-- gem (Effects/Rarity, 80 studs) comes into view.
--
--   CatWhistle.pick(from, candidates, maxStuds)   the nearest candidate within maxStuds, or nil (pure, for the specs)
--   CatWhistle.new(marker, running)                the marker, picking while running() is true; :destroy()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- WorldMarker's shape, not the module (it loads Theme, which the cloud tests can't)
type Marker = {
	show: (self: any, target: BasePart, label: string, color: Color3?) -> (),
	hide: (self: any) -> (),
}

local CatWhistle = {}
CatWhistle.__index = CatWhistle

local STEP = 0.25 -- seconds between picks
local REACH = 1000 -- studs: "the current area" without a zone lookup; an area is smaller than this
CatWhistle.REACH = REACH
local ATTRIBUTE = "WhistleTarget"
local PAW = Color3.fromRGB(255, 201, 77)

export type Candidate = { model: Model, position: Vector3 }

function CatWhistle.pick(from: Vector3, candidates: { Candidate }, maxStuds: number): Model?
	local best: Model? = nil
	local bestDistance = maxStuds
	for _, candidate in candidates do
		local distance = (candidate.position - from).Magnitude
		if distance <= bestDistance then
			best = candidate.model
			bestDistance = distance
		end
	end
	return best
end

local function bodyOf(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary ~= nil then
		return primary
	end
	return model:FindFirstChildWhichIsA("BasePart") :: BasePart?
end

-- Strays (tagged Stray) and trapped cats (tagged StuckCat) the player could go to: not another beginner's tutorial stray.
local function candidates(userId: number): { Candidate }
	local out: { Candidate } = {}
	local world = Workspace:FindFirstChild("World")
	local folder = if world then world:FindFirstChild("Strays") else nil
	local seen: { [Instance]: boolean } = {}
	local pool: { Instance } = CollectionService:GetTagged("Stray")
	for _, stuck in CollectionService:GetTagged("StuckCat") do -- trapped cats (RescueService)
		table.insert(pool, stuck)
	end
	if folder then
		for _, child in folder:GetChildren() do
			table.insert(pool, child)
		end
	end
	for _, instance in pool do
		if
			seen[instance]
			or not instance:IsA("Model")
			or not instance:IsDescendantOf(Workspace)
		then
			continue
		end
		seen[instance] = true
		local model = instance :: Model
		local beginner = model:GetAttribute("Beginner")
		if type(beginner) == "number" and beginner ~= 0 and beginner ~= userId then
			continue
		end
		local body = bodyOf(model)
		if body then
			table.insert(out, { model = model, position = body.Position })
		end
	end
	return out
end

export type CatWhistle = {
	destroy: (self: CatWhistle) -> (),
}

-- `running` says whether the cat_whistle buff runs now; checked every step, so the marker goes when it ends.
function CatWhistle.new(marker: Marker, running: () -> boolean): CatWhistle
	local self = setmetatable({}, CatWhistle) :: any
	self._marker = marker
	self._target = nil :: Model?
	self._running = running
	local clock = STEP -- the first pick on the first frame
	self._loop = RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < STEP then
			return
		end
		clock = 0
		self:_step()
	end)
	return self :: CatWhistle
end

function CatWhistle._set(self: any, model: Model?)
	local old: Model? = self._target
	if old == model then
		return
	end
	if old and old.Parent then
		old:SetAttribute(ATTRIBUTE, nil)
	end
	self._target = model
	if model then
		model:SetAttribute(ATTRIBUTE, true)
		local body = bodyOf(model)
		if body then
			self._marker:show(body, "🐾 Stray nearby", PAW)
		end
	else
		self._marker:hide()
	end
end

function CatWhistle._step(self: any)
	if not self._running() then
		self:_set(nil)
		return
	end
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		self:_set(nil)
		return
	end
	local target = CatWhistle.pick((root :: BasePart).Position, candidates(player.UserId), REACH)
	if target and target.Parent == nil then
		target = nil
	end
	self:_set(target)
end

function CatWhistle.destroy(self: any)
	self._loop:Disconnect()
	self:_set(nil)
end

return CatWhistle
