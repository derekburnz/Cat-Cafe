--!strict
-- The Codes Cat on this client (F65, data-model section 11d, v0.10). Walking into the CodesCircle in front of a
-- station tagged CodesCat opens the code box and walking out closes it, with no key press or prompt: the flat
-- distance from this character to the circle's centre opens it at CodesCircleRadius and closes it past one stud
-- more (shared/Codes.circleOpen). Redeem in the box goes to the server as RedeemCode(text), and CodeResult(ok,
-- message, prize) comes back to the box. The server checks range, the code and the lock again.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Codes = require(Shared:WaitForChild("Codes"))
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)

local CodesController = {}

local player = Players.LocalPlayer
local POLL_SECONDS = 0.1

-- The code box comes with the UI's Codes window. Until that is on main the UI module may not have it, so it is
-- reached loosely and skipped when missing.
local function codesUI(): any
	return (UI :: any).codes
end

-- Each station's circle, found once (review N177); a circle that streams out is looked up again.
local circles: { [Instance]: Instance } = setmetatable({}, { __mode = "k" }) :: any

-- The centre of a station's circle: the CodesCircle part, or the pivot of a CodesCircle Model.
local function circleCentre(station: Instance): Vector3?
	local circle: Instance? = circles[station]
	if circle == nil or not circle:IsDescendantOf(station) then
		circle = station:FindFirstChild(Codes.CIRCLE, true)
		if circle ~= nil then
			circles[station] = circle
		end
	end
	if circle ~= nil and circle:IsA("BasePart") then
		return (circle :: BasePart).Position
	elseif circle ~= nil and circle:IsA("Model") then
		return (circle :: Model):GetPivot().Position
	end
	return nil
end

-- The flat distance from this character to the nearest circle in the Workspace (the station templates in
-- ReplicatedStorage.Assets carry the tag too), or nil without a character or a circle.
local function nearestCircle(): number?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local position = (root :: BasePart).Position
	local best: number? = nil
	for _, station in CollectionService:GetTagged(Codes.TAG) do
		local centre = if station:IsDescendantOf(Workspace) then circleCentre(station) else nil
		if centre ~= nil then
			local distance = Vector2.new(position.X - centre.X, position.Z - centre.Z).Magnitude
			if best == nil or distance < best then
				best = distance
			end
		end
	end
	return best
end

function CodesController.start()
	local uiEvents: any = UI.events
	if uiEvents.redeemCode ~= nil then
		uiEvents.redeemCode:Connect(function(text: string)
			Net.fire("RedeemCode", text)
		end)
	end
	Net.on("CodeResult", function(ok: boolean, message: string, prize: Types.IndexPrize?)
		local box = codesUI()
		if box ~= nil then
			box.result(ok, message, prize)
		end
	end)
	task.spawn(function()
		local open = false
		while true do
			local distance = nearestCircle()
			local want = distance ~= nil and Codes.circleOpen(open, distance)
			local box = codesUI()
			if want ~= open and box ~= nil then
				open = want
				if open then
					box.open()
				else
					box.close()
				end
			end
			task.wait(POLL_SECONDS)
		end
	end)
end

return CodesController
