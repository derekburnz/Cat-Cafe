--!strict
-- Hides the server's LockLabel text ("Barista: opens at Tier 5") over every cafe's role slots, on this client.
-- Derek, 2026-10-27: "remove the place holder texts its ugly". The role slots now live in the Staff tab of
-- Upgrades (Components/StaffSlots), so the world shows no slot labels at all. The engineer is removing LockLabel
-- from CafeService; once that lands this screen can go.
--
-- Roblox terms: plots are the server's models tagged "Plot"; a BillboardGui's children can replicate after it.

local CollectionService = game:GetService("CollectionService")

export type SlotLabels = {
	destroy: (self: SlotLabels) -> (),
}

local TAG = "Plot"
local SERVER_LABEL = "LockLabel"

local SlotLabels = {}
SlotLabels.__index = SlotLabels

function SlotLabels.new(): SlotLabels
	local self = setmetatable({}, SlotLabels) :: any
	self._plots = {} :: { [Instance]: RBXScriptConnection }
	self._hidden = setmetatable({} :: { [TextLabel]: boolean }, { __mode = "k" }) -- weak: labels can go
	self._connections = {} :: { RBXScriptConnection }

	for _, plot in CollectionService:GetTagged(TAG) do
		self:_attach(plot)
	end
	table.insert(
		self._connections,
		CollectionService:GetInstanceAddedSignal(TAG):Connect(function(plot: Instance)
			self:_attach(plot)
		end)
	)
	table.insert(
		self._connections,
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(plot: Instance)
			local connection = self._plots[plot]
			if connection then
				connection:Disconnect()
				self._plots[plot] = nil
			end
		end)
	)
	return self :: SlotLabels
end

function SlotLabels._hideServerText(self: any, instance: Instance)
	local parent = instance.Parent
	if
		instance:IsA("TextLabel")
		and parent ~= nil
		and parent.Name == SERVER_LABEL
		and parent:IsA("BillboardGui")
	then
		local text = instance :: TextLabel
		text.Visible = false
		self._hidden[text] = true
	end
end

function SlotLabels._attach(self: any, plot: Instance)
	if self._plots[plot] then
		return
	end
	for _, descendant in plot:GetDescendants() do
		self:_hideServerText(descendant)
	end
	self._plots[plot] = plot.DescendantAdded:Connect(function(descendant: Instance)
		self:_hideServerText(descendant)
	end)
end

function SlotLabels.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, connection in self._plots do
		connection:Disconnect()
	end
	table.clear(self._plots)
	for text in self._hidden do
		if text.Parent then
			text.Visible = true
		end
	end
	table.clear(self._hidden)
end

return SlotLabels
