--!strict
-- Analytics custom field text. Roblox refuses a whole custom field when its value holds a comma, a double quote,
-- a single quote or a slash ("Event field CustomField02 is invalid", seen in the live server log 2026-11-11) or is
-- longer than 50 characters (the same error, "greater than 50 characters", 2026-11-14), so the
-- breakdown is lost for that event. Telemetry passes every field through here first: a slash becomes a dash, a comma
-- a space, quotes go, and the value is cut to MAX (50) characters. Pure, no services.

local FieldText = {}

FieldText.MAX = 50

function FieldText.clean(value: string): string
	local text = string.gsub(value, "/", "-")
	text = string.gsub(text, ",", " ")
	text = string.gsub(text, "[\"']", "")
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(string.gsub(text, "^ ", ""), " $", "")
	if #text > FieldText.MAX then
		text = string.sub(text, 1, FieldText.MAX)
	end
	return text
end

return FieldText
