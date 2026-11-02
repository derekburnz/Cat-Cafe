--!strict
-- Golden fish landing in your wallet (golden-fish.md section 4: "the golden fish pickup sparkle is the catch sparkle
-- in gold"): whenever this player's golden fish go up, gold sparkles burst round them and gold glints float up, with
-- a small gold ring at their feet; a bigger gain gets more sparkles and a wider ring (Presets.fishPickup). It reads
-- the count in ProfileSync, so every way of earning fish shows it (a first catch, a rank up, an Index milestone, the
-- wheel, the Tip Jar, a duplicate crate piece, a Fish Pond later) without each one firing anything. Spending never
-- sparkles. Only this player sees it. Listening only.

local Players = game:GetService("Players")

local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local Fish = {}

local last: number? = nil -- the count at the last ProfileSync that had one
local started = false

local function sparkle(gain: number)
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local body = root :: BasePart
	local p = Presets.fishPickup
	local sparkles, ring = Logic.fishPickup(gain)
	if sparkles <= 0 then
		return
	end
	local gold = Presets.palette.golden
	local at = body.Position + Vector3.new(0, p.chest, 0)
	Particles.burst("catchSparkle", at, sparkles, gold)
	Particles.burst("fishRise", at, math.ceil(sparkles * p.rise))
	local humanoid = (character :: Model):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid ~= nil then humanoid.HipHeight else 2
	Particles.ring(
		body.Position - Vector3.new(0, body.Size.Y / 2 + hip - 0.1, 0),
		gold,
		ring,
		p.ringSeconds
	)
end

function Fish.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local count = (state :: { [string]: unknown }).goldenFish
		local gain = Logic.fishGain(last, count)
		if type(count) == "number" then
			last = count
		end
		if gain > 0 then
			sparkle(gain)
		end
	end)
end

return Fish
