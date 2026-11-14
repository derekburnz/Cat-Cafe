--!strict
-- #4311 (Derek 2026-11-14: "I know their is a low quality mode just make it better and suggest it to them"): on a
-- touch screen with Low performance off, the frames a second are averaged over PerfSuggest.WINDOW_SECONDS windows.
-- Windows during a cutscene or the intro do not count, and nothing does in the first minute. After
-- PerfSuggest.WINDOWS slow windows in a row, the slide-in ask card asks once: "Turn on" sets Low performance the
-- way the Settings switch does, and either button saves perfAsked so it never asks again. A card that is busy now
-- (another ask, too soon after one) tries again on the next window. TelemetryReport perf_suggest logs how it went.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IntroController = require(script.Parent.IntroController)
local Net = require(script.Parent.Parent.Net)
local PerfSuggest = require(Shared:WaitForChild("PerfSuggest"))
local Scale = require(script.Parent.Parent.UI.Scale)
local UI = require(script.Parent.Parent.UI)

local PerfSuggestController = {}

local TITLE = "Game running slow?"
local LINE = "Low performance mode makes it smoother on this device."

local function report(outcome: string)
	Net.fire("TelemetryReport", PerfSuggest.TELEMETRY, outcome)
end

local function ask(): boolean
	local ui: any = UI
	local done = false
	local function finish(outcome: string, turnOn: boolean)
		if done then
			return
		end
		done = true
		if turnOn then
			ui.events.setSetting:Fire("lowPerformance", true)
		end
		ui.events.setSetting:Fire(PerfSuggest.ASKED_KEY, true)
		report(outcome)
	end
	local shown = ui.asks.card({
		title = TITLE,
		line = LINE,
		choices = {
			{ id = "on", label = "Turn on", style = "primary" },
			{ id = "no", label = "No thanks" },
		},
		answer = function(choice: string?)
			if choice == "on" then
				finish("accepted", true)
			elseif choice == "no" then
				finish("declined", false)
			end
		end,
		ended = function(how: string)
			if how == "closed" then
				finish("declined", false)
			elseif how ~= "answered" then
				done = true
				report("ignored")
			end
		end,
	})
	if shown then
		report("shown")
	end
	return shown
end

function PerfSuggestController.start()
	local started = os.clock()
	local run = 0
	local asked = false
	local frames = 0
	local windowStart = os.clock()
	local counted = true
	RunService.RenderStepped:Connect(function()
		frames += 1
		local ui: any = UI
		if ui.cutscene.on or IntroController.playing() then
			counted = false
		end
	end)
	task.spawn(function()
		while not asked and Players.LocalPlayer ~= nil do
			task.wait(PerfSuggest.WINDOW_SECONDS)
			local now = os.clock()
			local fps = frames / math.max(now - windowStart, 0.001)
			local elapsed = now - started
			run = PerfSuggest.step(run, fps, counted and elapsed >= PerfSuggest.SKIP_SECONDS)
			frames, windowStart, counted = 0, now, true
			if
				PerfSuggest.due(
					run,
					elapsed,
					Scale.isTouch(),
					UI.settings.value("lowPerformance"),
					UI.settings.value(PerfSuggest.ASKED_KEY)
				) and ask()
			then
				asked = true
			end
		end
	end)
end

return PerfSuggestController
