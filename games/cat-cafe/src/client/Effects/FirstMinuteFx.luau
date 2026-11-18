--!strict
-- The first minute's two payoffs (Growth-Agent's first-minute timeline, Design-Agent's edits on Nov 16; first 5
-- minutes priority):
--   * The first bowl cat's bait card (the walk-through still running, ProfileSync tutorialStep below
--     QuietStart.TUTORIAL_DONE, and the account's first food: stats luresUsed 1 or less and no bait cat tamed yet;
--     not the Let go button, which #4863 hides on every card): as the card pops in, gold sparkles burst off its Tame
--     button with two rings, and Moments.FirstBowlCard(rarity) has Audio play that rarity's jingle. No new card.
--   * The account's first net catch (Moments.CatchSuccess while ProfileSync stats catsCaught is 2 or less: the bowl
--     cat counts there too, and the sync may land before or after the catch; tutorialStep is no use, since bowl first
--     jumps to step 5 before its Alleyway catches): a confetti cheer round the player and Moments.FirstCatchCheer
--     for Audio's cheer.
-- Each once a session. Screen parts through ScreenFx (it only reads the UI); Reduce Motion: no confetti or rings,
-- the sounds still play. Listening only: no remotes, no game state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local FirstCatchWow = require(script.Parent.FirstCatchWow)
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local Particles = require(script.Parent.Particles)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)
local WowBaitGlow = require(script.Parent.WowBaitGlow)

local QuietStart = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("QuietStart"))

local FirstMinuteFx = {}

local started = false
local cardDone = false
local catchDone = false
local tutorialStep: number? = nil
local luresUsed: number? = nil
local baitsTamed: number? = nil
local catsCaught: number? = nil

-- At most this many cats on the save when the cheer plays: the bowl cat and the catch itself.
FirstMinuteFx.CHEER_MOST = 2

-- Whether a catch now gets the cheer: a brand new save (`caught` from its stats), and not yet cheered this session.
function FirstMinuteFx.cheers(caught: number?, already: boolean): boolean
	return not already and caught ~= nil and caught <= FirstMinuteFx.CHEER_MOST
end

-- Whether a bait card now is the account's first: one food in so far and no bait cat tamed yet, and not yet
-- sparkled. Nil counts (the save not heard yet) never sparkle.
function FirstMinuteFx.firstCard(
	step: number?,
	lures: number?,
	tamed: number?,
	already: boolean
): boolean
	return not already
		and step ~= nil
		and step < QuietStart.TUTORIAL_DONE
		and lures ~= nil
		and lures <= 1
		and (tamed == nil or tamed == 0)
end

local function button(gui: Instance, name: string): GuiObject?
	local found = gui:FindFirstChild(name, true)
	return if found ~= nil and found:IsA("GuiObject") then found :: GuiObject else nil
end

local function cardShown(gui: ScreenGui)
	if cardDone or not gui.Enabled then
		return
	end
	local p = Presets.firstMinute.card
	task.delay(p.wait, function() -- the card pops in first
		if cardDone or not gui.Enabled then
			return
		end
		local tame = button(gui, "Tame")
		if
			tame == nil
			or not ScreenFx.shown(tame :: GuiObject)
			or not FirstMinuteFx.firstCard(tutorialStep, luresUsed, baitsTamed, cardDone)
		then
			return
		end
		cardDone = true
		Moments.FirstBowlCard:Fire(WowBaitGlow.rarity())
		if Context.reducedMotion() then
			return
		end
		local fx = ScreenFx.gui("EffectsFirstMinute", p.displayOrder)
		if fx == nil then
			return
		end
		local object = tame :: GuiObject
		local centre = ScreenFx.centre(fx, object)
		local half = object.AbsoluteSize / 2
		local spots = {}
		for i = 1, p.sparks do
			local side = if i % 2 == 0 then 1 else -1
			local along = ((i - 1) / math.max(p.sparks - 1, 1)) * 2 - 1
			table.insert(spots, centre + Vector2.new(along * half.X, side * half.Y))
		end
		ScreenFx.sparkle(fx, spots, p.colour, p.sparkle)
		for i = 1, p.rings do
			task.delay((i - 1) * p.ringEvery, function()
				ScreenFx.ring(fx, centre, half.X, half.X * p.ringGrow, p.colour, p.ringSeconds)
			end)
		end
	end)
end

local function watchCard(playerGui: Instance)
	local function hook(child: Instance)
		if child.Name == "CatCafeBaitCard" and child:IsA("ScreenGui") then
			local gui = child :: ScreenGui
			gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				cardShown(gui)
			end)
			cardShown(gui)
		end
	end
	for _, child in playerGui:GetChildren() do
		hook(child)
	end
	playerGui.ChildAdded:Connect(hook)
end

local function caught(strayId: string?, rarity: string?)
	if not FirstMinuteFx.cheers(catsCaught, catchDone) then
		return
	end
	catchDone = true
	Moments.FirstCatchCheer:Fire()
	-- #5285 E2: with the firstCatchWow switch on, the wow moment (slow motion, push, big pop, coins, banner) in
	-- place of the confetti cheer; the cheer's sound above is its one sting
	if FirstCatchWow.on() and FirstCatchWow.play(strayId, rarity) then
		return
	end
	if Context.reducedMotion() then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local p = Presets.firstMinute.cheer
	local at = (root :: BasePart).Position
	local right = (root :: BasePart).CFrame.RightVector
	local count = math.ceil(Context.budget.confetti * p.confetti)
	for _, side in { -1, 1 } do
		Particles.confetti(at + right * (side * p.side) + Vector3.new(0, p.up, 0), count)
	end
	Particles.burst("gateSparkle", at + Vector3.new(0, p.up, 0), p.sparkle)
end

function FirstMinuteFx.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) == "table" then
			local step = (state :: { [string]: unknown }).tutorialStep
			if type(step) == "number" then
				tutorialStep = step
			end
			local stats = (state :: { [string]: unknown }).stats
			if type(stats) == "table" then
				local s = stats :: { [string]: unknown }
				if type(s.luresUsed) == "number" then
					luresUsed = s.luresUsed :: number
				end
				if type(s.baitsTamed) == "number" then
					baitsTamed = s.baitsTamed :: number
				end
				if type(s.catsCaught) == "number" then
					catsCaught = s.catsCaught :: number
				end
			end
		end
	end)
	Moments.CatchSuccess:Connect(caught)
	task.spawn(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 30)
		if playerGui ~= nil then
			watchCard(playerGui)
		end
	end)
end

return FirstMinuteFx
