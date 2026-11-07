--!strict
-- #2207 (Derek2 11-07: "A lot of the pop-up text gets cut off"): a one-line label whose words can run past its box
-- shrinks its text to fit instead of ending in "...". It never goes under MIN (12, which the phone's 0.75 scale
-- draws at the 9 px the UI gate allows, Theme.sizes.textTiny); only past that does Roblox's "..." still cut the
-- end. Short words keep the label's own TextSize, as UITextSizeConstraint caps TextScaled at it.

local FitText = {}

FitText.MIN = 12

function FitText.shrink(label: TextLabel, min: number?)
	local size = label.TextSize
	label.TextScaled = true
	local found = label:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint?
	local cap: UITextSizeConstraint = found or Instance.new("UITextSizeConstraint")
	cap.Parent = label
	cap.MaxTextSize = size
	cap.MinTextSize = math.min(size, min or FitText.MIN)
end

return FitText
