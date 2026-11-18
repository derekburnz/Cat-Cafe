--!strict
-- #5171 (Derek 2026-11-17 23:55 UTC: "add a good cat (maybe a secret) low rates to the spin wheel"): behind the
-- `spinCat` switch (LiveFlags, off by default) the Spin Wheel gets a ninth slice that gives a Secret cat, weight 0.5
-- of 200 (0.25%), taken from slice 1's small coins so every other prize keeps its chance. Spin luck does not lift it.
-- The cat is Lucky Clover, or Cafe Ghost while the `secretAreas` switch is off, so the wheel never gives a cat that
-- cannot be found yet. Both sides follow the two switches' ReplicatedStorage attributes and set the slice on Spin
-- (Spin.setCat), so the server's pick and the window's wheel and Odds list agree.
--
-- Money rules (monetization-policy): spins are free only. If spins are ever sold for Robux this slice must come off
-- first, since a paid spin that can give a cat is a paid random item (SpinCat.spec checks no product gives spins).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(script.Parent.LiveFlags)
local Spin = require(script.Parent.Spin)
local Types = require(script.Parent.Types)

local SpinCat = {}

SpinCat.FLAG = "spinCat"
SpinCat.SECRETS_FLAG = "secretAreas"
SpinCat.SLICE = 9
SpinCat.WEIGHT = 0.5 -- of 200: 0.25%
SpinCat.CAT = "lucky_clover"
SpinCat.FALLBACK = "cafe_ghost" -- while secretAreas is off

-- The cat the slice gives: Lucky Clover with the one-per-area Secrets on, else Cafe Ghost.
function SpinCat.catFor(secretsOn: boolean): string
	return if secretsOn then SpinCat.CAT else SpinCat.FALLBACK
end

-- The slice itself: a jackpot (the big win effect and a toast), one cat.
function SpinCat.row(catId: string): Types.SpinSlice
	local row: Types.SpinSlice = {
		slice = SpinCat.SLICE,
		kind = "cat",
		catId = catId,
		count = 1,
		weight = SpinCat.WEIGHT,
		jackpot = true,
	}
	table.freeze(row :: any)
	return row
end

local function shown(key: string): boolean
	return LiveFlags.shown(key, ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key))
end

-- Whether the switch reads on now.
function SpinCat.on(): boolean
	return shown(SpinCat.FLAG)
end

-- The slice for these switch readings, or nil with spinCat off.
function SpinCat.rowFor(on: boolean, secretsOn: boolean): Types.SpinSlice?
	if not on then
		return nil
	end
	return SpinCat.row(SpinCat.catFor(secretsOn))
end

local following = false
local lastKey: string? = nil

local function apply()
	local row = SpinCat.rowFor(SpinCat.on(), shown(SpinCat.SECRETS_FLAG))
	local key = if row ~= nil then row.catId or "" else nil
	if key == lastKey and following then
		return
	end
	lastKey = key
	Spin.setCat(row)
end

-- Sets the slice now and each time either switch flips. Safe to call more than once.
function SpinCat.follow()
	apply()
	if following then
		return
	end
	following = true
	for _, key in { SpinCat.FLAG, SpinCat.SECRETS_FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. key)
			:Connect(apply)
	end
end

return SpinCat
