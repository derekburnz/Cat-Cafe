--!strict
-- The text on a prompt's key cap, from the input the prompt was shown for and the key's Enum name (strings, so
-- this loads in the cloud test runner):
--   label("Keyboard", "E") -> "E", label("Keyboard", "LeftShift") -> "Shift", label("Gamepad", "ButtonX") -> "X",
--   label("Gamepad", "DPadUp") -> "↑", label("Touch", ...) -> "" (the whole pill is the button on touch)

local PromptKey = {}

local KEYBOARD: { [string]: string } = {
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Space = "Space",
	Return = "Enter",
	KeypadEnter = "Enter",
	Tab = "Tab",
	Backspace = "Bksp",
	LeftShift = "Shift",
	RightShift = "Shift",
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftAlt = "Alt",
	RightAlt = "Alt",
	Up = "↑",
	Down = "↓",
	Left = "←",
	Right = "→",
}

local GAMEPAD: { [string]: string } = {
	DPadUp = "↑",
	DPadDown = "↓",
	DPadLeft = "←",
	DPadRight = "→",
	ButtonSelect = "Select",
	ButtonStart = "Start",
}

-- inputKind is the ProximityPromptInputType name ("Keyboard", "Gamepad" or "Touch"); keyName is
-- KeyboardKeyCode.Name or GamepadKeyCode.Name.
function PromptKey.label(inputKind: string, keyName: string): string
	if inputKind == "Touch" then
		return ""
	end
	if inputKind == "Gamepad" then
		local named = GAMEPAD[keyName]
		if named then
			return named
		end
		-- ButtonA -> A, ButtonR1 -> R1, ButtonL3 -> L3
		local short = keyName:match("^Button(%w+)$")
		return short or keyName
	end
	return KEYBOARD[keyName] or keyName
end

-- Wider caps for words ("Shift", "Space") so the text fits: the cap's width in pixels at a square size.
function PromptKey.width(label: string, square: number): number
	local length = utf8.len(label) or #label
	if length <= 2 then
		return square
	end
	return square + (length - 2) * math.floor(square * 0.3)
end

return PromptKey
