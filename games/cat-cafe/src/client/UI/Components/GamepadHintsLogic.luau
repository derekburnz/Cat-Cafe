--!strict
-- #4224 (console controls, from player feedback): which button hints the small strip along the bottom of the screen
-- shows on a gamepad (Components/GamepadHints). Only while the padControls switch is on and the last input came from
-- a controller; a mouse, keyboard or touch player never sees it. Pure, so the spec runs it without the UI.
--   keys(view) -> { Hint }   the hints in order, empty when the strip hides
-- view:
--   gamepad    the last input came from a controller
--   on         the padControls switch
--   window     a window is open
--   tabs       the open window shows a tab row (L1 / R1 step it)
--   selecting  a button outside a window is selected (the HUD's menu grid)
--   card       a card or drop-down list B closes shows (GamepadNav.hasBack)

export type Key = "A" | "B" | "L1" | "R1" | "Select"
export type Hint = { keys: { Key }, label: string }
export type View = {
	gamepad: boolean,
	on: boolean,
	window: boolean,
	tabs: boolean,
	selecting: boolean,
	card: boolean?,
}

local GamepadHintsLogic = {}

GamepadHintsLogic.SELECT = "Select"
GamepadHintsLogic.BACK = "Back"
GamepadHintsLogic.TABS = "Tabs"
GamepadHintsLogic.MENU = "Menu"
GamepadHintsLogic.WALK = "Walk"

-- the short text on a key's cap when the platform gives no picture for it (Xbox names; PlayStation shows its own
-- pictures through UserInputService:GetImageForKeyCode)
GamepadHintsLogic.CAP = table.freeze({
	A = "A",
	B = "B",
	L1 = "LB",
	R1 = "RB",
	Select = "View",
}) :: { [Key]: string }

function GamepadHintsLogic.keys(view: View): { Hint }
	if not (view.gamepad and view.on) then
		return {}
	end
	if view.window then
		local list: { Hint } = {}
		table.insert(list, { keys = { "A" :: Key }, label = GamepadHintsLogic.SELECT })
		table.insert(list, { keys = { "B" :: Key }, label = GamepadHintsLogic.BACK })
		if view.tabs then
			table.insert(
				list,
				{ keys = { "L1" :: Key, "R1" :: Key }, label = GamepadHintsLogic.TABS }
			)
		end
		return list
	elseif view.selecting then
		return {
			{ keys = { "A" }, label = GamepadHintsLogic.SELECT },
			{
				keys = { "B" },
				label = if view.card then GamepadHintsLogic.BACK else GamepadHintsLogic.WALK,
			},
		}
	end
	return { { keys = { "Select" }, label = GamepadHintsLogic.MENU } }
end

return GamepadHintsLogic
