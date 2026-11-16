--!strict
-- #4788 (instance streaming): before the server moves a character far, ask Roblox to stream the landing to that
-- player, so the move never lands in empty sky. With Workspace.StreamingEnabled off (today) both do nothing and never
-- yield, so every caller behaves as before. CannonService and IntroController already stream their own trips.
--   StreamAround.on() -> boolean                              whether the place streams (Workspace.StreamingEnabled)
--   StreamAround.wait(player, position, seconds?) -> boolean   yields up to `seconds` (SECONDS) for the area; false
--                                                              when streaming is off (no yield)
--   StreamAround.start(player, position)                      the same request without waiting (a move that comes
--                                                              later, such as a cloud hop's)

local Workspace = game:GetService("Workspace")

local StreamAround = {}

StreamAround.SECONDS = 2 -- as CannonService's STREAM_TIMEOUT

function StreamAround.on(): boolean
	return Workspace.StreamingEnabled
end

function StreamAround.wait(player: Player, position: Vector3, seconds: number?): boolean
	if not Workspace.StreamingEnabled then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(position, seconds or StreamAround.SECONDS)
	end)
	return true
end

function StreamAround.start(player: Player, position: Vector3)
	if Workspace.StreamingEnabled then
		task.spawn(function()
			StreamAround.wait(player, position)
		end)
	end
end

return StreamAround
