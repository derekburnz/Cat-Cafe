--!strict
-- #2324 (Derek2: "out of breath shows a cooldown time left and make it a brief text message and not long ex: 'cooling
-- down 1 second'"): the one line every cooldown refusal reads, the seconds left rounded up (never 0 while it runs).
-- The client's catch card and Tackle bar read the same format (UI-Engineer's #2343).

local Cooldown = {}

function Cooldown.text(secondsLeft: number): string
	local left = if secondsLeft == secondsLeft then secondsLeft else 1 -- NaN reads as 1
	return string.format("Cooling down %ds", math.max(1, math.ceil(left)))
end

-- Whether `text` is a cooldown refusal, for the abuse tests and anything that matches on it.
function Cooldown.isText(text: string?): boolean
	return text ~= nil and string.match(text, "^Cooling down %d+s$") ~= nil
end

return Cooldown
