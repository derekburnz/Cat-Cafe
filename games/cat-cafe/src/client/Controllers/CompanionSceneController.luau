--!strict
-- #5284 (Derek 2026-11-18: "make the cat companion ... to unlock at tier 2 with a scene make sure it doesn't overlap
-- other cutscenes"; Design-Agent's companion-scene-5284 spec; switch companionScene, off by default): after the rank
-- up to Follower.OPEN_TIER, once per account, the best cat the player owns (shared/CompanionScene.pick) becomes their
-- Cat Companion (SetFollower, which the server checks as for a tap on Follow), in a short scene: Motion-FX's
-- Effects/CompanionUnlockCut when it is there, then the "Cat Companion unlocked!" card and a soft arrow on Cats for
-- ARROW_SECONDS with no dim (nothing is required). With no cat, the card says to pick one in Cats.
-- It never overlaps anything: it waits for the player to be free for SETTLE seconds, with no cutscene or quiet hold,
-- no intro, no station cut, no flight or carry, no catch circles, no open window, no card (bowl, pop-up, perk, rare
-- reveal), no banner across the top and no tutorial glow (the Rank Up walk-through, the Cannon point and the like).
-- A player who never gets free in FREE_MOST seconds still gets their companion, with a toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local CompanionScene = require(Shared:WaitForChild("CompanionScene"))
local Follower = require(Shared:WaitForChild("Follower"))
local IntroController = require(script.Parent.IntroController)
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(script.Parent.Parent.Moments)
local Net = require(script.Parent.Parent.Net)
local StationUnlockCut = require(script.Parent.Parent.Effects.StationUnlockCut)
local TutorialGlow = require(script.Parent.Parent.UI.Components.TutorialGlow)
local UI = require(script.Parent.Parent.UI)
local UIController = require(script.Parent.UIController)

local CompanionSceneController = {}

local POLL = 0.2
local LATE = 2 -- seconds after the rank up before looking (the rank up's own cards come about 1 s after it)
local SETTLE = 1 -- seconds the player must stay free first
local FREE_MOST = 600 -- seconds to wait for a free moment before the toast instead
local ARROW_SECONDS = 5
local CARD_WAIT = 0.5 -- seconds after the card closes before the arrow, so it lands on a settled HUD
local BAIT_CARD = "CatCafeBaitCard" -- UI/Screens/BaitCard's ScreenGui
local AREA_TITLE = "CatCafeAreaTitle" -- UI Screens/AreaTitle
local CUT = "CompanionUnlockCut" -- Motion-FX's Effects module, looked for by name so neither PR waits on the other

local started = false
local GLOW_EVERY = 1
local glowLookedAt, glowSeen = -math.huge, false
local asked = false

local function ui(): any
	return UI :: any
end

local function flag(key: string): boolean
	local value = ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key)
	if LiveFlags.OFF_BY_DEFAULT[key] then
		return value == true
	end
	return value ~= false
end

local function shown(playerGui: Instance?, name: string): boolean
	local gui = if playerGui ~= nil then playerGui:FindFirstChild(name) else nil
	return gui ~= nil and gui:IsA("ScreenGui") and (gui :: ScreenGui).Enabled
end

-- Whether a tutorial step is pointing at something now: its gold ring is on screen.
local function glowing(playerGui: Instance?): boolean
	if playerGui == nil then
		return false
	end
	for _, item in playerGui:GetDescendants() do
		if item.Name == TutorialGlow.NAME and item:IsA("GuiObject") then
			local gui = item:FindFirstAncestorOfClass("ScreenGui")
			if gui ~= nil and gui.Enabled then
				return true
			end
		end
	end
	return false
end

-- Nothing else holds the screen or the player.
local function free(): boolean
	local character = Players.LocalPlayer.Character
	if character == nil then
		return false
	end
	if
		character:GetAttribute("CarryingCatId") ~= nil
		or character:GetAttribute("Launching") == true
	then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false -- dead, or between characters
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if shown(playerGui, BAIT_CARD) then
		return false
	end
	local banner = if playerGui ~= nil then playerGui:FindFirstChild(AREA_TITLE) else nil
	local bannerCard = if banner ~= nil then banner:FindFirstChild("Card", true) else nil
	if bannerCard ~= nil and bannerCard:IsA("GuiObject") and (bannerCard :: GuiObject).Visible then
		return false
	end
	local u = ui()
	local perkCard = if u.perks ~= nil then u.perks.card else nil
	if perkCard ~= nil and perkCard:isShowing() then
		return false
	end
	local bigShowing: any = if u.bigPull ~= nil then u.bigPull.showing else nil
	if type(bigShowing) == "function" and (bigShowing :: () -> boolean)() then
		return false
	end
	local circles: any = if u.catch ~= nil then u.catch.circlesActive else nil
	if type(circles) == "function" and (circles :: () -> boolean)() then
		return false
	end
	local cardsUp: any = u.popupsShowing
	if type(cardsUp) == "function" and (cardsUp :: () -> boolean)() then
		return false
	end
	if u.isOpen() ~= nil then
		return false -- a window is open (the Rank Up window among them)
	end
	-- the glow search walks the whole PlayerGui, so at most once a GLOW_EVERY (Review-QA: cheaper on phones)
	if os.clock() - glowLookedAt >= GLOW_EVERY then
		glowLookedAt = os.clock()
		glowSeen = glowing(playerGui)
	end
	if glowSeen then
		return false
	end
	local held: any = if u.cutscene ~= nil then u.cutscene.held else nil
	return not (type(held) == "function" and (held :: () -> boolean)())
		and not (u.tips ~= nil and u.tips.staged == true)
		and not IntroController.playing()
		and not StationUnlockCut.playing()
end

local function waitFree(): boolean
	local untilAt = os.clock() + FREE_MOST
	local since: number? = nil
	while os.clock() < untilAt do
		if free() then
			local at = since or os.clock()
			since = at
			if os.clock() - at >= SETTLE then
				return true
			end
		else
			since = nil
		end
		task.wait(POLL)
	end
	return false
end

local function stage(held: boolean)
	local u = ui()
	local setCutscene: any = u.setCutscene
	if type(setCutscene) == "function" then
		(setCutscene :: (boolean) -> ())(held)
	end
	local clear: any = if u.tips ~= nil then u.tips.clearStage else nil
	if type(clear) == "function" then
		(clear :: (boolean) -> ())(held)
	end
end

-- The cat's name and its perk line, the Cats screen's words ("+5% money").
local function describe(uid: string): (string, string?, string?)
	local state = UIController.state
	local cat: any = if state ~= nil and type(state.cats) == "table" then state.cats[uid] else nil
	local def = if cat ~= nil then Catalog.getCat(cat.catId) else nil
	if cat == nil or def == nil then
		return "Your cat", nil, nil
	end
	local name = if type(cat.name) == "string" and cat.name ~= "" then cat.name else def.name
	local boost: Follower.Boost = if state ~= nil
			and type((state :: any).follower) == "table"
			and (state :: any).follower.boost == "luck"
		then "luck"
		else "money"
	local perk = Follower.text(Follower.amount(def.rarity, boost, cat.variant), boost)
	return name, perk, cat.catId
end

local function arrow()
	local u = ui()
	local find: any = u.catsButton
	local target: GuiObject? = if type(find) == "function"
		then (find :: () -> GuiObject?)()
		else nil
	if target == nil then
		return
	end
	TutorialGlow.set(target, true, nil, true) -- the ring and arrow, no dim: nothing is required
	task.delay(ARROW_SECONDS, function()
		TutorialGlow.set(target, false)
	end)
end

local function card(uid: string?)
	local u = ui()
	if uid == nil then
		u.toast(CompanionScene.NAME .. " unlocked! Pick one in Cats.", "info")
		task.delay(CARD_WAIT, arrow)
		return
	end
	local name, perk, catId = describe(uid :: string)
	local showCatFound: any = u.showCatFound
	if catId ~= nil and type(showCatFound) == "function" then
		(showCatFound :: (string, boolean, any) -> ())(catId, false, {
			banner = CompanionScene.NAME .. " unlocked!",
			line = CompanionScene.line(name, perk),
		})
	else
		u.toast(CompanionScene.NAME .. " unlocked! " .. CompanionScene.line(name, perk), "good")
	end
	-- the arrow once the card has gone
	task.spawn(function()
		local untilAt = os.clock() + 30
		task.wait(CARD_WAIT)
		local cardsUp: any = u.popupsShowing
		while
			type(cardsUp) == "function"
			and (cardsUp :: () -> boolean)()
			and os.clock() < untilAt
		do
			task.wait(POLL)
		end
		task.wait(CARD_WAIT)
		arrow()
	end)
end

local function ranked(tier: number)
	local state = UIController.state
	local seen = if state ~= nil then state.tipsSeen else nil
	if
		asked
		or not CompanionScene.due(tier, seen, flag(CompanionScene.FLAG), flag(Follower.FLAG))
	then
		return
	end
	asked = true
	task.spawn(function()
		task.wait(LATE)
		local ready = waitFree()
		local now = UIController.state
		local uid = CompanionScene.pick(if now ~= nil then now.cats :: any else nil)
		local following = now ~= nil
			and type((now :: any).follower) == "table"
			and type((now :: any).follower.uid) == "string"
			and (now :: any).follower.uid ~= Follower.HOME
		-- a player who already picked a companion keeps theirs
		local setUid: string? = nil
		if following then
			uid = (now :: any).follower.uid
		else
			setUid = uid
		end
		-- the real follower comes once the scene hands back (Motion-FX: the cut walks its own copy in, so firing first
		-- put two of the cat beside the player)
		local function follow()
			if setUid ~= nil then
				Net.fire("SetFollower", setUid)
				setUid = nil
			end
		end
		if not ready then
			follow()
			card(uid)
			Net.fire("TipSeen", CompanionScene.KEY, true)
			return
		end
		local module = script.Parent.Parent.Effects:FindFirstChild(CUT)
		local cut: any = nil
		if module ~= nil and module:IsA("ModuleScript") then
			local ok, loaded = pcall(require, module)
			cut = if ok then loaded else nil
		end
		local play: any = nil
		if type(cut) == "table" then
			play = cut.play
		end
		if uid ~= nil and type(play) == "function" then
			local catId: string? = nil
			local _, _, id = describe(uid :: string)
			catId = id
			stage(true)
			local playing = (play :: (string?, (string) -> ()) -> any)(
				catId,
				function(outcome: string)
					stage(false)
					follow()
					card(uid)
					Net.fire("TipSeen", CompanionScene.KEY, outcome == "skipped")
				end
			)
			if playing == true then
				return
			end
			stage(false)
		end
		follow()
		card(uid)
		Net.fire("TipSeen", CompanionScene.KEY, false)
	end)
end

function CompanionSceneController.start()
	if started then
		return
	end
	started = true
	Moments.RankUp:Connect(ranked)
end

return CompanionSceneController
