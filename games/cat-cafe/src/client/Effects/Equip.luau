--!strict
-- Decor you just put out (Derek 2026-10-28 01:25: "noticable when equipped maybe highlight outline green briefly
-- when equipping"): when you place a rug, a piece of furniture or a decoration in your cafe, a green outline and a
-- faint green fill flash round it and fade, so you see what changed even when it sits under a table; a new floor
-- flashes the cafe floor the same way. Wallpaper and paint already repaint whole walls, so they flash nothing. Only
-- this player sees it, on their own cafe. Numbers in Presets.equipFlash.
--
-- Source: `decorPlaced` in this player's ProfileSync, compared with the last one (Logic.newlyPlaced); the first one
-- seen only sets the baseline, so joining plays nothing. The piece is the model carrying that `DecorId` in the
-- `Decor` folder of the Plot whose `OwnerUserId` is this player, waited for a moment since it can arrive just after
-- the sync. Listening only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Net = require(script.Parent.Parent.Net)
local Presets = require(script.Parent.Presets)

local Equip = {}

local last: unknown = nil -- `decorPlaced` at the last ProfileSync that had one
local flashing = 0
local started = false

local function ownPlot(): Model?
	for _, instance in CollectionService:GetTagged("Plot") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and instance:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
		then
			return instance :: Model
		end
	end
	return nil
end

-- What flashes for the piece: its placed model, or the floor parts for a floor; nil until it has streamed in.
local function targetsOf(decorId: string, target: string): { Instance }?
	local plot = ownPlot()
	if plot == nil then
		return nil
	end
	if target == "floor" then
		local parts: { Instance } = {}
		for _, part in CollectionService:GetTagged("Floor") do
			if part:IsA("BasePart") and part:IsDescendantOf(plot) then
				table.insert(parts, part)
			end
		end
		return if #parts > 0 then parts else nil
	end
	local decor = plot:FindFirstChild("Decor")
	if decor == nil then
		return nil
	end
	for _, child in decor:GetChildren() do
		if
			child:IsA("Model")
			and child:GetAttribute("DecorId") == decorId
			and child:FindFirstChildWhichIsA("BasePart", true) ~= nil
		then
			return { child :: Instance }
		end
	end
	return nil
end

-- A piece's outline draws over anything in front of it, so a rug under a table still shows; the floor's stays
-- behind the furniture on it.
local function flash(adornee: Instance, overAll: boolean)
	local e = Presets.equipFlash
	local at = Context.positionOf(adornee)
	if flashing >= e.most or at == nil or Context.distance(at) > e.maxDistance then
		return
	end
	flashing += 1
	local highlight = Instance.new("Highlight")
	highlight.Name = "EquipFlash"
	highlight.Adornee = adornee
	highlight.DepthMode = if overAll
		then Enum.HighlightDepthMode.AlwaysOnTop
		else Enum.HighlightDepthMode.Occluded
	highlight.OutlineColor = e.colour
	highlight.FillColor = e.colour
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 1
	highlight.Parent = Context.folder()
	TweenService:Create(
		highlight,
		TweenInfo.new(e.fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ OutlineTransparency = 0, FillTransparency = e.fill }
	):Play()
	-- Ends the flash once, whether the fade finishes or the Highlight goes first (a fade on a destroyed one never
	-- completes), so the count of flashes never sticks.
	local done = false
	local function finish()
		if not done then
			done = true
			highlight:Destroy()
			flashing -= 1
		end
	end
	task.delay(e.fadeIn + e.hold, function()
		local out = TweenService:Create(
			highlight,
			TweenInfo.new(e.fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ OutlineTransparency = 1, FillTransparency = 1 }
		)
		out.Completed:Connect(finish)
		out:Play()
	end)
	task.delay(e.fadeIn + e.hold + e.fade + 0.5, finish)
end

local function equipped(decorId: string)
	local def = Catalog.getDecor(decorId)
	local target = Logic.equipTarget(if def ~= nil then def.kind else nil)
	if target == nil then
		return
	end
	task.spawn(function()
		local giveUp = os.clock() + Presets.equipFlash.wait
		while true do
			local targets = targetsOf(decorId, target)
			if targets ~= nil then
				for _, adornee in targets do
					flash(adornee, target == "piece")
				end
				return
			end
			if os.clock() >= giveUp then
				return
			end
			task.wait(0.1)
		end
	end)
end

function Equip.start()
	if started then
		return
	end
	started = true
	Net.on("ProfileSync", function(state: unknown)
		if type(state) ~= "table" then
			return
		end
		local placed = (state :: { [string]: unknown }).decorPlaced
		if type(placed) ~= "table" then
			return
		end
		-- a copy, so a later merge into the same table cannot hide what changed
		local now = table.clone(placed :: { [unknown]: unknown })
		local ids = Logic.newlyPlaced(last, now)
		last = now
		for _, decorId in ids do
			equipped(decorId)
		end
	end)
end

return Equip
