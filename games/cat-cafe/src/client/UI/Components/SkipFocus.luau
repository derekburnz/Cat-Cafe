--!strict
-- #5624 (Derek 2026-11-20, PS4: "X just rebuys the crate if they try clicking it to skip", "if you click x to skip it
-- has you hovering cafe and just teleports you away"): behind the switch `padSkip`. Roblox gives a controller's
-- bottom face button (A on Xbox, Cross on PlayStation, both Enum.KeyCode.ButtonA) to the selected button first, so
-- while a button stayed selected under a skippable reel, wheel or scene, the skip press pressed it (Buy again, the
-- HUD's Cafe). While held, nothing is selected; the press reaches the skip alone, and the selection comes back after.
--   SkipFocus.on() -> boolean          the switch
--   SkipFocus.hold() -> release         clears the selection and keeps it clear until release() (safe to call twice)
--   SkipFocus.cross() -> boolean        the controller is a PlayStation one (Roblox names ButtonA "ButtonCross")
--   SkipFocus.hint(lastInput) -> string the skip line: SpinLogic.skipHint, with "Press X to skip" on a PlayStation pad
--
-- Roblox terms: GuiService.SelectedObject is the button a controller has highlighted; ButtonA presses it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local SpinLogic = require(script.Parent.SpinLogic)

local SkipFocus = {}

SkipFocus.FLAG = "LiveFlag_padSkip"
SkipFocus.CROSS_HINT = "Press X to skip"

local holds = 0
local saved: GuiObject? = nil
local keeper: RBXScriptConnection? = nil

function SkipFocus.on(): boolean
	return ReplicatedStorage:GetAttribute(SkipFocus.FLAG) == true
end

-- Whether `object` may be selected again: still shown under the player's own screen.
local function usable(object: GuiObject): boolean
	local player = Players.LocalPlayer
	local playerGui = if player ~= nil then player:FindFirstChildOfClass("PlayerGui") else nil
	return playerGui ~= nil
		and object:IsDescendantOf(playerGui)
		and object.Visible
		and object.Selectable
end

function SkipFocus.hold(): () -> ()
	holds += 1
	if holds == 1 then
		saved = GuiService.SelectedObject
		GuiService.SelectedObject = nil
		keeper = RunService.Heartbeat:Connect(function()
			if GuiService.SelectedObject ~= nil then
				GuiService.SelectedObject = nil -- a window's own pick while the scene plays
			end
		end)
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		holds -= 1
		if holds > 0 then
			return
		end
		local connection = keeper
		keeper = nil
		if connection ~= nil then
			connection:Disconnect()
		end
		local back = saved
		saved = nil
		if back ~= nil and GuiService.SelectedObject == nil and usable(back) then
			GuiService.SelectedObject = back
		end
	end
end

function SkipFocus.cross(): boolean
	local ok, name = pcall(function()
		return UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	end)
	return ok and type(name) == "string" and string.find(name, "Cross", 1, true) ~= nil
end

function SkipFocus.hint(lastInput: string): string
	if SkipFocus.on() and lastInput:sub(1, 7) == "Gamepad" and SkipFocus.cross() then
		return SkipFocus.CROSS_HINT
	end
	return SpinLogic.skipHint(lastInput)
end

return SkipFocus
