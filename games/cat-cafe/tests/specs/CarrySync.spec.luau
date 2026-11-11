--!strict
-- CarrySync.luau (#3145): when the screen's carry state must be set again to the server's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CarrySync = require(Shared.CarrySync)

	local function view(catId: string?, banner: boolean, built: boolean?): CarrySync.View
		return { built = built ~= false, catId = catId, banner = banner }
	end

	describe("CarrySync.stale", function()
		it("is quiet while the screen agrees with the server", function()
			expect(CarrySync.stale(nil, nil, view(nil, false))).to.equal(false)
			expect(CarrySync.stale("bengal", "bengal", view("bengal", true))).to.equal(false)
		end)

		it("asks for a change of cat, a pick up and a put down", function()
			expect(CarrySync.stale("bengal", nil, view(nil, false))).to.equal(true)
			expect(CarrySync.stale(nil, "bengal", view("bengal", true))).to.equal(true)
			expect(CarrySync.stale("tabby", "bengal", view("bengal", true))).to.equal(true)
		end)

		it(
			"takes down a banner left up for a cat the server no longer has (Derek2's screenshot)",
			function()
				-- the last value applied was nil, yet the banner is up and the UI still names the cat
				expect(CarrySync.stale(nil, nil, view("bengal", true))).to.equal(true)
				expect(CarrySync.stale(nil, nil, view(nil, true))).to.equal(true)
				-- the UI's state names a cat with no banner (a sync that stopped part way): G would still send Drop
				expect(CarrySync.stale(nil, nil, view("bengal", false))).to.equal(true)
			end
		)

		it("puts back a banner that never came up, or names the wrong cat", function()
			expect(CarrySync.stale("bengal", "bengal", view("bengal", false))).to.equal(true)
			expect(CarrySync.stale("bengal", "bengal", view("tabby", true))).to.equal(true)
			expect(CarrySync.stale("bengal", "bengal", view(nil, true))).to.equal(true)
		end)

		it("waits for the HUD before comparing the banner", function()
			expect(CarrySync.stale("bengal", "bengal", view("bengal", false, false))).to.equal(
				false
			)
			expect(CarrySync.stale(nil, nil, view(nil, false, false))).to.equal(false)
			-- a new value is still handed over before the HUD exists (UI.setCarrying keeps it in its state)
			expect(CarrySync.stale("bengal", nil, view(nil, false, false))).to.equal(true)
		end)
	end)

	-- UIController in small: `latest` is noted as each sync arrives, `apply` hands a value to the screen.
	describe("a Drop of a Backpack cat: two syncs in one frame", function()
		local function screen()
			local ui = { catId = nil :: string?, banner = false }
			local applied: string? = nil
			local latest: string? = nil
			local function refresh()
				local now: CarrySync.View = { built = true, catId = ui.catId, banner = ui.banner }
				if CarrySync.stale(latest, applied, now) then
					applied = latest
					ui.catId, ui.banner = latest, latest ~= nil
				end
			end
			return ui, function(value: string?)
				latest = value
			end, refresh
		end

		it("ends with no banner when the syncs apply in order", function()
			local ui, arrive, refresh = screen()
			arrive("bengal")
			refresh()
			expect(ui.banner).to.equal(true)
			arrive(nil)
			refresh()
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)

		it("ends with no banner when the first sync finishes applying after the second", function()
			local ui, arrive, refresh = screen()
			arrive("bengal") -- the first sync arrives and is held up before it reaches the banner
			arrive(nil) -- the second arrives and applies in full
			refresh()
			refresh() -- the first resumes: it reads the newest value, not its own
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)

		it("takes a stuck banner down on the next look, with no new sync", function()
			local ui, arrive, refresh = screen()
			arrive(nil)
			ui.catId, ui.banner = "bengal", true -- left behind, whatever the cause
			refresh()
			expect(ui.banner).to.equal(false)
			expect(ui.catId).to.equal(nil)
		end)
	end)

	-- shared/HeldCat.held (#3165): whether the cat in a carrier's arms is still welded to the character as it is now.
	local HeldCat = require(Shared.HeldCat) :: any

	-- The cloud runner has no Instance.new, so these stand in for the few things `held` reads: Name, Parent,
	-- FindFirstChild (also through children), IsA, and a Weld's Part0 and Part1.
	local function fake(class: string, name: string, parent: any?): any
		local self: any = { ClassName = class, Name = name, Parent = nil, children = {} }
		function self.IsA(_: any, asked: string): boolean
			return asked == class or (asked == "BasePart" and class == "Part")
		end
		function self.FindFirstChild(_: any, wanted: string, deep: boolean?): any
			for _, child in self.children do
				if child.Name == wanted then
					return child
				end
			end
			if deep then
				for _, child in self.children do
					local found = child:FindFirstChild(wanted, true)
					if found ~= nil then
						return found
					end
				end
			end
			return nil
		end
		function self.setParent(to: any?)
			local old = self.Parent
			if old ~= nil then
				table.remove(old.children, table.find(old.children, self))
			end
			self.Parent = to
			if to ~= nil then
				table.insert(to.children, self)
			end
		end
		self.setParent(parent)
		return self
	end

	local function part(name: string, parent: any?): any
		return fake("Part", name, parent)
	end

	-- a character with a root and, when asked, an R15 torso
	local function character(withTorso: boolean): (any, any, any)
		local model = fake("Model", "Character", nil)
		local root = part("HumanoidRootPart", model)
		local torso = if withTorso then part("UpperTorso", model) else nil
		return model, root, torso
	end

	-- a one-part cat, its body welded to `holder` when there is one
	local function cat(holder: any?, parent: any?): any
		local model = fake("Model", "HeldCat", parent)
		local body = part("Body", model)
		if holder ~= nil then
			local weld = fake("Weld", "HoldWeld", body)
			weld.Part0 = holder
			weld.Part1 = body
		end
		return model
	end

	describe("HeldCat.held (#3165)", function()
		it("is true for a cat welded to the character's torso", function()
			local who, root, torso = character(true)
			expect(HeldCat.held(cat(torso, who), who, root)).to.equal(true)
		end)

		it("is false with no model, a model outside the character, or no weld", function()
			local who, root, torso = character(true)
			expect(HeldCat.held(nil, who, root)).to.equal(false)
			expect(HeldCat.held(cat(torso, nil), who, root)).to.equal(false)
			expect(HeldCat.held(cat(nil, who), who, root)).to.equal(false)
		end)

		it("is false once the avatar's appearance rebuilt the torso", function()
			local who, root, torso = character(true)
			local held = cat(torso, who)
			expect(HeldCat.held(held, who, root)).to.equal(true)
			torso.setParent(nil) -- the old torso goes
			part("UpperTorso", who) -- and a new one arrives
			expect(HeldCat.held(held, who, root)).to.equal(false)
		end)

		it("holds on the root only while there is no torso", function()
			local who, root = character(false)
			local held = cat(root, who)
			expect(HeldCat.held(held, who, root)).to.equal(true)
			part("UpperTorso", who) -- the torso arrives: the cat belongs on it now
			expect(HeldCat.held(held, who, root)).to.equal(false)
		end)
	end)
end
