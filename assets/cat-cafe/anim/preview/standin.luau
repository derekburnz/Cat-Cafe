--!nocheck
-- The stand-in player for the preview tools (avatar.luau): the blocky R15 shape (Roblox's own Block body, about 5
-- studs tall) in the palette's shirt and skin swatches. In the game the poses go on each player's own avatar. It is built from plain tables with the few instance members Avatar.bind reads (Name,
-- IsA, FindFirstChild, GetDescendants, Part0, Part1, C0, C1, Size): Roblox hands out one value per instance, which
-- Avatar keys tables by, while Lune makes a new value on every read.
--
--   local Standin = require("standin")(roblox, Avatar)
--   local c = Standin.character("Player", Standin.SHIRT.red, Standin.SKIN.light)
--   local frames = Standin.place(c, rootCFrame, transforms) -- every part's world CFrame

return function(roblox, Avatar)
	local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3

	local function node(className, name, props)
		local n = props or {}
		n.ClassName, n.Name, n.children = className, name, {}
		function n:IsA(class)
			return class == className or class == "Instance" or (class == "BasePart" and className == "Part")
		end
		function n:FindFirstChild(childName)
			for _, child in self.children do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end
		function n:GetDescendants()
			local out = {}
			local function walk(at)
				for _, child in at.children do
					table.insert(out, child)
					walk(child)
				end
			end
			walk(self)
			return out
		end
		return n
	end
	local function parent(child, to)
		table.insert(to.children, child)
	end

	local function hex(s)
		return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
	end
	local SKIN = { light = hex("F3C9A2"), tan = hex("C98E6A") }
	local SHIRT = { red = hex("D9483B"), blue = hex("3C7DD9") }
	local PANTS = hex("2F3E5C") -- pants_navy
	local SHOES = hex("5E4634") -- dark_wood
	local EYE = hex("2B211A")

	-- A blocky R15 standing with its feet at y = 0, facing -Z: parts, then the Motor6Ds named and placed the way a
	-- Roblox R15 character has them (each joint in the child part, C0 and C1 axis-aligned).
	local function character(name, shirt, skin)
		local model = node("Model", name)
		local function part(partName, size, centre, colour)
			local p = node("Part", partName, { Size = size, CFrame = CFrame.new(centre), Color = colour })
			parent(p, model)
			return p
		end
		local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), SKIN.light)
		local parts = {
			LowerTorso = part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0), PANTS),
			UpperTorso = part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0), shirt),
			Head = part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), skin),
		}
		for side, x in { Left = -1.5, Right = 1.5 } do
			parts[side .. "UpperArm"] = part(side .. "UpperArm", Vector3.new(1, 1, 1), Vector3.new(x, 3.5, 0), shirt)
			parts[side .. "LowerArm"] = part(side .. "LowerArm", Vector3.new(1, 0.75, 1), Vector3.new(x, 2.625, 0), skin)
			parts[side .. "Hand"] = part(side .. "Hand", Vector3.new(1, 0.3, 1), Vector3.new(x, 2.1, 0), skin)
			local lx = x / 3
			parts[side .. "UpperLeg"] = part(side .. "UpperLeg", Vector3.new(1, 0.9, 1), Vector3.new(lx, 1.55, 0), PANTS)
			parts[side .. "LowerLeg"] = part(side .. "LowerLeg", Vector3.new(1, 0.8, 1), Vector3.new(lx, 0.7, 0), PANTS)
			parts[side .. "Foot"] = part(side .. "Foot", Vector3.new(1, 0.3, 1.1), Vector3.new(lx, 0.15, -0.05), SHOES)
		end
		local function joint(jointName, part0, part1, at)
			parent(
				node("Motor6D", jointName, {
					Part0 = part0,
					Part1 = part1,
					C0 = CFrame.new(at - part0.CFrame.Position),
					C1 = CFrame.new(at - part1.CFrame.Position),
				}),
				part1
			)
		end
		joint("Root", root, parts.LowerTorso, Vector3.new(0, 2.2, 0))
		joint("Waist", parts.LowerTorso, parts.UpperTorso, Vector3.new(0, 2.4, 0))
		joint("Neck", parts.UpperTorso, parts.Head, Vector3.new(0, 4.0, 0))
		for side, x in { Left = -1.5, Right = 1.5 } do
			local lx = x / 3
			joint(side .. "Shoulder", parts.UpperTorso, parts[side .. "UpperArm"], Vector3.new(x, 3.75, 0))
			joint(side .. "Elbow", parts[side .. "UpperArm"], parts[side .. "LowerArm"], Vector3.new(x, 3.0, 0))
			joint(side .. "Wrist", parts[side .. "LowerArm"], parts[side .. "Hand"], Vector3.new(x, 2.25, 0))
			joint(side .. "Hip", parts.LowerTorso, parts[side .. "UpperLeg"], Vector3.new(lx, 2.0, 0))
			joint(side .. "Knee", parts[side .. "UpperLeg"], parts[side .. "LowerLeg"], Vector3.new(lx, 1.1, 0))
			joint(side .. "Ankle", parts[side .. "LowerLeg"], parts[side .. "Foot"], Vector3.new(lx, 0.3, 0))
		end
		-- a face, so the front shows: two eyes riding the head
		local eyes = {}
		for _, x in { -0.28, 0.28 } do
			local e = part("Eye", Vector3.new(0.16, 0.3, 0.05), Vector3.new(x, 4.68, -0.61), EYE)
			table.insert(eyes, { part = e, offset = parts.Head.CFrame:Inverse() * e.CFrame })
		end
		local rig = Avatar.bind(model)
		assert(rig, "Avatar.bind found no R15 rig")
		return { model = model, rig = rig, parts = parts, head = parts.Head, eyes = eyes }
	end

	-- Every part's world CFrame for this root and these Transforms (Avatar.lowest's walk, kept).
	local function place(c, rootCF, transforms)
		local at = { [c.rig.root] = CFrame.identity }
		local out = {}
		for _, link in c.rig.links do
			local frame = at[link.parent] * link.c0 * (transforms[link.motor] or CFrame.identity) * link.c1
			at[link.part] = frame
			out[link.part] = rootCF * frame
		end
		for _, eye in c.eyes do
			out[eye.part] = out[c.head] * eye.offset
		end
		return out
	end

	-- render.py's entry for each of a character's visible parts, in the order `parts` lists them.
	local function partInfo(c, prefix)
		local info, order = {}, {}
		for _, d in c.model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				table.insert(order, d)
				local colour = d.Color
				table.insert(info, {
					name = prefix .. "_" .. d.Name,
					shape = "Block",
					color = { colour.R, colour.G, colour.B },
					material = "SmoothPlastic",
					transparency = 0,
				})
			end
		end
		return info, order
	end

	return {
		SKIN = SKIN,
		SHIRT = SHIRT,
		character = character,
		place = place,
		partInfo = partInfo,
	}
end
