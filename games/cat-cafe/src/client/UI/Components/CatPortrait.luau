--!strict
-- A live 3D cat for reveal cards and the book: the cat's own model, cloned from ReplicatedStorage.Assets (the
-- asset thread's mesh, or the server's placeholder until it lands), in a ViewportFrame that sways it slowly.
-- When the model is not there yet it falls back to the cat's initial on its body colour. A silhouette (the
-- book's cats not found yet, like the Pet Simulator index) tints the whole view near black and hides the initial.
--
-- Roblox terms: a ViewportFrame draws 3D parts inside 2D UI through its own Camera. Nothing in it is simulated,
-- so the clone needs no anchoring, but scripts inside a model would still run under PlayerGui, so they are
-- stripped from the clone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Create = require(script.Parent.Create)
local Outline = require(script.Parent.Outline)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Parent.Types)

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

export type Props = {
	parent: Instance,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	still: boolean?, -- no sway: a book cell holds the three-quarter pose, so a page of cells costs no frames
}

export type CatPortrait = {
	frame: Frame,
	set: (self: CatPortrait, def: Types.CatDef?) -> (),
	setSilhouette: (self: CatPortrait, on: boolean) -> (),
	hasModel: (self: CatPortrait) -> boolean,
	destroy: (self: CatPortrait) -> (),
}

local FOV = 30
local THREE_QUARTER = 35 -- degrees turned from face-on, so the body shows behind the head
local SWAY_DEGREES = 20 -- each side of the three-quarter view
local SWAY_SECONDS = 4
local SILHOUETTE = Color3.fromRGB(38, 30, 26) -- multiplies the render: every part goes this dark brown

local CatPortrait = {}
CatPortrait.__index = CatPortrait

local function bodyColor(def: Types.CatDef): Color3
	local rgb = def.color
	if rgb and #rgb >= 3 then
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	return Theme.rarityColor(def.rarity)
end

-- A copy of the cat's model with every script removed, or nil when Assets has no model for it yet.
local function cloneModel(catId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = if assets then assets:FindFirstChild(Catalog.catModelName(catId)) else nil
	if not source then
		return nil
	end
	local copy = (source :: Instance):Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	if copy:IsA("Model") then
		return copy :: Model
	end
	local wrapper = Instance.new("Model")
	copy.Parent = wrapper
	return wrapper
end

function CatPortrait.new(props: Props): CatPortrait
	local self = setmetatable({}, CatPortrait) :: any
	local zIndex = props.zIndex or 1

	local frame: Frame = Create("Frame", {
		Name = "CatPortrait",
		BackgroundTransparency = 1,
		AnchorPoint = props.anchorPoint or Vector2.new(),
		Position = props.position or UDim2.new(),
		Size = props.size,
		ZIndex = zIndex,
		Parent = props.parent,
	})
	self.frame = frame

	local camera: Camera = Create("Camera", { FieldOfView = FOV })
	local viewport: ViewportFrame = Create("ViewportFrame", {
		Name = "View",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 180, 170),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = zIndex,
		Parent = frame,
	})
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	self._viewport = viewport
	self._camera = camera

	local glyph: TextLabel = Create("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.fonts.display,
		TextScaled = true,
		TextColor3 = Theme.colors.white,
		Text = "",
		Visible = false,
		ZIndex = zIndex,
		Parent = frame,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0.22, 0),
			PaddingBottom = UDim.new(0.22, 0),
		}),
	})
	Outline.text(glyph, Theme.sizes.textOutline + 1)
	self._glyph = glyph
	self._still = props.still == true
	self._silhouette = false
	self._def = nil :: Types.CatDef?
	self._model = nil :: Model?
	self._sway = nil :: RBXScriptConnection?
	return self :: CatPortrait
end

function CatPortrait._clear(self: any)
	local sway: RBXScriptConnection? = self._sway
	if sway then
		sway:Disconnect()
		self._sway = nil
	end
	local model: Model? = self._model
	if model then
		model:Destroy()
		self._model = nil
	end
end

function CatPortrait._paintGlyph(self: any)
	local def: Types.CatDef? = self._def
	if not def then
		return
	end
	assert(def, "cat def")
	self._glyph.Text = if self._silhouette then "?" else def.name:sub(1, 1)
	self._glyph.TextColor3 = if self._silhouette
		then Theme.colors.muted
		else bodyColor(def):Lerp(Theme.colors.white, 0.35)
end

function CatPortrait.set(self: any, def: Types.CatDef?)
	self:_clear()
	self._def = def
	if not def then
		self._glyph.Visible = false
		return
	end
	assert(def, "cat def")
	local model = cloneModel(def.id)
	if not model then
		self:_paintGlyph()
		self._glyph.Visible = true
		return
	end
	assert(model, "model")
	self._glyph.Visible = false

	-- Stand the cat at the origin facing the camera (models face -Z, the Roblox front), then frame its box.
	model:PivotTo(CFrame.new())
	local boxCFrame, boxSize = model:GetBoundingBox()
	local centre = boxCFrame.Position
	local radius = boxSize.Magnitude / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
	self._camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, radius * 0.35, -distance), centre)
	model.Parent = self._viewport
	self._model = model

	-- a slow sway round a three-quarter view, only while the portrait is on screen
	local base = CFrame.new(centre)
		* CFrame.Angles(0, math.rad(THREE_QUARTER), 0)
		* CFrame.new(-centre)
	model:PivotTo(base)
	if self._still then
		return
	end
	local started = os.clock()
	self._sway = RunService.Heartbeat:Connect(function()
		if not self.frame.Visible or not self.frame:IsDescendantOf(game) then
			return
		end
		local angle = math.sin((os.clock() - started) * math.pi * 2 / SWAY_SECONDS) * SWAY_DEGREES
		model:PivotTo(
			CFrame.new(centre) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(-centre) * base
		)
	end)
end

function CatPortrait.setSilhouette(self: any, on: boolean)
	self._silhouette = on
	self._viewport.ImageColor3 = if on then SILHOUETTE else Theme.colors.white
	self:_paintGlyph()
end

-- False while Assets had no model for the cat (the initial shows); the book retries on its next render.
function CatPortrait.hasModel(self: any): boolean
	return self._model ~= nil
end

function CatPortrait.destroy(self: any)
	self:_clear()
	self.frame:Destroy()
end

return CatPortrait
