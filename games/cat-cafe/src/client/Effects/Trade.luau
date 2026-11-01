--!strict
-- Trade done (F102, trading.md section 3 step 6: "Both see "Trade done!" with the cats flying into their cat room").
-- When this player's trade goes through, the cats they got fly off the confirm screen into the HUD's Cats pill, the
-- way into the cat room: copies of UI-Engineer's "You get" pictures (tagged `TradeGot` as TradeDone arrives; the UI
-- hides its own a frame later) leave one after another in an arc that bends up, shrinking toward the pill, and each
-- lands with a few sparkles and a ring round the pill. With the HUD hidden they fly to the middle of the left edge.
-- With Reduce Motion nothing flies: the pill gets half the sparkles and no ring.
--
-- Source: the server's `TradeDone` to each of the two players, hooked when it appears (it only exists once the server
-- has F102); the pictures by their tag. Numbers in Presets.tradeFly. Listening only; the UI's objects are only read
-- and copied, never changed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Context = require(script.Parent.Context)
local Logic = require(script.Parent.Logic)
local Presets = require(script.Parent.Presets)
local ScreenFx = require(script.Parent.ScreenFx)

local Trade = {}

local GUI_NAME = "EffectsTrade"
local TAG = "TradeGot"
local FRESH = 1.5 -- seconds a tag counts as this trade's

local taggedAt: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local started = false

-- The HUD's Cats pill, where it is and how tall, in `gui`'s pixels; the middle of the left edge with the HUD hidden.
local function catRoom(gui: ScreenGui): (Vector2, number)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui ~= nil then playerGui:FindFirstChild("CatCafeHUD") else nil
	local menu = if hud ~= nil then hud:FindFirstChild("Menu", true) else nil
	local pill = if menu ~= nil then menu:FindFirstChild("Cats") else nil
	if pill ~= nil and pill:IsA("GuiObject") and ScreenFx.shown(pill :: GuiObject) then
		local object = pill :: GuiObject
		return ScreenFx.centre(gui, object), object.AbsoluteSize.Y
	end
	return Vector2.new(70, gui.AbsoluteSize.Y / 2), 48
end

-- This trade's "You get" pictures, tagged within the last moment, left to right and top to bottom.
local function pictures(): { GuiObject }
	local now = os.clock()
	local found: { GuiObject } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		local at = taggedAt[instance]
		if
			instance:IsA("GuiObject")
			and at ~= nil
			and now - at <= FRESH
			and ScreenFx.placed(instance :: GuiObject)
		then
			table.insert(found, instance :: GuiObject)
		end
	end
	table.sort(found, function(a: GuiObject, b: GuiObject): boolean
		if math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) > 4 then
			return a.AbsolutePosition.Y < b.AbsolutePosition.Y
		end
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	return found
end

local function landed(gui: ScreenGui, at: Vector2, height: number)
	local f = Presets.tradeFly
	ScreenFx.sparkle(
		gui,
		table.create(f.arrive, at),
		f.sparkle,
		{ size = 10, seconds = 0.4, reach = height * 0.9, stagger = 0.06 }
	)
	ScreenFx.ring(gui, at, height * 0.8, height * f.ring, f.ringColor, f.ringSeconds)
end

-- One picture's copy flying into the cat room, `wait` seconds after the first.
local function fly(
	gui: ScreenGui,
	picture: GuiObject,
	wait: number,
	target: Vector2,
	height: number
)
	local f = Presets.tradeFly
	local size = picture.AbsoluteSize
	local from = ScreenFx.centre(gui, picture)
	local copy = picture:Clone() :: GuiObject
	CollectionService:RemoveTag(copy, TAG)
	for _, descendant in copy:GetDescendants() do
		CollectionService:RemoveTag(descendant, TAG)
	end
	copy.AnchorPoint = Vector2.new(0.5, 0.5)
	copy.Position = UDim2.fromOffset(from.X, from.Y)
	copy.Size = UDim2.fromOffset(size.X, size.Y)
	copy.Rotation = 0
	copy.Visible = false
	copy.Parent = gui
	local land = height * f.land / math.max(size.Y, 1)
	local lean = if from.X > target.X then -1 else 1
	local bend = Logic.flyBend(from, target, if from.X > target.X then f.lift else -f.lift)
	local began = os.clock() + wait
	local loop: RBXScriptConnection? = nil
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t < 0 then
			return
		end
		if t >= f.seconds or gui.Parent == nil then
			if loop ~= nil then
				loop:Disconnect()
			end
			copy:Destroy()
			if gui.Parent ~= nil then
				landed(gui, target, height)
			end
			return
		end
		local u = Logic.easeInOut(t / f.seconds)
		local at = Logic.curve(from, bend, target, u)
		-- a small bump as it lifts off, then down to the pill's size
		local k = 1 + (land - 1) * u * u + 0.08 * math.sin(math.pi * math.min(t / f.popIn, 1))
		copy.Visible = true
		copy.Position = UDim2.fromOffset(at.X, at.Y)
		copy.Size = UDim2.fromOffset(size.X * k, size.Y * k)
		copy.Rotation = lean * 10 * math.sin(math.pi * u)
	end)
end

local function done()
	local f = Presets.tradeFly
	local gui = ScreenFx.gui(GUI_NAME, f.displayOrder)
	if gui == nil then
		return
	end
	local target, height = catRoom(gui)
	if Context.reducedMotion() then
		ScreenFx.sparkle(
			gui,
			table.create(math.max(1, math.floor(f.arrive / 2)), target),
			f.sparkle,
			{ size = 10, seconds = 0.4, reach = height * 0.6, stagger = 0.06 }
		)
		return
	end
	local got = pictures()
	for _ = 1, 3 do
		if #got > 0 then
			break
		end
		RunService.RenderStepped:Wait() -- pictures made this frame have no size until the next
		got = pictures()
	end
	for i, picture in got do
		fly(gui, picture, (i - 1) * f.stagger, target, height)
	end
	if #got == 0 then
		landed(gui, target, height) -- no pictures to copy: the cat room still lights up
	end
end

function Trade.start()
	if started then
		return
	end
	started = true
	local function stamp(instance: Instance)
		taggedAt[instance] = os.clock()
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(stamp)
	Context.whenRemote("TradeDone", function(remote: RemoteEvent)
		remote.OnClientEvent:Connect(function()
			-- after the UI's own TradeDone handler has tagged its pictures, before it hides them
			task.defer(done)
		end)
	end)
end

return Trade
