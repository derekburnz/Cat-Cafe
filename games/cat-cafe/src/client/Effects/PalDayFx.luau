--!strict
-- #4913 Pal Day: the moment today's Pal Day gift is paid (the server's PalDayPaid, palDay switch), this player's
-- character waves and a puff of pink hearts floats up over its head, and each pal on the server within the hearts'
-- range waves back a beat later with a puff of its own, so playing together today feels like something. The loot card
-- (UIController) lists the gift; this adds the moment in the world. A heart chime plays through PalDayFx.onBeat
-- (Audio). Reduce Motion keeps the hearts and the chime and drops the waves. Numbers in Presets.palDay. Local only:
-- nothing here fires a remote or changes game state.
local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local PalWave = require(script.Parent.PalWave)
local PetCat = require(script.Parent.PetCat)
local Presets = require(script.Parent.Presets)

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

function PalDayFx.start()
	if started then
		return
	end
	started = true
	Context.whenRemote("PalsChanged", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(setPals)
	end)
	Context.whenRemote("PalDayPaid", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(paid)
	end)
end

return PalDayFx
