--!strict
-- #3936 (Derek 2026-11-13: "show the exclamation marks above the trait portal when they have trait rerolls to use"):
-- the camp stations' red "!" (ReadyBang, the Rummage Bin's) over the Mystic Pool while this player has a roll to use:
-- a free roll left, a Trait Token banked or free tokens waiting at the station (MysticPoolLogic.bangShows). Only this
-- player sees it (the billboard lives in their PlayerGui), within RANGE studs, bobbing unless Reduce Motion is on.
-- It hangs from the model's BangAnchor attachment when it has one, else LIFT studs over the model's top.
--   PoolBang.new()          watches every model tagged Traits.TAG, including ones that stream in later
--   :update(traitsView)     PlayerState.traits (false or nil while the `traits` switch is off)
--   :destroy()

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local MysticPoolLogic = require(script.Parent.MysticPoolLogic)
local Outline = require(script.Parent.Outline)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Traits = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Traits")) :: any

local RANGE = 40 -- studs from the camera, as the camp stations' "!" (CampExtrasLogic.BANG_RANGE)
local LIFT = 2 -- studs over the model's top, for a model with no ANCHOR
local ANCHOR = "BangAnchor"
local BOB_STUDS = 1
local BOB_SECONDS = 2

export type PoolBang = {
	update: (self: PoolBang, view: unknown) -> (),
	destroy: (self: PoolBang) -> (),
}

type Bang = { gui: BillboardGui, bob: Tween? }

local PoolBang = {}
PoolBang.__index = PoolBang

function PoolBang.new(): PoolBang
	local self = setmetatable({}, PoolBang) :: any
	self._on = false
	self._bangs = {} :: { [Instance]: Bang }
	self._connections = {
		CollectionService:GetInstanceAddedSignal(Traits.TAG):Connect(function(model: Instance)
			self:_set(model)
		end),
		CollectionService:GetInstanceRemovedSignal(Traits.TAG):Connect(function(model: Instance)
			self:_drop(model)
		end),
	} :: { RBXScriptConnection }
	return self :: PoolBang
end

local function still(bang: Bang)
	if bang.bob ~= nil then
		bang.bob:Cancel()
		bang.bob = nil
	end
	bang.gui.StudsOffset = Vector3.zero
end

function PoolBang._drop(self: any, model: Instance)
	local bang: Bang? = self._bangs[model]
	if bang ~= nil then
		self._bangs[model] = nil
		still(bang)
		bang.gui:Destroy()
	end
end

function PoolBang._make(self: any, model: Instance): Bang?
	local found: Bang? = self._bangs[model]
	if found ~= nil then
		return found
	end
	if not model:IsA("Model") then
		return nil
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if part == nil or playerGui == nil then
		return nil
	end
	local anchor = model:FindFirstChild(ANCHOR, true)
	local adornee: Instance = part
	local lift = Vector3.zero
	if anchor ~= nil and anchor:IsA("Attachment") then
		adornee = anchor
	else
		local box, size = model:GetBoundingBox()
		lift = Vector3.new(0, box.Position.Y + size.Y / 2 - (part :: BasePart).Position.Y + LIFT, 0)
	end
	local gui: BillboardGui = Create("BillboardGui", {
		Name = "CatCafePoolBang",
		Size = UDim2.new(
			1.6 * Scale.phoneStuds(),
			Scale.billboard(28),
			1.6 * Scale.phoneStuds(),
			Scale.billboard(28)
		),
		StudsOffsetWorldSpace = lift,
		LightInfluence = 0,
		AlwaysOnTop = false,
		MaxDistance = RANGE,
		DistanceLowerLimit = Scale.BUBBLE_NEAR,
		ResetOnSpawn = false,
		Enabled = false,
		Adornee = adornee,
		Parent = playerGui,
	})
	local dot: Frame = Create("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.colors.red,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Outline.border(dot, 2)
	local mark: TextLabel = Create("TextLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.8),
		Position = UDim2.fromScale(0, 0.1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "!",
		ZIndex = 2,
		Parent = dot,
	})
	Outline.text(mark, 2)
	local bang: Bang = { gui = gui, bob = nil }
	self._bangs[model] = bang
	return bang
end

function PoolBang._set(self: any, model: Instance)
	local on = self._on == true
	local bang: Bang? = if on then self:_make(model) else self._bangs[model]
	if bang == nil then
		return
	end
	bang.gui.Enabled = on
	if not on or GuiService.ReducedMotionEnabled then
		still(bang)
	elseif bang.bob == nil then
		local info = TweenInfo.new(
			BOB_SECONDS / 2,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		local bob =
			TweenService:Create(bang.gui, info, { StudsOffset = Vector3.new(0, BOB_STUDS, 0) })
		bob:Play()
		bang.bob = bob
	end
end

function PoolBang.update(self: any, view: unknown)
	local on = MysticPoolLogic.bangShows(if type(view) == "table" then view :: any else nil)
	if on == self._on then
		return
	end
	self._on = on
	for _, model in CollectionService:GetTagged(Traits.TAG) do
		self:_set(model)
	end
end

function PoolBang.destroy(self: any)
	for _, connection: RBXScriptConnection in self._connections do
		connection:Disconnect()
	end
	for model in self._bangs do
		self:_drop(model)
	end
end

return PoolBang
