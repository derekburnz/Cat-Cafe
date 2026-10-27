--!strict
-- The code box's text rules (F65, data-model section 11d), the way the server reads a code: letters and digits,
-- big or small, 1 to CodeMaxLength (20). The box drops anything else as it is typed, so "play test!" becomes
-- "playtest", and Redeem lights once a letter or digit is in. The server trims and lowercases again; this only saves
-- a wasted try against the wrong-code lock. Pure: no Theme, so the cloud spec runner can load it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local CodeEntry = {}

CodeEntry.MAX_LENGTH = (Config.CodeMaxLength or 20) :: number
CodeEntry.ANSWER_SECONDS = 5 -- Redeem lights again when no CodeResult has come back in this long
-- the server takes one RedeemCode per 2 s and drops the rest without an answer (Net.luau), so Redeem stays grey
-- this long after each send (review N183)
CodeEntry.RESEND_SECONDS = 2

-- The text with everything but letters and digits taken out, cut to MAX_LENGTH.
function CodeEntry.clean(text: string): string
	local kept = text:gsub("[^%w]", "")
	return kept:sub(1, CodeEntry.MAX_LENGTH)
end

-- Whether Redeem can send it: at least one letter or digit.
function CodeEntry.canRedeem(text: string): boolean
	return #CodeEntry.clean(text) > 0
end

return CodeEntry
