--!strict
-- One ScreenGui that hosts every modal screen (Upgrades, Decor, Collection). Only one is open at a time.
-- Only a screen's own X (or its key) closes it: the dim backdrop takes taps without closing, so a tap on an empty
-- part of a window or beside it never shuts it (Derek 2026-10-27). Screens register a frame plus optional
-- onOpen/onClose callbacks.
-- Opening plays uiOpen and closing uiClose, so the buttons that only open or close a screen stay silent.

local Create = require(script.Parent.Create)
local Scale = require(script.Parent.Parent.Scale)
local Signal = require(script.Parent.Signal)
local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Tween)

export type Screen = {
	frame: GuiObject,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

export type Modal = {
	screenGui: ScreenGui,
	container: Frame,
	changed: Signal.Signal, -- fires (name: string?)
	register: (self: Modal, name: string, screen: Screen) -> (),
	open: (self: Modal, name: string) -> (),
	close: (self: Modal) -> (),
	toggle: (self: Modal, name: string) -> (),
	current: (self: Modal) -> string?,
	destroy: (self: Modal) -> (),
}

local Modal = {}
Modal.__index = Modal

function Modal.new(parent: Instance): Modal
	local screenGui: ScreenGui = Create("ScreenGui", {
		Name = "CatCafeModals",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	})

	-- Active, so a tap on it stops here instead of reaching the world under the window
	local backdrop: Frame = Create("Frame", {
		Name = "Backdrop",
		Active = true,
		BackgroundColor3 = Theme.modal.backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})

	-- Scaled root: screens are built in design pixels inside this.
	local root: Frame = Create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	local uiScale = Scale.bind(root)

	-- Container keeps every screen inside 92% x 86% of the (scaled) viewport.
	local container: Frame = Create("Frame", {
		Name = "Container",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.86),
		Parent = root,
	})

	local self = setmetatable({}, Modal) :: any
	self.screenGui = screenGui
	self.container = container
	self.changed = Signal.new()
	self._backdrop = backdrop
	self._root = root
	self._uiScale = uiScale
	self._screens = {} :: { [string]: Screen }
	self._current = nil :: string?
	self._closing = false

	if parent then
		screenGui.Parent = parent
	end
	return self :: Modal
end

function Modal.register(self: any, name: string, screen: Screen)
	self._screens[name] = screen
	screen.frame.Visible = false
	screen.frame.Parent = self.container
end

function Modal.current(self: any): string?
	return self._current
end

function Modal.open(self: any, name: string)
	local screen: Screen? = self._screens[name]
	if not screen then
		warn(("[CatCafeUI] no modal screen named %q"):format(name))
		return
	end
	assert(screen, "modal screen missing")
	if self._current == name then
		return
	end
	if self._current then
		local previous: Screen = self._screens[self._current]
		previous.frame.Visible = false
		if previous.onClose then
			previous.onClose()
		end
	end
	self._closing = false
	self._current = name
	self.screenGui.Enabled = true
	Tween.to(
		self._backdrop,
		Tween.FAST,
		{ BackgroundTransparency = Theme.modal.backdropTransparency }
	)
	screen.frame.Visible = true
	-- the night dealer's stall has its own bell (sound list 5.8)
	Sound.play(if name == "Dealer" then "uiDealerOpen" else "uiOpen")
	Tween.popIn(screen.frame)
	if screen.onOpen then
		screen.onOpen()
	end
	self.changed:Fire(name)
end

function Modal.close(self: any)
	local name = self._current
	if not name or self._closing then
		return
	end
	local screen: Screen = self._screens[name]
	self._closing = true
	self._current = nil
	Sound.play("uiClose")
	Tween.to(self._backdrop, Tween.FAST, { BackgroundTransparency = 1 })
	Tween.popOut(screen.frame, function()
		if self._closing then
			screen.frame.Visible = false
			self.screenGui.Enabled = false
			self._closing = false
		end
	end)
	if screen.onClose then
		screen.onClose()
	end
	self.changed:Fire(nil)
end

function Modal.toggle(self: any, name: string)
	if self._current == name then
		self:close()
	else
		self:open(name)
	end
end

function Modal.destroy(self: any)
	Scale.unbind(self._uiScale)
	self.changed:DisconnectAll()
	self.screenGui:Destroy()
end

return Modal
