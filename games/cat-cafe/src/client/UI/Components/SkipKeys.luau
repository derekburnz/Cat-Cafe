--!strict
-- #2246 (Derek2 11-07: "Add the ability to skip spins"): Space, Enter or a controller's A skips what is playing (the
-- Spin Wheel's turn, the crate reel's roll) as a tap on it does. Which keys, and when a key counts, is SpinLogic's
-- (pure, so the specs check it). The prize was paid before the animation began; a skip only shows it sooner.
--   SkipKeys.connect(playing, skip) -> RBXScriptConnection   skip() on a skip key while playing() is true
--
-- Roblox terms: UserInputService.InputBegan fires for every key, click and button; its second argument is true when
-- the game's own UI already used it (a focused text box, a selected button).

local UserInputService = game:GetService("UserInputService")

local SpinLogic = require(script.Parent.SpinLogic)

local SkipKeys = {}

function SkipKeys.connect(playing: () -> boolean, skip: () -> ()): RBXScriptConnection
	return UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		if SpinLogic.skipKey(input.KeyCode.Name, processed, typing) and playing() then
			skip()
		end
	end)
end

return SkipKeys
