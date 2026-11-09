--!strict
-- #2721: Roblox's live touch jump button (PlayerGui.TouchGui.TouchControlFrame.JumpButton), so the Net and Tackle
-- buttons follow it on every phone and tablet, in screen pixels. Falls back to
-- NetButtonPlace.jump's formula when it is not there (no touch controls yet, a custom control script).
--   read(viewport) -> (Vector2, number)   its top left corner and size, in screen pixels

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local NetButtonPlace = require(script.Parent.NetButtonPlace)

local JumpButton = {}

function JumpButton.read(viewport: Vector2): (Vector2, number)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local button = frame and frame:FindFirstChild("JumpButton")
	if
		touchGui
		and touchGui:IsA("ScreenGui")
		and button
		and button:IsA("GuiObject")
		and button.Visible
	then
		local size = button.AbsoluteSize
		-- AbsolutePosition is measured below the top bar's inset even in a ScreenGui that ignores it
		local at = button.AbsolutePosition + GuiService:GetGuiInset()
		local fits = size.X >= 30
			and at.X >= 0
			and at.Y >= 0
			and at.X + size.X <= viewport.X + 1
			and at.Y + size.Y <= viewport.Y + 1
		if fits then
			return Vector2.new(math.floor(at.X + 0.5), math.floor(at.Y + 0.5)),
				math.floor(size.X + 0.5)
		end
	end
	return NetButtonPlace.jump(viewport)
end

return JumpButton
