--!strict
-- Trading on this client (F102, trading.md section 6). The client only asks: the UI's trade signals go to the server
-- as they are (TradeRequest, TradeRespond, TradeOffer, TradeReady, TradeConfirm, TradeCancel), and the server's
-- answers go to the UI's hooks: TradeAsked to `UI.trade.asked` (the request card), every TradeState to
-- `UI.trade.state` (nil closes the window), TradeDone to `UI.trade.done` and TradeEnded to `UI.trade.ended`.
-- `TradeController.state` keeps the last TradeState. Effects/Trade and Audio listen to TradeDone themselves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(script.Parent.Parent.Net)
local Types = require(Shared:WaitForChild("Types"))
local UI = require(script.Parent.Parent.UI)

local TradeController = {}

TradeController.state = nil :: Types.TradeStateView?

-- The UI's trade hook `name`, or nil until the UI has it.
local function hook(name: string): ((...any) -> ())?
	local trade = (UI :: any).trade
	local fn = if trade ~= nil then trade[name] else nil
	return if type(fn) == "function" then fn else nil
end

local function call(name: string, ...: any)
	local fn = hook(name)
	if fn ~= nil then
		fn(...)
	end
end

-- Forwards the UI signal `signalName` (when the UI has it) to the remote `remote` with its arguments.
local function forward(signalName: string, remote: string)
	local signal = (UI.events :: any)[signalName]
	if signal ~= nil then
		signal:Connect(function(...: any)
			Net.fire(remote, ...)
		end)
	end
end

function TradeController.start()
	forward("requestTrade", "TradeRequest")
	forward("respondTrade", "TradeRespond")
	forward("tradeOffer", "TradeOffer")
	forward("tradeReady", "TradeReady")
	forward("tradeConfirm", "TradeConfirm")
	forward("tradeCancel", "TradeCancel")
	Net.on(
		"TradeAsked",
		function(requestId: string, fromUserId: number, fromName: string, expiresAt: number)
			call("asked", requestId, fromUserId, fromName, expiresAt)
		end
	)
	Net.on("TradeState", function(state: Types.TradeStateView?)
		TradeController.state = state
		call("state", state)
	end)
	Net.on(
		"TradeDone",
		function(tradeId: string, gave: { Types.CatSummary }, got: { Types.CatSummary })
			TradeController.state = nil
			call("done", tradeId, gave, got)
		end
	)
	Net.on("TradeEnded", function(tradeId: string, reason: string)
		TradeController.state = nil
		call("ended", tradeId, reason)
	end)
end

return TradeController
