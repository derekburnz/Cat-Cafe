--!strict
-- The code box's text rules (F65, data-model section 11d), the way the server reads a code: letters, digits and the
-- symbols in shared Codes.SYMBOLS ("!?#$&*@_-.", Derek's Set 4 answer 2026-11-01: "Make it so codes can work with
-- symbols like !"), big or small, 1 to CodeMaxLength (20). The box drops anything else as it is typed (spaces too,
-- so "play test!" becomes "playtest!"), through shared Codes.clean, so it can never keep or drop a character the
-- server would read differently, and Redeem lights once anything is left. The server trims and lowercases again;
-- this only saves a wasted try against the wrong-code lock. Pure: no Theme, so the cloud spec runner can load it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Codes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local CodeEntry = {}

CodeEntry.MAX_LENGTH = (Config.CodeMaxLength or 20) :: number
CodeEntry.ANSWER_SECONDS = 5 -- Redeem lights again when no CodeResult has come back in this long
-- the server takes one RedeemCode per 2 s and drops the rest without an answer (Net.luau), so Redeem stays grey
-- this long after each send (review N183)
CodeEntry.RESEND_SECONDS = 2

-- The text with everything a code cannot hold taken out, cut to MAX_LENGTH (the server's own Codes.clean).
function CodeEntry.clean(text: string): string
	return Codes.clean(text)
end

-- Whether Redeem can send it: at least one letter, digit or symbol left.
function CodeEntry.canRedeem(text: string): boolean
	return #CodeEntry.clean(text) > 0
end

return CodeEntry
