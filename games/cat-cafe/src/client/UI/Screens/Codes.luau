--!strict
-- The code box (F65, data-model section 11d; Derek 2026-10-27 19:33 and 20:10): walking into the glowing circle in
-- front of the Codes Cat opens it, and walking out closes it and clears it (the controller watches the distance and
-- calls UI.codes.open and UI.codes.close). A box for the code with
-- Redeem beside it, and an answer line: "Code redeemed!" in green with the prize as little pictures under it
-- (Components/PrizeChips), or the server's refusal in red ("That code doesn't exist", "You already used that code",
-- "Too many tries, wait a minute"). The box takes letters, digits and "!?#$&*@_-." only, up to CodeMaxLength
-- (Components/CodeEntry), and Enter redeems too. Redeem shows "..." until CodeResult answers, or for 5 s, and stays
-- grey until 2 s after the last send, since the server drops a second try inside that (review N183).
--
-- The window sits in the middle of the screen (Derek 2026-10-28: "codes need to be more centred in middle of
-- screen"); on a phone with no keyboard it stays near the top, so the on-screen keyboard never covers it. It does
-- not take the keyboard when it opens: the player is walking into the circle, so W, A, S and D keep moving the
-- character until the box is clicked.
--
-- #1428 (the friend 11-05: "change the codes stand to be mixed with the store stand so that they have to see the store
-- to find codes"): the box, Redeem and the answer sit in one Body frame, and mount(parent) moves that frame into the
-- Store's Codes tab (Screens/Store, UI.store); the Codes Cat's circle then opens the Store on that tab. mount(nil)
-- puts it back in this window.
--
-- Roblox terms: a TextBox is an editable text field; its FocusLost(enterPressed) fires when Enter is pressed in it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Button = require(script.Parent.Parent.Components.Button)
local CodeEntry = require(script.Parent.Parent.Components.CodeEntry)
local Create = require(script.Parent.Parent.Components.Create)
local IconArt = require(script.Parent.Parent.Components.IconArt)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Scale = require(script.Parent.Parent.Scale)
local ShopIcons = require(script.Parent.Parent.Components.ShopIcons)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

-- the dark window palette (#1028), in place of Theme.modal
local PAL = Theme.dark

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog")) :: any
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

export type Callbacks = {
	redeem: (code: string) -> (),
	close: () -> (),
}

export type Codes = {
	frame: Frame,
	setCatalog: (self: Codes, catalog: Types.Catalog) -> (),
	render: (self: Codes, state: Types.PlayerState) -> (),
	setNight: (self: Codes, night: boolean) -> (),
	onOpen: (self: Codes) -> (),
	onClose: (self: Codes) -> (),
	result: (self: Codes, ok: boolean, message: string, prize: Types.IndexPrize?) -> (),
	mount: (self: Codes, parent: Instance?) -> (),
	destroy: (self: Codes) -> (),
}

-- #1714 (Derek2: "remake the code section of the store it's very blank"): in the Store's Codes tab the box sits
-- under a header (the Codes Cat's picture, "Codes" and where new codes come from), the answer shows in place as a
-- green card with the prize or one calm refusal line, and "Codes you've used" lists PlayerState.codesRedeemed newest
-- first (Components/CodeEntry.used). No help line: the placeholder says enough, and case is still ignored. The header
-- and the list show only in the Store; the walk-up window keeps just the box and the answer.
local HEADER_LINE = "New codes come with updates and in our Roblox group."
local USED_TITLE = "Codes you've used"
local USED_EMPTY = "Codes you use show up here"
local PLACEHOLDER = "Type a code"
local NO_ANSWER = "No answer yet. Try Redeem again."

local MAX_SIZE = Vector2.new(460, 262)
local TOP_EDGE = 30 -- on a phone: room above the window for the panel's badge
local HEADER_H = 84
local HEADER_PICTURE = 64
local USED_ROW = 44
local USED_TILE = 28
local ROW = Scale.tapHeight(52) -- the box and Redeem, a finger tall on a phone
local REDEEM_WIDTH = 132
local ANSWER_HEIGHT = 24
local TILE = 40 -- a prize picture
local GAP = Theme.sizes.gap
local NIGHT_SHARE: number = Config.NightIncomeMultiplier or 0.6

local Codes = {}
Codes.__index = Codes

local function text(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	return Create("TextLabel", merged)
end

function Codes.new(callbacks: Callbacks): Codes
	local self = setmetatable({}, Codes) :: any
	self._callbacks = callbacks
	self._pending = false
	self._token = 0 -- one per Redeem, so a late timeout cannot touch a newer one
	self._open = false
	self._alive = true
	self._failed = false -- the answer line shows a refusal, which typing again clears
	self._sentAt = -math.huge -- os.clock() of the last Redeem
	self._state = nil :: Types.PlayerState?
	self._night = false
	self._connections = {} :: { RBXScriptConnection }

	local panel = Panel.new({
		dark = true, -- #1028
		name = "Codes",
		title = "Codes",
		subtitle = "From the Codes Cat",
		color = Theme.colors.berry,
		icon = "🎟️",
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	-- centred; on a touch-only phone near the top, clear of its on-screen keyboard
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	panel.frame.AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(0.5, 0.5)
	panel.frame.Position = if phone
		then UDim2.new(0.5, 0, 0, TOP_EDGE)
		else UDim2.fromScale(0.5, 0.5)
	self._panel = panel
	self.frame = panel.frame
	-- everything in one scrolling column, so the Store's Codes tab can hold it (#1428): the header, the box row, the
	-- answer and the used list, top to bottom
	local content: ScrollingFrame = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = PAL.subtext,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, {
		Create("UIListLayout", {
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
	})
	self._body = content
	self._mounted = false

	-- #1714: the header, a warm gold card with the Codes Cat's picture
	local header: Frame = Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.colors.gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_H),
		LayoutOrder = 1,
		Visible = false,
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
	})
	Outline.border(header, Theme.sizes.stroke)
	self._header = header
	local picture = text({
		Name = "Picture",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(HEADER_PICTURE, HEADER_PICTURE),
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🎟️",
		Parent = header,
	})
	IconArt.setImage(picture, ShopIcons.storeTab("codes"), 1)
	local textLeft = 12 + HEADER_PICTURE + 12
	local title = text({
		Name = "Title",
		Position = UDim2.new(0, textLeft, 0.5, -26),
		Size = UDim2.new(1, -(textLeft + 12), 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.colors.white,
		Text = "Codes",
		Parent = header,
	})
	Outline.text(title, 2)
	text({
		Name = "Line",
		Position = UDim2.new(0, textLeft, 0.5, 4),
		Size = UDim2.new(1, -(textLeft + 12), 0, 22),
		FontFace = Theme.fonts.bodyBold,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.colors.ink,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		Text = HEADER_LINE,
		Parent = header,
	})

	local row: Frame = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW),
		LayoutOrder = 2,
		Parent = content,
	})
	local box: TextBox = Create("TextBox", {
		Name = "Code",
		BackgroundColor3 = PAL.card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -(REDEEM_WIDTH + GAP), 0, ROW),
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = PAL.text,
		PlaceholderColor3 = PAL.subtext,
		PlaceholderText = PLACEHOLDER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = row,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	Outline.border(box, Theme.sizes.stroke, PAL.cardStroke)
	self._box = box
	self._redeem = Button.new({
		name = "Redeem",
		text = "Redeem",
		style = "primary",
		size = UDim2.fromOffset(REDEEM_WIDTH, ROW),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.fromScale(1, 0),
		parent = row,
		enabled = false,
		onClick = function()
			self:_submit()
		end,
	})

	-- the answer in place under the box: a green card with the prize, or one calm refusal line (#1714)
	local result: Frame = Create("Frame", {
		Name = "Result",
		BackgroundColor3 = Theme.colors.good,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})
	self._result = result
	self._answer = text({
		Name = "Answer",
		Size = UDim2.new(1, 0, 0, ANSWER_HEIGHT),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = result,
	})
	local prizeRow: Frame = Create("Frame", {
		Name = "PrizeRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TILE),
		LayoutOrder = 2,
		Visible = false,
		Parent = result,
	})
	self._prizeRow = prizeRow
	self._chips = PrizeChips.new({
		textColor = Theme.colors.white,
		outlined = true,
		parent = prizeRow,
		tile = TILE,
		textSize = Theme.sizes.textSmall,
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.fromScale(0.5, 0),
		align = Enum.HorizontalAlignment.Center,
		fitTo = prizeRow,
		fitPad = 8,
		maxPictures = 2, -- F94
	})

	-- #1714: "Codes you've used", newest first
	self._usedTitle = text({
		Name = "UsedTitle",
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textBody,
		TextColor3 = PAL.text,
		Text = USED_TITLE,
		LayoutOrder = 4,
		Visible = false,
		Parent = content,
	})
	local used: Frame = Create("Frame", {
		Name = "Used",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Visible = false,
		Parent = content,
	}, {
		Create(
			"UIListLayout",
			{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	self._used = used
	self._usedRows = {} :: { any }
	self._usedShape = nil :: string?
	self._usedEmpty = text({
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = PAL.subtext,
		Text = USED_EMPTY,
		LayoutOrder = 0,
		Parent = used,
	})

	table.insert(
		self._connections,
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local clean = CodeEntry.clean(box.Text)
			if clean ~= box.Text then
				box.Text = clean
				return -- setting Text fires this again
			end
			if self._failed and clean ~= "" then
				self:_setAnswer(nil, nil, nil)
			end
			self:_refresh()
		end)
	)
	table.insert(
		self._connections,
		box.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed then
				self:_submit()
			end
		end)
	)

	self:_refresh()
	return self :: Codes
end

function Codes.setCatalog(self: any, catalog: Types.Catalog)
	self._catalog = catalog
	self._chips:setCatalog(catalog)
	for _, usedRow in self._usedRows do
		usedRow.chips:setCatalog(catalog)
	end
end

-- The coins a prize grows with and the tier its "highest" crate opens are read from the state.
function Codes.render(self: any, state: Types.PlayerState)
	self._state = state
	self:_renderUsed()
end

-- #1714: the used list, rebuilt when the codes or their times change
function Codes._renderUsed(self: any)
	local state: any = self._state
	local list = CodeEntry.used(if state then state.codesRedeemed else nil, Catalog.codes)
	local keys: { string } = {}
	for _, entry in list do
		table.insert(keys, entry.id .. "@" .. tostring(entry.at))
	end
	local shape = table.concat(keys, ",")
	if shape == self._usedShape then
		return
	end
	self._usedShape = shape
	for _, usedRow in self._usedRows do
		usedRow.chips:destroy()
		usedRow.frame:Destroy()
	end
	table.clear(self._usedRows)
	self._usedEmpty.Visible = #list == 0
	for order, entry in list do
		local frame: Frame = Create("Frame", {
			Name = entry.id,
			BackgroundColor3 = PAL.card,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, USED_ROW),
			LayoutOrder = order,
			Parent = self._used,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		})
		text({
			Name = "Code",
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0.34, -10, 1, 0),
			FontFace = Theme.fonts.display,
			TextSize = Theme.sizes.textBody,
			Text = entry.code,
			Parent = frame,
		})
		text({
			Name = "Date",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0, 64, 1, 0),
			TextSize = Theme.sizes.textSmall,
			TextColor3 = PAL.subtext,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = os.date("%b %d", entry.at) :: string,
			Parent = frame,
		})
		local prizeArea: Frame = Create("Frame", {
			Name = "Prize",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.34, 4, 0, 0),
			Size = UDim2.new(0.66, -(64 + 24), 1, 0),
			Parent = frame,
		})
		local chips = PrizeChips.new({
			textColor = PAL.text,
			parent = prizeArea,
			tile = USED_TILE,
			textSize = Theme.sizes.textSmall,
			anchorPoint = Vector2.new(0, 0.5),
			position = UDim2.fromScale(0, 0.5),
			fitTo = prizeArea,
			maxPictures = 2,
		})
		local catalog: Types.Catalog? = self._catalog
		if catalog then
			chips:setCatalog(catalog)
		end
		chips:set(entry.prize, self:_look())
		table.insert(self._usedRows, { frame = frame, chips = chips })
	end
end

function Codes.setNight(self: any, night: boolean)
	self._night = night
end

function Codes._look(self: any): PrizeChips.Look
	local state: Types.PlayerState? = self._state
	if state == nil then
		return {}
	end
	return {
		dayRate = TipJarLogic.dayRate(state.incomePerSecond, self._night, NIGHT_SHARE),
		tier = state.tier,
	}
end

-- The answer in place (#1714): ok a green card with the prize in it, a refusal one calm line, nil hides it.
function Codes._setAnswer(self: any, ok: boolean?, message: string?, prize: Types.IndexPrize?)
	self._failed = ok == false
	self._answer.Text = message or ""
	self._answer.TextColor3 = if ok then Theme.colors.white else PAL.subtext
	self._result.BackgroundTransparency = if ok then 0 else 1
	self._result.Visible = (message or "") ~= ""
	self._chips:set(prize, self:_look())
	self._prizeRow.Visible = prize ~= nil
	if ok then
		Tween.popIn(self._result, 0.85)
	end
end

function Codes._resting(self: any): boolean
	return os.clock() - self._sentAt < CodeEntry.RESEND_SECONDS
end

function Codes._refresh(self: any)
	self._box.TextEditable = not self._pending
	self._redeem:setText(if self._pending then "..." else "Redeem")
	local ready = not self._pending and not self:_resting()
	self._redeem:setEnabled(ready and CodeEntry.canRedeem(self._box.Text))
end

function Codes._submit(self: any)
	local code = CodeEntry.clean(self._box.Text)
	if self._pending or code == "" or self:_resting() then
		return
	end
	self._pending = true
	self._sentAt = os.clock()
	self._token += 1
	local token = self._token
	if self._box:IsFocused() then
		self._box:ReleaseFocus()
	end
	self:_setAnswer(nil, nil, nil)
	self:_refresh()
	self._callbacks.redeem(code)
	task.delay(CodeEntry.ANSWER_SECONDS, function()
		if self._alive and self._pending and token == self._token then
			self._pending = false
			self:_setAnswer(false, NO_ANSWER, nil)
			self:_refresh()
		end
	end)
end

-- CodeResult(ok, message, prize): a redeemed code clears the box and shows what it paid; a refusal keeps the text
-- so it can be fixed.
function Codes.result(self: any, ok: boolean, message: string, prize: Types.IndexPrize?)
	self._pending = false
	self._token += 1
	Sound.play(if ok then "uiCodeRedeem" else "uiError")
	if ok then
		self._box.Text = ""
	end
	self:_setAnswer(ok, message, if ok then prize else nil)
	self:_refresh()
	-- light Redeem again once the server would take another try
	local wait = CodeEntry.RESEND_SECONDS - (os.clock() - self._sentAt)
	if wait > 0 then
		task.delay(wait, function()
			if self._alive then
				self:_refresh()
			end
		end)
	end
end

-- A fresh box each time the player steps in.
function Codes.onOpen(self: any)
	self._open = true
	if not self._pending then
		self:_setAnswer(nil, nil, nil)
	end
	self:_refresh()
end

-- Walking out clears the field and the answer (data-model 11d).
function Codes.onClose(self: any)
	self._open = false
	if self._box:IsFocused() then
		self._box:ReleaseFocus()
	end
	self._box.Text = ""
	self:_setAnswer(nil, nil, nil)
	self:_refresh()
end

-- Moves the box into `parent` (the Store's Codes tab), or back into this window with nil. The header and the used
-- list show only in the Store (#1714).
function Codes.mount(self: any, parent: Instance?)
	self._body.Parent = parent or self._panel.content
	local mounted = parent ~= nil
	self._mounted = mounted
	self._header.Visible = mounted
	self._usedTitle.Visible = mounted
	self._used.Visible = mounted
end

function Codes.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._redeem:destroy()
	self._chips:destroy()
	for _, usedRow in self._usedRows do
		usedRow.chips:destroy()
	end
	self._body:Destroy() -- it may sit in the Store
	self._panel:destroy()
end

return Codes
