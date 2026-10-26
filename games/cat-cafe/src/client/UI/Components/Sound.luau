--!strict
-- The UI's one sound hook. UI.init takes `config.playSound` (the controller passes Audio.play), so the UI keeps
-- no asset ids and never requires Audio itself. Cue ids are the sound list's (docs/audio/cat-cafe/sound-list.md
-- section 5.8). Until a player function is set every call is silent, and a failing player only warns once.

local Sound = {}

export type Player = (cueId: string) -> ...any

local player: Player? = nil
local warned = false

function Sound.set(fn: Player?)
	player = fn
	warned = false
end

function Sound.play(cueId: string)
	local fn = player
	if not fn then
		return
	end
	local ok, err = pcall(fn, cueId)
	if not ok and not warned then
		warned = true
		warn(("[CatCafeUI] playSound(%q) failed: %s"):format(cueId, tostring(err)))
	end
end

return Sound
