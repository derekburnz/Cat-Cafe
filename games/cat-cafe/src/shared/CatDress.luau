--!strict
-- A working cat's outfit (features.md F25, data-model section 5; Derek 2026-10-27: outfits by role), shared so the
-- server's working cats (World/CatPose) and the intro's seated waiter (IntroController, F72) dress the same way.
--
-- Outfit pieces go on the seated cat's Outfit_<Piece> Attachments (manifest sit_slots), which ride the Body or the
-- Head, so the asset thread can move a slot without a code change. Each piece's parts get Follows = "Body" or
-- "Head", which the client's idles (Effects/Pose) read. A walking body (F90's walking staff, Effects/CafeWalk) wears
-- a piece's walking cut, CatCafe_Accessory_<Piece>_Walk (Model-Agent #787), where one exists.
--
-- Roblox terms: an Attachment is a named point and rotation inside a part; its WorldCFrame follows the part.

local Catalog = require(script.Parent.Catalog)
local Looks = require(script.Parent.Looks)

local CatDress = {}

local PIECE_ATTRIBUTE = "OutfitPiece" -- on each piece dress puts on: the piece's name ("Apron")
local ACCESSORY_PIECE_ATTRIBUTE = "AccessoryPiece" -- #1624: on the accessory dress puts on, its piece ("Hat")
local BUILT_COLOR_ATTRIBUTE = "BuiltColor" -- on a recoloured part: its colour as built
local UNIFORM_ATTRIBUTE = "UniformStyle" -- on a dressed cat: the Looks uniform it wears, nil for Classic

-- The exporter's object Model whose name ends in _<suffix> ("Head", "Tail"), or nil (placeholder cats have none).
local function objectModel(model: Model, suffix: string): Model?
	local tail = "_" .. suffix
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child.Name:sub(-#tail) == tail then
			return child :: Model
		end
	end
	return nil
end

function CatDress.scaleOf(model: Model): number
	local scale = model:GetAttribute("Scale")
	return if type(scale) == "number" and scale > 0 then scale else 1
end

-- Which of `role`'s pieces a cat with props in `propSlot` and `propSlot2` (the model's PropSlot and PropSlot2) wears,
-- and which of its own props comes off for them (features.md F71, data-model section 5): a piece in a slot either
-- prop takes stays off, except that an Entertainer with a Head and a Back prop wears the party hat in place of its
-- head prop at the station, so its "Prop" (or "Prop2") object comes off. Pure, for the specs.
function CatDress.plan(
	role: string,
	propSlot: string?,
	propSlot2: string?,
	accessorySlot: string?
): ({ string }, string?, boolean)
	local pieces = Catalog.roleOutfits[role]
	if pieces == nil then
		return {}, nil, false
	end
	local taken: { [string]: boolean } = {}
	if propSlot ~= nil then
		taken[propSlot] = true
	end
	if propSlot2 ~= nil then
		taken[propSlot2] = true
	end
	-- #1624 section 6: the cafe's accessory goes on unless the cat's own prop fills its slot; a Head one replaces the
	-- role hat and a Back one the cape, so the role piece in its slot stays off (a Face one clashes with nothing)
	local accessoryOn = accessorySlot ~= nil and not taken[accessorySlot]
	local offProp: string? = nil
	if role == "entertainer" and taken.Head == true and taken.Back == true then
		taken.Head = false
		offProp = if propSlot == "Head" then "Prop" else "Prop2"
	end
	if accessoryOn then
		taken[accessorySlot :: string] = true
	end
	local wear: { string } = {}
	for _, piece in pieces do
		local slot = Catalog.outfitPieceSlots[piece]
		if slot == nil or not taken[slot] then
			table.insert(wear, piece)
		end
	end
	return wear, offProp, accessoryOn
end

-- Whether `model` is a walking body (A) rather than a seated one (B) or a standing worker (S): a seated body carries
-- Pose "sit" (CafeService and the intro set it on the _Sit clones they dress) or still has its asset's _Sit name, a
-- worker Pose "work" or its _Work name; S has B's chest, so it wears the seated cuts. A working cat whose seat is not
-- exported yet sits on its walking body, so it gets the walking cut too, which is the one its slots fit.
function CatDress.isWalking(model: Instance): boolean
	local pose = model:GetAttribute("Pose")
	return pose ~= "sit"
		and pose ~= "work"
		and string.find(model.Name, "_Sit", 1, true) == nil
		and string.find(model.Name, "_Work", 1, true) == nil
end

-- The standing worker at work (Model-Agent #826; Derek picked S on 2026-11-02): each role's front legs turn in their
-- own axes by the manifest's cat_poses.work_<role> angles_roblox_deg (degrees about X, Y and Z, applied as
-- CFrame.Angles), and copy new numbers from there when Model-Agent poses them again. The client's Effects add small
-- idles on top, so a far cat, which gets none, still shows the pose. Copied from the manifest generated 2026-11-02
-- 13:20 UTC (its "generated" field): a newer export means checking these against it (review N330). The entertainer's
-- are from the 20:33 UTC export (Model-Agent #901, Derek's pick A): the mic held up under the chin in the right paw,
-- the left paw down at its side.
CatDress.WORK_ARMS = {
	barista = { LegF2 = { 57.5, 21.5, 13.1 }, LegF1 = { 9.9, -1.0, -5.9 } },
	waiter = { LegF1 = { 37.5, -27.0, -30.7 }, LegF2 = { 9.9, 1.0, 5.9 } },
	greeter = { LegF1 = { 172.4, 13.0, -59.1 }, LegF2 = { 9.9, 1.0, 5.9 } },
	entertainer = { LegF2 = { 18, 84, 30 }, LegF1 = { 9.9, -1.0, -5.9 } },
} :: { [string]: { [string]: { number } } }

-- What each worker carries in its paws, an object Model named <asset>_Held_<Role>: the barista's cup and the
-- entertainer's microphone in LegF2, the waiter's tray in LegF1. Every worker model has all three; a greeter holds
-- none.
CatDress.HELD = { "Held_Barista", "Held_Waiter", "Held_Entertainer" }
CatDress.WORK_HELD = {
	barista = "Held_Barista",
	waiter = "Held_Waiter",
	entertainer = "Held_Entertainer",
} :: { [string]: string }

-- The held things that come off a worker in `role`: every one but its own.
function CatDress.heldOff(role: string): { string }
	local keep = CatDress.WORK_HELD[role]
	local off: { string } = {}
	for _, held in CatDress.HELD do
		if held ~= keep then
			table.insert(off, held)
		end
	end
	return off
end

-- Poses a worker for `role`: the other roles' held things come off and each front leg turns about its own pivot
-- (WORK_ARMS), which carries what it holds, so this works before or after the model is pivoted to its station and at
-- any Scale. A model without the legs (a placeholder) is left as it is.
function CatDress.workPose(model: Model, role: string)
	for _, held in CatDress.heldOff(role) do
		local tail = "_" .. held
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Model") and descendant.Name:sub(-#tail) == tail then
				descendant:Destroy()
			end
		end
	end
	local arms = CatDress.WORK_ARMS[role]
	if arms == nil then
		return
	end
	for legName, angles in arms do
		local leg = objectModel(model, legName)
		if leg ~= nil then
			local turn =
				CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
			leg:PivotTo(leg:GetPivot() * turn)
		end
	end
end

-- The assets to try for `piece`, in order: on a walking body its walking cut and then the plain piece (the cut is
-- missing for the pieces whose walking slot sits where the seated one does), on a seated body or a worker its seated
-- cut (#1624: the Tiny Lantern hangs on an upright back, CatCafe_Accessory_TinyLantern_Sit) and then the plain piece.
function CatDress.assetNames(piece: string, walking: boolean): { string }
	local plain = Catalog.accessoryModelName(piece)
	return if walking then { plain .. "_Walk", plain } else { plain .. "_Sit", plain }
end

-- Takes one of the cat's own props off: its object Models (a Head prop's nest in the Head) and their _Glass twins.
local function takeOff(model: Model, prop: string)
	local tails = { "_" .. prop, "_" .. prop .. "_Glass" }
	for _, descendant in model:GetDescendants() do
		if not descendant:IsDescendantOf(model) then
			continue -- inside a prop already taken off
		end
		for _, tail in tails do
			if descendant.Name:sub(-#tail) == tail then
				descendant:Destroy()
				break
			end
		end
	end
end

-- One piece on `model` at its Outfit_<piece> slot, a copy from `clone` (its walking or seated cut first), scaled to
-- the cat and tagged `attribute` = piece. False while the slot or every asset for it is missing.
local function putOn(
	model: Model,
	piece: string,
	clone: (assetName: string) -> Model?,
	attribute: string
): boolean
	local slot = model:FindFirstChild("Outfit_" .. piece, true)
	if slot == nil or not slot:IsA("Attachment") then
		return false
	end
	local worn: Model? = nil
	for _, name in CatDress.assetNames(piece, CatDress.isWalking(model)) do
		worn = clone(name)
		if worn ~= nil then
			break
		end
	end
	if worn == nil then
		return false
	end
	local scale = CatDress.scaleOf(model)
	if scale ~= 1 then
		worn:ScaleTo(scale)
	end
	worn:PivotTo((slot :: Attachment).WorldCFrame)
	local head = objectModel(model, "Head")
	local follows = if head ~= nil and slot:IsDescendantOf(head) then "Head" else "Body"
	for _, descendant in worn:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part:SetAttribute("Follows", follows)
		end
	end
	worn:SetAttribute(attribute, piece) -- recolour and accessory swaps find the pieces by it
	worn.Parent = model
	return true
end

-- The model's PropSlot and PropSlot2, and the Looks accessory `accessoryId` while the cat has its Outfit_<piece>
-- slot (nil for none, an unknown id, or a cat whose body is not exported with the slot yet, which keeps its role hat).
local function slotsOf(model: Model, accessoryId: string?): (string?, string?, Looks.Accessory?)
	local propSlot = model:GetAttribute("PropSlot")
	local propSlot2 = model:GetAttribute("PropSlot2")
	local accessory = if accessoryId ~= nil then Looks.accessory(accessoryId) else nil
	if accessory ~= nil then
		local slot = model:FindFirstChild("Outfit_" .. accessory.piece, true)
		if slot == nil or not slot:IsA("Attachment") then
			accessory = nil
		end
	end
	return if type(propSlot) == "string" then propSlot else nil,
		if type(propSlot2) == "string" then propSlot2 else nil,
		accessory
end

-- Puts `role`'s outfit on a cat (CatDress.plan), each piece a copy from `clone(assetName)` (nil while that asset is
-- missing), its walking cut on a walking body (CatDress.assetNames). A piece is skipped while its assets or the cat's
-- Outfit_<Piece> slot are missing, so new pieces and new cats can land in either order. A worker (Pose "work") is
-- posed for the role first (workPose). #1624: `accessoryId`, the cafe's Looks accessory, goes on too where the plan
-- lets it, in place of the role piece in its slot; the cat's Accessory attribute names it. Returns how many pieces
-- went on.
function CatDress.dress(
	model: Model,
	role: string,
	clone: (assetName: string) -> Model?,
	accessoryId: string?
): number
	if model:GetAttribute("Pose") == "work" then
		CatDress.workPose(model, role)
	end
	local propSlot, propSlot2, accessory = slotsOf(model, accessoryId)
	local pieces, offProp, accessoryOn =
		CatDress.plan(role, propSlot, propSlot2, if accessory ~= nil then accessory.slot else nil)
	if offProp ~= nil then
		takeOff(model, offProp)
	end
	local worn = 0
	for _, piece in pieces do
		if putOn(model, piece, clone, PIECE_ATTRIBUTE) then
			worn += 1
		end
	end
	if
		accessory ~= nil
		and accessoryOn
		and putOn(model, accessory.piece, clone, ACCESSORY_PIECE_ATTRIBUTE)
	then
		worn += 1
	end
	model:SetAttribute(Looks.ACCESSORY_ATTRIBUTE, if accessory ~= nil then accessory.id else nil)
	return worn
end

-- #1624: swaps a dressed cat's accessory for `accessoryId` (nil: none) in place, so a pick on the Style tab shows on
-- the cats already at work. The old accessory comes off, a role piece it replaced goes back on, and one the new one
-- replaces comes off (CatDress.plan). Nothing happens while the cat already wears it. A newly put on role piece is in
-- its built colours, so the cat's uniform is cleared for CatDress.wearUniform to paint again.
function CatDress.setAccessory(
	model: Model,
	role: string,
	accessoryId: string?,
	clone: (assetName: string) -> Model?
)
	local propSlot, propSlot2, accessory = slotsOf(model, accessoryId)
	local id = if accessory ~= nil then accessory.id else nil
	if model:GetAttribute(Looks.ACCESSORY_ATTRIBUTE) == id then
		return
	end
	local pieces, _, accessoryOn =
		CatDress.plan(role, propSlot, propSlot2, if accessory ~= nil then accessory.slot else nil)
	local wanted: { [string]: boolean } = {}
	for _, piece in pieces do
		wanted[piece] = true
	end
	local have: { [string]: boolean } = {}
	for _, child in model:GetChildren() do
		local piece = child:GetAttribute(PIECE_ATTRIBUTE)
		if child:GetAttribute(ACCESSORY_PIECE_ATTRIBUTE) ~= nil then
			child:Destroy()
		elseif type(piece) == "string" then
			if wanted[piece] then
				have[piece] = true
			else
				child:Destroy()
			end
		end
	end
	local added = false
	for _, piece in pieces do
		if not have[piece] and putOn(model, piece, clone, PIECE_ATTRIBUTE) then
			added = true
		end
	end
	if accessory ~= nil and accessoryOn then
		putOn(model, accessory.piece, clone, ACCESSORY_PIECE_ATTRIBUTE)
	end
	model:SetAttribute(Looks.ACCESSORY_ATTRIBUTE, id)
	if added then
		model:SetAttribute(UNIFORM_ATTRIBUTE, nil)
	end
end

-- #1624 (store-pass-looks.md section 2): a uniform style recolours the role pieces with no new meshes. In each piece
-- the colour that covers the most surface becomes the style's `main`, the next one its `trim`, and any others (a
-- cocoa band, a gold star) stay as built. Pure, for the specs: `areas` maps each colour (any key) to its surface,
-- and the answer maps the main and trim keys to "main" and "trim". Ties go to the smaller key, so it never flickers.
function CatDress.uniformSlots(areas: { [string]: number }): { [string]: string }
	local keys: { string } = {}
	for key in areas do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: string, b: string): boolean
		if areas[a] ~= areas[b] then
			return areas[a] > areas[b]
		end
		return a < b
	end)
	local slots: { [string]: string } = {}
	if keys[1] ~= nil then
		slots[keys[1]] = "main"
	end
	if keys[2] ~= nil then
		slots[keys[2]] = "trim"
	end
	return slots
end

-- A part's colour as built, kept the first time a uniform recolours it so Classic can put it back.
local function builtColor(part: BasePart): Color3
	local kept = part:GetAttribute(BUILT_COLOR_ATTRIBUTE)
	if typeof(kept) == "Color3" then
		return kept :: Color3
	end
	part:SetAttribute(BUILT_COLOR_ATTRIBUTE, part.Color)
	return part.Color
end

-- Recolours every outfit piece `model` wears (the ones CatDress.dress put on) in the Looks uniform `uniformId`'s main
-- and trim colours, or back to their built colours for nil or an unknown id (Classic). The model's UniformStyle
-- attribute names the style it wears, so a second call with the same one does nothing. The server calls it on the
-- working cats with the plot's UniformStyle; a client copy of a cat (CafeWalk's walkers) can call it the same way.
function CatDress.wearUniform(model: Model, uniformId: string?)
	local uniform = if uniformId ~= nil then Looks.uniform(uniformId) else nil
	local id = if uniform ~= nil then uniform.id else nil
	if model:GetAttribute(UNIFORM_ATTRIBUTE) == id then
		return
	end
	local main = if uniform ~= nil
		then Color3.fromRGB(uniform.main[1], uniform.main[2], uniform.main[3])
		else nil
	local trim = if uniform ~= nil
		then Color3.fromRGB(uniform.trim[1], uniform.trim[2], uniform.trim[3])
		else nil
	model:SetAttribute(UNIFORM_ATTRIBUTE, id)
	for _, child in model:GetChildren() do
		if not child:IsA("Model") or child:GetAttribute(PIECE_ATTRIBUTE) == nil then
			continue
		end
		local parts: { BasePart } = {}
		local areas: { [string]: number } = {}
		for _, descendant in child:GetDescendants() do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				table.insert(parts, part)
				local size = part.Size
				local key = builtColor(part):ToHex()
				areas[key] = (areas[key] or 0) + size.X * size.Y + size.Y * size.Z + size.X * size.Z
			end
		end
		local slots = if uniform ~= nil then CatDress.uniformSlots(areas) else {}
		for _, part in parts do
			local built = builtColor(part)
			local slot = slots[built:ToHex()]
			part.Color = if slot == "main" and main ~= nil
				then main
				elseif slot == "trim" and trim ~= nil then trim
				else built
		end
	end
end

return CatDress
