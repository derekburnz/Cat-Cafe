--!strict
-- #4913 Pal Day: the moment today's Pal Day gift is paid (the server's PalDayPaid, palDay switch), this player's
-- character waves and a puff of pink hearts floats up over its head, and each pal on the server within the hearts'
-- range waves back a beat later with a puff of its own, so playing together today feels like something. The loot card
-- (UIController) lists the gift; this adds the moment in the world. A heart chime plays through PalDayFx.onBeat
-- (Audio). Reduce Motion keeps the hearts and the chime and drops the waves. Numbers in Presets.palDay. Local only:
-- nothing here fires a remote or changes game state.
-- Before the gift (Design-Agent, Wed Nov 18): while the server's PalDayDue attribute on this player is true and the
-- palDay switch is on, a small still pink heart sits over the nearest Presets.palDay.heart.most pals in range, so a
-- player can see who to play beside. No glow, no sound, no pop-up. Idle until the server sets the attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local PalWave = require(script.Parent.PalWave)
local PetCat = require(script.Parent.PetCat)
local Presets = require(script.Parent.Presets)

local Pals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pals"))

local PalDayFx = {}

local player = Players.LocalPlayer
local started = false
local pals: { number } = {}
local listeners: { (beat: string, at: Vector3) -> () } = {}

-- (beat, at) "gift" when the hearts puff over this player; Audio plays the heart chime there.
function PalDayFx.onBeat(listener: (beat: string, at: Vector3) -> ())
	table.insert(listeners, listener)
end

-- Over a character's head: the Head's top, else `up` studs over its root; nil without a character.
local function overHead(who: Player): Vector3?
	local character = who.Character
	if character == nil then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, head.Size.Y * 0.5 + Presets.palDay.overHead, 0)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, Presets.palDay.up, 0)
	end
	return nil
end

local function celebrate(who: Player, after: number)
	task.delay(after, function()
		if who.Parent == nil then
			return
		end
		if not Context.reducedMotion() then
			PalWave.wave(who.UserId)
		end
		local at = overHead(who)
		if at ~= nil then
			PetCat.heartsAt(at, Presets.palDay.colour)
		end
	end)
end

local function paid()
	local mine = overHead(player)
	if mine == nil then
		return
	end
	celebrate(player, 0)
	for _, listener in listeners do
		task.spawn(listener, "gift", mine)
	end
	local p = Presets.palDay
	for _, userId in pals do
		local pal = Players:GetPlayerByUserId(userId)
		local at = if pal ~= nil and pal ~= player then overHead(pal) else nil
		if pal ~= nil and at ~= nil and (at - mine).Magnitude <= p.range then
			celebrate(pal, p.palDelay)
		end
	end
end

-- PalsChanged's list, kept as this player's pals on the server (numbers only).
local function setPals(userIds: unknown)
	local out: { number } = {}
	if type(userIds) == "table" then
		for _, id in userIds :: { unknown } do
			if type(id) == "number" and #out < Presets.palDay.most then
				table.insert(out, id)
			end
		end
	end
	pals = out
end

-- #4913: whether the hearts over pals show now: today's gift still to earn and the switch on. Pure.
function PalDayFx.heartsOn(due: unknown, switch: unknown): boolean
	return due == true and switch == true
end

local hearts: { [Player]: BillboardGui } = {}

local function heartFor(pal: Player, head: BasePart): BillboardGui
	local h = Presets.palDay.heart
	local had: BillboardGui? = hearts[pal]
	local made: BillboardGui
	if had ~= nil and had.Parent ~= nil then
		made = had
	else
		made = Instance.new("BillboardGui")
		made.Name = "EffectsPalDayHeart"
		made.Size = UDim2.new(h.size, h.pixels, h.size, h.pixels)
		made.StudsOffsetWorldSpace = Vector3.new(0, h.up, 0)
		made.LightInfluence = 0
		made.MaxDistance = h.range * 1.2
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = h.glyph
		label.TextScaled = true
		label.TextColor3 = Presets.palDay.colour
		label.TextStrokeTransparency = 0.4
		label.Parent = made
		made.Parent = Context.folder()
		hearts[pal] = made
	end
	if made.Adornee ~= (head :: Instance) then
		made.Adornee = head
	end
	return made
end

local function dropHeart(pal: Player)
	local gui: BillboardGui? = hearts[pal]
	if gui ~= nil then
		hearts[pal] = nil
		gui:Destroy()
	end
end

local function checkHearts()
	local h = Presets.palDay.heart
	local wanted: { [Player]: BasePart } = {}
	local on = PalDayFx.heartsOn(
		player:GetAttribute(h.due),
		ReplicatedStorage:GetAttribute("LiveFlag_" .. Pals.PAL_DAY_FLAG)
	)
	local focus = Context.focus()
	if on and focus ~= nil then
		local candidates: { Logic.Candidate<Player> } = {}
		local heads: { [Player]: BasePart } = {}
		for _, userId in pals do
			local pal = Players:GetPlayerByUserId(userId)
			local character = if pal ~= nil and pal ~= player then pal.Character else nil
			local head = if character ~= nil then character:FindFirstChild("Head") else nil
			if pal ~= nil and head ~= nil and head:IsA("BasePart") then
				heads[pal] = head :: BasePart
				table.insert(
					candidates,
					{ key = pal, distance = ((head :: BasePart).Position - focus).Magnitude }
				)
			end
		end
		for _, pal in Logic.nearest(candidates, h.range, h.most) do
			wanted[pal] = heads[pal]
		end
	end
	for pal in hearts do
		local keep: BasePart? = wanted[pal]
		if keep == nil then
			dropHeart(pal)
		end
	end
	for pal, head in wanted do
		heartFor(pal, head)
	end
end

function PalDayFx.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			checkHearts()
			task.wait(Presets.palDay.heart.every)
		end
	end)
	Context.whenRemote("PalsChanged", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(setPals)
	end)
	Context.whenRemote("PalDayPaid", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(paid)
	end)
end

return PalDayFx
