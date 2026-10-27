--!strict
-- The code box (F65, data-model section 11d; Derek 2026-10-27 19:33 and 20:10): walking into the glowing circle in
-- front of the Codes Cat opens it, and walking out closes it and clears it (the controller watches the distance and
-- calls UI.codes.open and UI.codes.close). One line saying big and small letters both work, a box for the code with
-- Redeem beside it, and an answer line: "Code redeemed!" in green with the prize as little pictures under it
-- (Components/PrizeChips), or the server's refusal in red ("That code doesn't exist", "You already used that code",
-- "Too many tries, wait a minute"). The box takes letters and digits only, up to CodeMaxLength
-- (Components/CodeEntry), and Enter redeems too. Redeem shows "..." until CodeResult answers, or for 5 s.
--
-- The window sits near the top of the screen, so a phone's keyboard never covers it and the Codes Cat stays in view
-- below. It does not take the keyboard when it opens: the player is walking into the circle, so W, A, S and D keep
-- moving the character until the box is clicked.
--
-- Roblox terms: a TextBox is an editable text field; its FocusLost(enterPressed) fires when Enter is pressed in it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CodeEntry = require(script.Parent.Parent.Components.CodeEntry)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Panel = require(script.Parent.Parent.Components.Panel)
local PrizeChips = require(script.Parent.Parent.Components.PrizeChips)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local TipJarLogic = require(script.Parent.Parent.Components.TipJarLogic)
local Tween = require(script.Parent.Parent.Components.Tween)
local Types = require(script.Parent.Parent.Types)

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
	destroy: (self: Codes) -> (),
}

local HINT = "Got a code? Type it here. Big or small letters both work."
local PLACEHOLDER = "Type a code"
local NO_ANSWER = "No answer yet. Try Redeem again."

local MAX_SIZE = Vector2.new(460, 262)
local TOP_EDGE = 30 -- room above the window for the panel's ears and badge
local HINT_HEIGHT = 20
local ROW = 52 -- the box and Redeem
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
		TextColor3 = Theme.modal.text,
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
	self._state = nil :: Types.PlayerState?
	self._night = false
	self._connections = {} :: { RBXScriptConnection }

	local panel = Panel.new({
		name = "Codes",
		title = "Codes",
		subtitle = "From the Codes Cat",
		color = Theme.colors.berry,
		icon = "🎟️",
		size = UDim2.new(1, 0, 0, MAX_SIZE.Y),
		onClose = callbacks.close,
	})
	Create("UISizeConstraint", { MaxSize = MAX_SIZE, Parent = panel.frame })
	-- near the top, clear of a phone's keyboard and of the Codes Cat
	panel.frame.AnchorPoint = Vector2.new(0.5, 0)
	panel.frame.Position = UDim2.new(0.5, 0, 0, TOP_EDGE)
	self._panel = panel
	self.frame = panel.frame
	local content = panel.content

	text({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		Text = HINT,
		Parent = content,
	})
	local rowTop = HINT_HEIGHT + GAP
	local box: TextBox = Create("TextBox", {
		Name = "Code",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, rowTop),
		Size = UDim2.new(1, -(REDEEM_WIDTH + GAP), 0, ROW),
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.modal.text,
		PlaceholderColor3 = Theme.modal.subtext,
		PlaceholderText = PLACEHOLDER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = content,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	Outline.border(box, Theme.sizes.stroke, Theme.modal.cardStroke)
	self._box = box
	self._redeem = Button.new({
		name = "Redeem",
		text = "Redeem",
		style = "primary",
		size = UDim2.fromOffset(REDEEM_WIDTH, ROW),
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, rowTop),
		parent = content,
		enabled = false,
		onClick = function()
			self:_submit()
		end,
	})

	local answerTop = rowTop + ROW + GAP
	self._answer = text({
		Name = "Answer",
		Position = UDim2.fromOffset(0, answerTop),
		Size = UDim2.new(1, 0, 0, ANSWER_HEIGHT),
		FontFace = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = content,
	})
	local prizeRow: Frame = Create("Frame", {
		Name = "PrizeRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, answerTop + ANSWER_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, TILE),
		Visible = false,
		Parent = content,
	})
	self._prizeRow = prizeRow
	self._chips = PrizeChips.new({
		parent = prizeRow,
		tile = TILE,
		textSize = Theme.sizes.textSmall,
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.fromScale(0.5, 0),
		align = Enum.HorizontalAlignment.Center,
		fitTo = prizeRow,
		fitPad = 8,
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
	self._chips:setCatalog(catalog)
end

-- The coins a prize grows with and the tier its "highest" crate opens are read from the state.
function Codes.render(self: any, state: Types.PlayerState)
	self._state = state
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

-- The answer line: ok green with the prize under it, a refusal red, nil empties it.
function Codes._setAnswer(self: any, ok: boolean?, message: string?, prize: Types.IndexPrize?)
	self._failed = ok == false
	self._answer.Text = message or ""
	self._answer.TextColor3 = if ok then Theme.colors.goodDark else Theme.colors.red
	self._chips:set(prize, self:_look())
	self._prizeRow.Visible = prize ~= nil
	if prize ~= nil then
		Tween.popIn(self._prizeRow, 0.7)
	end
end

function Codes._refresh(self: any)
	self._box.TextEditable = not self._pending
	self._redeem:setText(if self._pending then "..." else "Redeem")
	self._redeem:setEnabled(not self._pending and CodeEntry.canRedeem(self._box.Text))
end

function Codes._submit(self: any)
	local code = CodeEntry.clean(self._box.Text)
	if self._pending or code == "" then
		return
	end
	self._pending = true
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

function Codes.destroy(self: any)
	self._alive = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self._redeem:destroy()
	self._chips:destroy()
	self._panel:destroy()
end

return Codes
