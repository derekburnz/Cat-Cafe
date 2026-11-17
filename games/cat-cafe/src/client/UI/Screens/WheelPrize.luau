--!strict
-- #4876 (Derek 2026-11-16: "close the wheel and pop up on screen with an image of what you got after the spin lands
-- (wait 1 second then close spin and show on screen) for 2-3 seconds"): the Admin Wheel's prize card. "You got!"
-- over the prize's picture (the cat itself for a cat slice) and what the server paid. It sits in the middle of the
-- screen for SECONDS or until tapped; only the card takes the tap. It sells nothing and opens nothing.
--   show(prizeId, words, catId?, done?)   the card for that prize; `done` runs once it goes (timer, tap or hide)
--   hide()
--   isShowing() -> boolean
-- Names for Motion-FX-Agent: the ScreenGui is CatCafeWheelPrize, the card `Card`, its picture holder `Picture`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatPortrait = require(script.Parent.Parent.Components.CatPortrait)
local Create = require(script.Parent.Parent.Components.Create)
local GamepadNav = require(script.Parent.Parent.Components.GamepadNav)
local ItemIcon = require(script.Parent.Parent.Components.ItemIcon)
local Outline = require(script.Parent.Parent.Components.Outline)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Theme = require(script.Parent.Parent.Theme)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any

export type WheelPrize = {
	screenGui: ScreenGui,
	show: (
		self: WheelPrize,
		prizeId: string,
		words: string,
		catId: string?,
		done: (() -> ())?
	) -> (),
	hide: (self: WheelPrize) -> (),
	isShowing: (self: WheelPrize) -> boolean,
	destroy: (self: WheelPrize) -> (),
}

local SECONDS = 2.5
local CARD_W = 280
local CARD_H = 250
local PICTURE = 120
local PAD = 12

local WheelPrize = {}
WheelPrize.__index = WheelPrize

function WheelPrize.new(parent: Instance): WheelPrize
	local self = setmetatable({}, WheelPrize) :: any
	self._token = 0
	self._done = nil :: (() -> ())?
	self._icon = nil :: ItemIcon.ItemIcon?
	self._portrait = nil :: CatPortrait.CatPortrait?

	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeWheelPrize",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30, -- over the HUD and the loot card (25)
		Parent = parent,
	})
	self.screenGui = screenGui
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._uiScale = Scale.bind(root)

	local card: TextButton = Create("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.modal.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Visible = false,
		Parent = root,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius + 4) }),
		Create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Theme.colors.gold,
			Thickness = Theme.sizes.outline + 2,
		}),
	})
	self._card = card
	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD - 2),
		Size = UDim2.new(1, -PAD * 2, 0, 34),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody + 12,
		TextColor3 = Theme.colors.gold,
		Text = "You got!",
		Parent = card,
	})
	Outline.text(title, 2)
	self._picture = Create("Frame", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, PAD + 36),
		Size = UDim2.fromOffset(PICTURE, PICTURE),
		Parent = card,
	}) :: Frame
	self._words = Create("TextLabel", {
		Name = "Prize",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD + 36 + PICTURE + 6),
		Size = UDim2.new(1, -PAD * 2, 0, CARD_H - (PAD + 36 + PICTURE + 6) - PAD),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textBody + 2,
		TextColor3 = Theme.modal.text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = card,
	}) :: TextLabel
	card.Activated:Connect(function()
		self:hide()
	end)
	return self :: WheelPrize
end

function WheelPrize._clear(self: any)
	local icon: ItemIcon.ItemIcon? = self._icon
	if icon then
		icon:destroy()
		self._icon = nil
	end
	local portrait: CatPortrait.CatPortrait? = self._portrait
	if portrait then
		portrait:destroy()
		self._portrait = nil
	end
end

-- The prize's picture: the cat for a cat slice, else the item's own picture (AdminWheel.PRIZES ids).
function WheelPrize._paint(self: any, prizeId: string, catId: string?)
	self:_clear()
	local def = if catId ~= nil and catId ~= "" then Catalog.getCat(catId) else nil
	if def ~= nil then
		local portrait = CatPortrait.new({
			parent = self._picture,
			size = UDim2.fromScale(1, 1),
		})
		portrait:set(def)
		self._portrait = portrait
		return
	end
	local icon = ItemIcon.new({
		parent = self._picture,
		size = UDim2.fromScale(1, 1),
		name = "Icon",
		badge = "none",
	})
	self._icon = icon
	if prizeId == "rerolls20" or prizeId == "mega" then
		icon:set(nil, Theme.icons.spin, "Epic", ShopIcons.deal("token"))
	elseif prizeId == "fish200" then
		icon:set(nil, Theme.icons.goldenFish, "Legendary", ShopIcons.deal("fish"))
	elseif prizeId == "crates5" then
		icon:set(nil, Theme.icons.crate, "Legendary", ShopIcons.deal("crate"))
	elseif prizeId == "potions" then
		icon:setPotion("lucky_potion", "Epic")
	elseif prizeId == "money3x" then
		icon:setPotion("admin_money_potion", "Legendary")
	else
		icon:set(nil, Theme.icons.spin, "Epic", nil)
	end
end

function WheelPrize.show(
	self: any,
	prizeId: string,
	words: string,
	catId: string?,
	done: (() -> ())?
)
	self:_finish() -- a card still up hands over first
	self._token += 1
	local token = self._token
	self._done = done
	self:_paint(prizeId, catId)
	self._words.Text = words
	self._card.Visible = true
	task.delay(SECONDS, function()
		if self._token == token then
			self:hide()
		end
	end)
	-- #4224 (console): B puts it away
	GamepadNav.pushBack("wheelPrize", self._card, function(): boolean?
		self:hide()
		return true
	end)
end

function WheelPrize._finish(self: any)
	local done = self._done
	self._done = nil
	if done then
		task.spawn(done)
	end
end

function WheelPrize.hide(self: any)
	GamepadNav.popBack("wheelPrize")
	self._token += 1
	self._card.Visible = false
	self:_clear()
	self:_finish()
end

function WheelPrize.isShowing(self: any): boolean
	return self._card.Visible
end

function WheelPrize.destroy(self: any)
	self._done = nil
	self:_clear()
	self.screenGui:Destroy()
end

return WheelPrize
