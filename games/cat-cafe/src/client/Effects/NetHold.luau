--!strict
-- The net in each player's hand (Derek 2026-10-28: "have your character holding a net while walking around until
-- catching a cat"; F93, catch-rework.md section 1: at all times, put away while a cat is in the arms): alive, with no
-- cat in its arms (`CarryingCatId`, or the server's `NetHidden`), not in a cannon flight (`Launching`) and, for a
-- staged character, not flagged `IntroNoNet` (the intro's copy of you, #1252), a character this client sees holds its
-- player's net, CatCafe_Item_Net_L1 to L4 from ReplicatedStorage.Assets by the server's `NetLevel` on the character or
-- its player (Avatar.netModel; a level whose model is missing shows the next one down), a copy made on this client and
-- pivoted by its `Grip` attachment into the hand before each frame draws.
-- Tackle.luau asks `NetHold.weight` every frame for each character it poses and raises the arm by that much
-- (Avatar.holdNet), with `NetHold.arm`'s smack over it; the net shows once the arm is past Presets.netHold.showAt,
-- and fades as the hand does (the player's own in first person). The smack (Avatar.smack) starts on the swinger's
-- own screen at the press (Moments.NetSmackPress) and elsewhere when the server's NetSwung arrives
-- (Moments.NetSwung), which also says whether it hit; a miss bounces the net back up from where the arm is when this
-- client hears it. A server that never sets `NetLevel` shows the Basic net. Nothing
-- here replicates or fires a remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Avatar = require(script.Parent.Avatar)
local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Presets = require(script.Parent.Presets)

local NetHold = {}

type Held = {
	rig: Avatar.Rig,
	weight: number,
	model: Model?, -- the net in the hand, while it shows
	level: number, -- the model it is (1 to 4)
	offset: CFrame, -- the model's pivot from its Grip
	parts: { BasePart }, -- the net's parts, to fade with the hand
	smackAt: number?, -- server time the last smack began
	missedAt: number?, -- seconds into that smack this client heard it hit nothing
}

local NO_NET = "IntroNoNet" -- true on a staged character (no player) that shows no net and keeps its arm down
local held: { [Model]: Held } = {}
local started = false
-- Server time of this player's last swing press, until the server's NetSwung for it comes back (Review S91).
local pressAt: number? = nil

local function alive(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function drop(entry: Held)
	if entry.model ~= nil then
		entry.model:Destroy()
		entry.model = nil
	end
end

-- A copy of the level's net (or, when the assets lack it, of the next one down) that never collides or blocks a
-- click, its pivot from the Grip (the pivot itself on a net made before the Grip was added) and its parts. nil when
-- the assets have no net at all.
local function make(level: number): (Model?, CFrame, { BasePart })
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template: Instance? = nil
	for n = level, 1, -1 do
		local found = if assets ~= nil
			then assets:FindFirstChild("CatCafe_Item_Net_L" .. n)
			else nil
		if found ~= nil and found:IsA("Model") then
			template = found
			break
		end
	end
	if template == nil then
		return nil, CFrame.identity, {}
	end
	local model = (template :: Model):Clone() :: Model
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			table.insert(parts, part)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local grip = model:FindFirstChild("Grip", true)
	local offset = if grip ~= nil and grip:IsA("Attachment")
		then (grip :: Attachment).WorldCFrame:Inverse() * model:GetPivot()
		else CFrame.identity
	model.Parent = Context.folder()
	return model, offset, parts
end

local function entryOf(character: Model, rig: Avatar.Rig): Held
	local entry: Held = held[character]
		or {
			rig = rig,
			weight = 0,
			model = nil,
			level = 0,
			offset = CFrame.identity,
			parts = {},
			smackAt = nil,
			missedAt = nil,
		}
	held[character] = entry
	entry.rig = rig
	return entry
end

-- How far `character`'s arm is raised for its net this frame, 0 to 1, `dt` seconds after the last call; `near` is
-- false beyond the animation radius, where the arm lowers and the net goes. Also makes or drops the net to match.
function NetHold.weight(character: Model, rig: Avatar.Rig, dt: number, near: boolean): number
	local entry = entryOf(character, rig)
	local player = Players:GetPlayerFromCharacter(character)
	local holding = Avatar.holdsNet(
		character:GetAttribute("CarryingCatId"),
		character:GetAttribute("NetHidden"),
		alive(character),
		character:GetAttribute("Launching"),
		-- a staged copy's own flag (the intro's copy of you shows no net, #1252); a player's character ignores it
		if player == nil then character:GetAttribute(NO_NET) else nil
	)
	-- the server's NetLevel on the character, or on its player
	local netLevel = character:GetAttribute("NetLevel")
	if netLevel == nil and player ~= nil then
		netLevel = player:GetAttribute("NetLevel")
	end
	local level = Avatar.netModel(netLevel)
	if entry.model ~= nil and entry.level ~= level then
		drop(entry) -- an upgrade bought while holding: the new net comes next
	end
	entry.weight = Avatar.holdWeight(entry.weight, holding and near, dt)
	if entry.weight >= Presets.netHold.showAt then
		if entry.model == nil then
			local model, offset, parts = make(level)
			entry.model, entry.offset, entry.parts, entry.level = model, offset, parts, level
			if model == nil then
				entry.weight = 0 -- no net to hold, so the arm stays down
			end
		end
	else
		drop(entry)
	end
	return entry.weight
end

-- The smack's arm on `character` at server time `now` (Avatar.smack), nil when it is not swinging.
function NetHold.arm(character: Model, now: number): Avatar.NetArm?
	local entry = held[character]
	local at = if entry ~= nil then entry.smackAt else nil
	if entry == nil or at == nil then
		return nil
	end
	local arm = Avatar.smack(now - at, entry.missedAt)
	if arm == nil then
		entry.smackAt = nil
	end
	return arm
end

-- A smack starting now on `character`, unless one is still playing (the swinger's own, started at its press, when the
-- server's NetSwung comes back for it).
local function smack(character: Model, now: number)
	local entry = held[character]
	if entry == nil or entry.weight <= 0 then
		return
	end
	local at = entry.smackAt
	if at ~= nil and Avatar.smack(now - at, entry.missedAt) ~= nil then
		return
	end
	entry.smackAt, entry.missedAt = now, nil
end

-- The net in `character`'s hand while it shows, nil while it is away; NetTrail.luau (VFX-Agent, F93) draws the
-- swing's whoosh off it.
function NetHold.net(character: Model): Model?
	local entry = held[character]
	return if entry ~= nil then entry.model else nil
end

-- Lets go of a character that left or was rebuilt.
function NetHold.forget(character: Model)
	local entry = held[character]
	if entry ~= nil then
		drop(entry)
		held[character] = nil
	end
end

-- Each frame before it draws, every shown net goes into its hand, where the frame's joints have put it.
local function place()
	for character, entry in held do
		local model = entry.model
		if model == nil then
			continue
		end
		if not character:IsDescendantOf(game) then
			NetHold.forget(character)
			continue
		end
		local hand, grip = Avatar.netHand(entry.rig)
		if hand ~= nil then
			model:PivotTo(hand.CFrame * grip * entry.offset)
			local fade = hand.LocalTransparencyModifier
			for _, part in entry.parts do
				part.LocalTransparencyModifier = fade
			end
		end
	end
end

function NetHold.start()
	if started then
		return
	end
	started = true
	RunService.PreRender:Connect(place)
	-- The engineer's swing moments, once Moments has them (F93); until then nobody smacks.
	local moments = Moments :: any
	if moments.NetSmackPress ~= nil then
		moments.NetSmackPress:Connect(function()
			local me = Players.LocalPlayer.Character
			if me ~= nil then
				local now = Workspace:GetServerTimeNow()
				pressAt = now
				smack(me, now)
			end
		end)
	end
	if moments.NetSwung ~= nil then
		moments.NetSwung:Connect(function(userId: unknown, hit: unknown)
			local player = if type(userId) == "number"
				then Players:GetPlayerByUserId(userId)
				else nil
			local character = if player ~= nil then player.Character else nil
			if character == nil then
				return
			end
			local now = Workspace:GetServerTimeNow()
			local entry = held[character]
			local pressed = pressAt
			if
				player == Players.LocalPlayer
				and pressed ~= nil
				and now - pressed < Presets.netSmack.answerWithin
			then
				-- this player's own swing coming back, a round trip and NetSmackDelay after the press: it already
				-- smacked at the press, so it only learns whether it missed, and only while that smack still plays
				pressAt = nil
				local at = if entry ~= nil then entry.smackAt else nil
				if
					entry ~= nil
					and at ~= nil
					and at == pressed
					and hit == false
					and entry.missedAt == nil
				then
					entry.missedAt = now - at
				end
				return
			end
			smack(character, now)
			local at = if entry ~= nil then entry.smackAt else nil
			if entry ~= nil and at ~= nil and hit == false and entry.missedAt == nil then
				entry.missedAt = now - at
			end
		end)
	end
end

return NetHold
