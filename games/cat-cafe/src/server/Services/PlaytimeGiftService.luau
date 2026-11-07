--!strict
-- The like and favourite gifts (#1947, like-prompts.md section 2): once a second, a loaded player whose account has
-- played long enough for a gift not yet paid (shared/PlaytimeGifts) has it marked and paid at once (Payout), then
-- hears ProfileSync and PlaytimeGift(kind, paid) for the card. The gift is for playing: nothing the client sends pays
-- it, and the card's buttons (like, favourite, close) only reach analytics (Telemetry playtime_gift). A second gift
-- in one session waits PlaytimeGifts.GAP_SECONDS after the first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CafeService = require(script.Parent.CafeService)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local Payout = require(script.Parent.Payout)
local PlayTime = require(script.Parent.Parent.Util.PlayTime)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)

local PlaytimeGiftService = {}

local CHECK_SECONDS = 1

local lastPaidAt: { [Player]: number } = {} -- os.clock() of this session's last gift

-- true when a gift was paid this tick
local function check(player: Player): boolean
	local profile = DataService.get(player)
	if profile == nil then
		return false
	end
	local last = lastPaidAt[player]
	if last ~= nil and os.clock() - last < PlaytimeGifts.GAP_SECONDS then
		return false
	end
	local due: PlaytimeGifts.Kind? = PlaytimeGifts.due(profile, PlayTime.seconds(player, profile))
	if due == nil then
		return false
	end
	local kind: PlaytimeGifts.Kind = due
	-- marked before paying, so a failure inside the payout never pays it twice
	PlaytimeGifts.mark(profile, kind)
	lastPaidAt[player] = os.clock()
	local paid = Payout.pay(player, profile, PlaytimeGifts.prize(kind), kind .. "_gift")
	CafeService.sync(player)
	Net.fire(player, "PlaytimeGift", kind, paid)
	return true
end

function PlaytimeGiftService.start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastPaidAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for _, player in DataService.loadedPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn("[PlaytimeGiftService] " .. tostring(err))
				end
			end
		end
	end)
end

return PlaytimeGiftService
