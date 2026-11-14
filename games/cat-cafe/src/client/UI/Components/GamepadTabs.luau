--!strict
-- #4224 (console): which tab L1 / R1 land on (GamepadNav.stepTab). Pure, so the spec runs it without the UI.
local GamepadTabs = {}

-- The index of the tab `step` (-1 or 1) away from the open one among `styles`, wrapping round; with no open tab
-- found, R1 takes the first and L1 the last. Nil with fewer than two tabs.
function GamepadTabs.index(styles: { string? }, step: number): number?
	local count = #styles
	if count < 2 then
		return nil
	end
	local open: number? = nil
	for index, style in styles do
		if style ~= nil and style ~= "ghost" then
			open = index
			break
		end
	end
	if open == nil then
		return if step > 0 then 1 else count
	end
	return (open - 1 + step) % count + 1
end

return GamepadTabs
