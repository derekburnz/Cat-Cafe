--!strict
-- The outfit passes' thank-you sparkle (#2147, store-pass-looks.md section 7.3; Derek2 2026-11-07: "make the +15%
-- earned more obvious"). Right after Cat Accessories or Uniform Styles is bought, one short bow-pink sparkle pops
-- over each of your working cats in range, a little apart, so the +15% on each cat shows on the cats themselves. The
-- toast is UI-Engineer's. Reduce Motion and Low performance skip the sparkle (the toast stays). It plays once per
-- purchase: only on Moments.OutfitPassBought, which the UI fires from the purchase prompt's result, never on a join.
-- Listening only; numbers in Presets.passThanks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Context = require(script.Parent.Context)
local Moments = require(script.Parent.Parent.Moments)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)

local PassThanks = {}

local started = false

-- Over a cat's head: its Head's BubbleAnchor, else `over` studs over its pivot.
local function overHead(cat: Model, over: number): Vector3
	local head = cat:FindFirstChild("Head", true)
	local anchor = if head ~= nil then head:FindFirstChild("BubbleAnchor") else nil
	if anchor ~= nil and anchor:IsA("Attachment") then
		return (anchor :: Attachment).WorldPosition
	end
	return cat:GetPivot().Position + Vector3.new(0, over, 0)
end

-- Your own working cats within `within` studs, nearest first, at most `most`.
local function myWorkers(within: number, most: number): { Model }
	local player = Players.LocalPlayer
	type Found = { cat: Model, distance: number }
	local found: { Found } = {}
	for _, tagged in CollectionService:GetTagged("WorkingCat") do
		if
			tagged:IsA("Model")
			and tagged.Parent ~= nil
			and player ~= nil
			and tagged:GetAttribute("OwnerUserId") == player.UserId
			and tagged:GetAttribute("HiddenLocal") ~= true
		then
			local cat = tagged :: Model
			local distance = Context.distance(cat:GetPivot().Position)
			if distance <= within then
				table.insert(found, { cat = cat, distance = distance })
			end
		end
	end
	table.sort(found, function(a: Found, b: Found): boolean
		return a.distance < b.distance
	end)
	local out: { Model } = {}
	for i = 1, math.min(#found, most) do
		table.insert(out, found[i].cat)
	end
	return out
end

-- The sparkle over each working cat, `gap` seconds apart, nearest first. Nothing with Reduce Motion or Low
-- performance.
function PassThanks.play()
	if Context.reducedMotion() or Context.lowPerformance then
		return
	end
	local p = Presets.passThanks
	for i, cat in myWorkers(p.within, p.most) do
		task.delay((i - 1) * p.gap, function()
			if cat.Parent == nil then
				return
			end
			local at = overHead(cat, p.over)
			Particles.burst("dingSparkle", at, p.sparkles, p.colours[1])
			Particles.burst("dingSparkle", at, p.sparkles, p.colours[2])
			Particles.ring(at - Vector3.new(0, p.ringBelow, 0), p.colours[1], p.ring, p.ringSeconds)
		end)
	end
end

function PassThanks.start()
	if started then
		return
	end
	started = true
	local bought = (Moments :: any).OutfitPassBought
	if bought ~= nil then
		bought:Connect(function(_pass: unknown)
			PassThanks.play()
		end)
	end
end

return PassThanks
