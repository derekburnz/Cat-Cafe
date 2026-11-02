--!strict
-- Rename a cat (F33, data-model section 4), the Pet Simulator "Rename Pet" box: a card over the cat room with the
-- breed, a text box, a "7/20" counter and Rename / Cancel. The name is checked as the player types with the same
-- rules the server uses (Shared.CatName.validate: 1 to CatNameMaxLength characters after trimming, no control
-- characters, < or >), so Rename only lights up for a name the server would take before its chat filter.
--   open(uid, current?, breed)   current is the cat's name now (nil while it uses the breed name)
--   close()
-- Rename calls onSave(uid, name) with the trimmed name and closes. The server filters it and answers with a toast
-- ("Renamed to X", or why it refused) and a ProfileSync carrying the filtered name.
--
-- Roblox terms: a TextBox is an editable text field; FocusLost(enterPressed) fires when the player leaves it,
-- with enterPressed true for the Enter key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Create = require(script.Parent.Parent.Components.Create)
local Outline = require(script.Parent.Parent.Components.Outline)
local Sound = require(script.Parent.Parent.Components.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Components.Tween)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatName = require(Shared:WaitForChild("CatName"))
local Config = require(Shared:WaitForChild("Config"))

local MAX_LENGTH: number = Config.CatNameMaxLength
local CARD = Vector2.new(380, 236)
local FILTER_NOTE = "Other players see it after the chat filter"

export type RenameDialog = {
	frame: Frame,
	open: (self: RenameDialog, uid: string, current: string?, breed: string) -> (),
	close: (self: RenameDialog) -> (),
	isOpen: (self: RenameDialog) -> boolean,
	editing: (self: RenameDialog) -> string?,
	destroy: (self: RenameDialog) -> (),
}

local RenameDialog = {}
RenameDialog.__index = RenameDialog

function RenameDialog.new(
	parent: GuiObject,
	onSave: (uid: string, name: string) -> ()
): RenameDialog
	local self = setmetatable({}, RenameDialog) :: any
	self._onSave = onSave
	self._uid = nil :: string?
	self._current = nil :: string?
	self._connections = {} :: { RBXScriptConnection }

	-- a dim layer over the cat room that also swallows taps meant for the cards under it
	local frame: Frame = Create("Frame", {
		Name = "Rename",
		Active = true,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 8,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	self.frame = frame

	local card: Frame = Create("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.modal.card,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		ZIndex = 9,
		Parent = frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radius) }) })
	Outline.border(card, Theme.sizes.outline, Theme.colors.caramel)
	self._card = card

	local title: TextLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 28),
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.modal.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Rename Cat",
		ZIndex = 10,
		Parent = card,
	})
	self._title = title

	local box: TextBox = Create("TextBox", {
		Name = "Name",
		BackgroundColor3 = Theme.colors.cream,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 46),
		ClearTextOnFocus = false,
		FontFace = Theme.fonts.display,
		TextSize = Theme.sizes.textLarge,
		TextColor3 = Theme.modal.text,
		PlaceholderColor3 = Theme.modal.subtext,
		PlaceholderText = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 10,
		Parent = card,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, Theme.sizes.radiusSmall) }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})
	self._boxBorder = Outline.border(box, Theme.sizes.stroke, Theme.modal.cardStroke)
	self._box = box

	local counter: TextLabel = Create("TextLabel", {
		Name = "Counter",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 100),
		Size = UDim2.fromOffset(60, 18),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 10,
		Parent = card,
	})
	self._counter = counter
	local note: TextLabel = Create("TextLabel", {
		Name = "Note",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 100),
		Size = UDim2.new(1, -96, 0, 36),
		FontFace = Theme.fonts.body,
		TextSize = Theme.sizes.textSmall,
		TextColor3 = Theme.modal.subtext,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = FILTER_NOTE,
		ZIndex = 10,
		Parent = card,
	})
	self._note = note

	self._save = Button.new({
		name = "Save",
		text = "Rename",
		style = "primary",
		size = UDim2.new(0.5, -22, 0, 48),
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -16, 1, -14),
		parent = card,
		zIndex = 10,
		enabled = false,
		sound = false, -- _submit plays uiRename, for Enter too
		onClick = function()
			self:_submit()
		end,
	})
	self._cancel = Button.new({
		name = "Cancel",
		text = "Cancel",
		style = "ghost",
		size = UDim2.new(0.5, -22, 0, 48),
		anchorPoint = Vector2.new(0, 1),
		position = UDim2.new(0, 16, 1, -14),
		parent = card,
		zIndex = 10,
		onClick = function()
			self:close()
		end,
	})

	table.insert(
		self._connections,
		box:GetPropertyChangedSignal("Text"):Connect(function()
			self:_check()
		end)
	)
	table.insert(
		self._connections,
		box.FocusLost:Connect(function(enterPressed: boolean)
			if enterPressed and frame.Visible then
				self:_submit()
			end
		end)
	)
	return self :: RenameDialog
end

-- The trimmed name when Rename may be pressed (valid and different from the name now), else nil.
function RenameDialog._check(self: any): string?
	local raw: string = self._box.Text
	local name, reason = CatName.validate(raw)
	local length = utf8.len(raw) or 0
	self._counter.Text = ("%d/%d"):format(length, MAX_LENGTH)
	local tooLong = name == nil and length > MAX_LENGTH
	self._counter.TextColor3 = if tooLong then Theme.colors.red else Theme.modal.subtext
	-- an empty box is not an error yet; a name the server would refuse is, in red with its reason
	local blank = (raw:match("^%s*$")) ~= nil
	local bad = name == nil and not blank
	self._note.Text = if bad then reason or FILTER_NOTE else FILTER_NOTE
	self._note.TextColor3 = if bad then Theme.colors.red else Theme.modal.subtext
	self._boxBorder.Color = if bad then Theme.colors.red else Theme.modal.cardStroke
	local ready = name ~= nil and name ~= self._current
	self._save:setEnabled(ready)
	return if ready then name else nil
end

function RenameDialog._submit(self: any)
	local uid: string? = self._uid
	local name = self:_check()
	if uid == nil or name == nil then
		return
	end
	Sound.play("uiRename")
	self._onSave(uid, name)
	self:close()
end

function RenameDialog.open(self: any, uid: string, current: string?, breed: string)
	self._uid = uid
	self._current = if current ~= nil and current ~= "" then current else nil
	-- a name the filter turned to "Mo##i" starts the box empty: # fails the name rules, so it would open in red
	-- (reviewer N96)
	local named: string? = self._current
	local hashed = named ~= nil and string.find(named, "#", 1, true) ~= nil
	self._title.Text = "Rename " .. (if hashed then breed else self._current or breed)
	self._box.PlaceholderText = breed
	self._box.Text = if hashed then "" else self._current or ""
	self:_check()
	self.frame.Visible = true
	Tween.popIn(self._card, 0.9)
	self._box:CaptureFocus()
end

function RenameDialog.close(self: any)
	self._uid = nil
	if self._box:IsFocused() then
		self._box:ReleaseFocus()
	end
	self.frame.Visible = false
end

function RenameDialog.isOpen(self: any): boolean
	return self.frame.Visible
end

-- The uid of the cat being renamed while the box is open.
function RenameDialog.editing(self: any): string?
	return if self.frame.Visible then self._uid else nil
end

function RenameDialog.destroy(self: any)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._save:destroy()
	self._cancel:destroy()
	self.frame:Destroy()
end

return RenameDialog
