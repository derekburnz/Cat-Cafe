--!strict
-- FallCatchService (#2651, tier6-7-areas.md section 5): the Ruins' mist catch. Every CHECK_SECONDS, a character that
-- has fallen into an area's catch (Layout.fallCaught: catchBelow under the floor, within catchMargin of it) drops
-- what it carries back onto the area's floor (CatService.dropForFall) and is put on the camp's landing pad
-- (CannonService.landOnPad): no damage, no death, nothing lost. The server measures; a client can't ask for it, and it
-- only ever moves you to the pad you would fly to anyway. Areas without catchBelow are never checked.
local Players = game:GetService("Players")

local CannonService = require(script.Parent.CannonService)
local CatService = require(script.Parent.CatService)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)

local FallCatchService = {}

local CHECK_SECONDS = 0.5
FallCatchService.TOAST = "The mist carried you back to camp."

-- The ids of every area with a catch, worked out once.
local function catchAreas(): { string }
	local ids: { string } = {}
	for id, spec in Layout.areas do
		if spec.catchBelow ~= nil then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function check(ids: { string })
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		-- a cannon flight is the cannon's to land (Review-Agent on #2665): never pulled out of the air mid-arc
		if root ~= nil and root:IsA("BasePart") and not CatService.inFlight(player) then
			local at = root.Position
			for _, id in ids do
				if Layout.fallCaught(Layout.areas[id], at.X, at.Y, at.Z) then
					CatService.dropForFall(player, id)
					if CannonService.landOnPad(player, id) then
						Net.toast(player, FallCatchService.TOAST, "info")
					end
					break
				end
			end
		end
	end
end

function FallCatchService.start()
	local ids = catchAreas()
	if #ids == 0 then
		return -- no area has a catch
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			check(ids)
		end
	end)
end

return FallCatchService
