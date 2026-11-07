--!strict
-- #2214 add-on (Derek2 11-07: "show exclamation mark when someone is doing a rescue also"): while another player is
-- rescuing a stuck cat, the Fish Market's red "!" and bubble (Components/MarketBang.build) hang over that rescue spot,
-- "🆘 Rescue on! Come help" (or "🐾 Team Rescue on!" once a helper has joined, F92), so everyone nearby notices and
-- can come help. It hangs from the spot itself (the server's `RescueSpot` part), not from a sign, so it stays right
-- wherever the area's signs are moved. The rescuer and the helper see none (they have the bar). It bobs and holds
-- still with Reduce Motion, as the Market's does. Each player's copy lives in their own PlayerGui.
--   RescueBang.new(parent)   the billboards, kept up to date by itself; :destroy()

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MarketBang = require(script.Parent.MarketBang)
local RescueBangLogic = require(script.Parent.RescueBangLogic)

export type RescueBang = {
	refresh: (self: RescueBang) -> (),
	destroy: (self: RescueBang) -> (),
}

local RescueBang = {}
RescueBang.__index = RescueBang

RescueBang.TAG = "RescueSpot" -- WorldBuilder's rescue spots
RescueBang.LIFT = 5 -- studs over the spot, clear of the stuck cat
RescueBang.LOOK_SECONDS = 0.5

function RescueBang.new(parent: Instance): RescueBang
	local self = setmetatable({}, RescueBang) :: any
	self._parent = parent
	self._bangs = {} :: { [Instance]: MarketBang.Bang }
	self._connections = {} :: { RBXScriptConnection }
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(RescueBang.TAG):Connect(function(spot: Instance)
			local bang = self._bangs[spot]
			if bang then
				bang.gui:Destroy()
				self._bangs[spot] = nil
			end
		end)
	)
	table.insert(
		self._connections,
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			for _, bang in self._bangs do
				self:_still(bang)
			end
			self:refresh()
		end)
	)
	-- a rescue starting or ending (the spot's LockedBy and HelpedBy) shows within half a second
	self._alive = true
	task.spawn(function()
		while self._alive do
			task.wait(RescueBang.LOOK_SECONDS)
			if self._alive then
				self:refresh()
			end
		end
	end)
	self:refresh()
	return self :: RescueBang
end

function RescueBang._still(_self: any, bang: MarketBang.Bang)
	local bob = bang.bob
	if bob ~= nil then
		bob:Cancel()
		bang.bob = nil
	end
	bang.gui.StudsOffset = Vector3.zero
end

function RescueBang.refresh(self: any)
	local me = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
	for _, spot in CollectionService:GetTagged(RescueBang.TAG) do
		local words = if spot:IsA("BasePart") and spot:IsDescendantOf(Workspace)
			then RescueBangLogic.line(
				spot:GetAttribute("LockedBy"),
				spot:GetAttribute("HelpedBy"),
				me
			)
			else nil
		local bang: MarketBang.Bang? = self._bangs[spot]
		if bang == nil and words ~= nil then
			local made = MarketBang.build(self._parent)
			made.gui.Name = "CatCafeRescueBang"
			made.gui.StudsOffsetWorldSpace = Vector3.new(0, RescueBang.LIFT, 0)
			self._bangs[spot] = made
			bang = made
		end
		if bang ~= nil then
			local gui: any = bang.gui
			local anchor = if words ~= nil then spot else nil
			if gui.Adornee ~= anchor then
				gui.Adornee = anchor
			end
			gui.Enabled = anchor ~= nil
			if words ~= nil and bang.line.Text ~= words then
				bang.line.Text = words
			end
			if anchor == nil then
				self:_still(bang)
			elseif bang.bob == nil and not GuiService.ReducedMotionEnabled then
				local info = TweenInfo.new(
					MarketBang.BOB_SECONDS / 2,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				)
				local bob = TweenService:Create(
					gui,
					info,
					{ StudsOffset = Vector3.new(0, MarketBang.BOB_STUDS, 0) }
				)
				bob:Play()
				bang.bob = bob
			end
		end
	end
end

function RescueBang.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, bang in self._bangs do
		self:_still(bang)
		bang.gui:Destroy()
	end
	table.clear(self._bangs)
end

return RescueBang
