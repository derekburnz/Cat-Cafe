--!strict
-- Controller rumble (#4224, Better on Every Device): a short buzz in the gamepad's big motor for the moments that
-- already bump the camera (a missed catch, a shove, the cannon's launch, a prize landing) and a light one for your
-- own catch, stronger the rarer the cat. Only while the last thing the player touched is a gamepad whose motor
-- Roblox says it can drive. Phones never vibrate (#5214, Derek Nov 18: no need), and keyboard and mouse get nothing. Context.shake and Context.rumble call it, so it follows the Screen
-- shake setting; it still plays with Reduce Motion, since nothing on screen moves.
--
-- Context only calls it while the `deviceFixes` switch is on (off by default until the Tue 2026-11-17 update).
--
-- One pulse at a time: a new one replaces one still running, and the motor always goes back to 0 (also if the
-- gamepad is put down mid pulse). Numbers in Presets.rumble.

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")

local Presets = require(script.Parent.Presets)

local Rumble = {}

local MOTOR = Enum.VibrationMotor.Large
local PADS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

local turn = 0 -- the pulse now running; a later one takes over

-- The motor's strength (0 to 1) for a camera bump of `studs`: `perStud` each, never under `least` (a bump you can
-- feel) or over `most` (never the motor's full buzz).
function Rumble.strength(studs: number): number
	local r = Presets.rumble
	if studs ~= studs or studs <= 0 then
		return 0
	end
	return math.clamp(studs * r.perStud, r.least, r.most)
end

-- How long a pulse runs: `seconds` kept between `shortest` and `longest`.
function Rumble.length(seconds: number): number
	local r = Presets.rumble
	if seconds ~= seconds or seconds <= 0 then
		return 0
	end
	return math.clamp(seconds, r.shortest, r.longest)
end

-- Your own catch: the pulse for the cat's rarity (seconds, strength); an unknown rarity gets the Common one.
function Rumble.catch(rarity: string): (number, number)
	local r = Presets.rumble
	local row = r.catch[rarity] or r.catch.Common
	return row.seconds, row.strength
end

local function pad(): Enum.UserInputType?
	local last = UserInputService:GetLastInputType()
	if not PADS[last] then
		return nil
	end
	local ok, can = pcall(function(): boolean
		return HapticService:IsVibrationSupported(last)
			and HapticService:IsMotorSupported(last, MOTOR)
	end)
	return if ok and can then last else nil
end

local function set(on: Enum.UserInputType, strength: number)
	pcall(function()
		HapticService:SetMotor(on, MOTOR, strength)
	end)
end

-- Buzzes the gamepad in use for `seconds` at `strength` (0 to 1). Nothing on a phone or a keyboard.
function Rumble.pulse(seconds: number, strength: number)
	local length = Rumble.length(seconds)
	local level = math.clamp(strength, 0, Presets.rumble.most)
	if length <= 0 or level <= 0 then
		return
	end
	local on = pad()
	if on == nil then
		return
	end
	turn += 1
	local mine = turn
	set(on, level)
	task.delay(length, function()
		if turn == mine then
			set(on, 0)
		end
	end)
end

-- A camera bump's pulse (Context.shake): as long as the bump, as strong as its studs say.
function Rumble.bump(seconds: number, studs: number)
	Rumble.pulse(seconds, Rumble.strength(studs))
end

return Rumble
