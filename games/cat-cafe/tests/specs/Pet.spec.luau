--!strict
-- shared/Pet.luau and Economy's happy cat pay (#3651): one happy cat a player, its own pay doubled for an hour by
-- the clock, online pay only, never above EventMoneyMax with the event money slot.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local LiveFlags = require(Shared.LiveFlags)
	local Pet = require(Shared.Pet)
	local ProfileSchema = require(Shared.ProfileSchema)

	local T = 1000

	-- A new save at T with its working cat's uid, and a second cat with no job.
	local function cafe(): (any, string)
		local profile: any = ProfileSchema.template(T)
		profile.lastTick = T
		local worker: string? = nil
		for uid, cat in profile.cats do
			if cat.spotId ~= nil then
				worker = uid
			end
		end
		assert(worker ~= nil, "the template has a working cat")
		local resting = table.clone(profile.cats[worker])
		resting.uid = "rest-1"
		resting.spotId = nil
		profile.cats["rest-1"] = resting
		return profile, worker :: string
	end

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	describe("Pet's numbers", function()
		it("are Derek's: 2x for an hour, behind a switch that is off", function()
			expect(Config.PetMoneyBoost).to.equal(2)
			expect(Config.PetSeconds).to.equal(3600)
			expect(Config.PetCooldownSeconds).to.equal(3)
			expect(Pet.FLAG).to.equal("petCats")
			expect(LiveFlags.defaults()[Pet.FLAG]).to.equal(false)
		end)
	end)

	describe("Pet.pet", function()
		it("makes one happy cat for a fresh hour and moves the heart to a new one", function()
			local profile, worker = cafe()
			local second = table.clone(profile.cats[worker])
			second.uid = "work-2"
			profile.cats["work-2"] = second
			local how, from = Pet.pet(profile, worker, T)
			expect(how).to.equal("first")
			expect(from).to.equal(nil)
			expect(profile.pet.uid).to.equal(worker)
			expect(profile.pet.untilAt).to.equal(T + 3600)
			expect(Pet.active(profile.pet, profile.cats, T + 3599)).to.equal(worker)
			expect(Pet.active(profile.pet, profile.cats, T + 3600)).to.equal(nil)
			-- the same cat again: a fresh hour
			how, from = Pet.pet(profile, worker, T + 600)
			expect(how).to.equal("same")
			expect(from).to.equal(nil)
			expect(profile.pet.untilAt).to.equal(T + 600 + 3600)
			-- another cat: the heart moves, the first has none
			how, from = Pet.pet(profile, "work-2", T + 700)
			expect(how).to.equal("moved")
			expect(from).to.equal(worker)
			expect(profile.pet.uid).to.equal("work-2")
			expect(Pet.active(profile.pet, profile.cats, T + 800)).to.equal("work-2")
		end)

		it("is only for one of your cats on a job", function()
			local profile, worker = cafe()
			expect(Pet.blocker(profile.cats, worker)).to.equal(nil)
			expect(Pet.blocker(profile.cats, "rest-1")).to.be.ok()
			expect(Pet.blocker(profile.cats, "nobody")).to.be.ok()
		end)
	end)

	describe("Pet.prune", function()
		it("ends the heart with the hour, a sale or the cat leaving its job", function()
			local profile, worker = cafe()
			Pet.pet(profile, worker, T)
			expect(Pet.prune(profile, T + 10)).to.equal(false)
			expect(Pet.prune(profile, T + 3600)).to.equal(true)
			expect(profile.pet).to.equal(nil)
			Pet.pet(profile, worker, T)
			profile.cats[worker].spotId = nil
			expect(Pet.prune(profile, T + 10)).to.equal(true)
			Pet.pet(profile, worker, T)
			profile.cats[worker] = nil
			expect(Pet.prune(profile, T + 10)).to.equal(true)
			expect(Pet.prune(profile, T + 10)).to.equal(false)
		end)
	end)

	describe("Pet.sanitize", function()
		it("keeps a heart still ahead, no longer than one pet, and drops anything else", function()
			local kept = Pet.sanitize({ uid = "abc-1", untilAt = T + 100.7 }, T) :: any
			expect(kept.uid).to.equal("abc-1")
			expect(kept.untilAt).to.equal(T + 100)
			expect((Pet.sanitize({ uid = "abc-1", untilAt = T + 99999 }, T) :: any).untilAt).to.equal(
				T + 3600
			)
			expect(Pet.sanitize({ uid = "abc-1", untilAt = T }, T)).to.equal(nil)
			expect(Pet.sanitize({ uid = "", untilAt = T + 5 }, T)).to.equal(nil)
			expect(Pet.sanitize({ uid = 5, untilAt = T + 5 }, T)).to.equal(nil)
			expect(Pet.sanitize({ uid = "abc-1", untilAt = 0 / 0 }, T)).to.equal(nil)
			expect(Pet.sanitize("x", T)).to.equal(nil)
			expect(Pet.sanitize(nil, T)).to.equal(nil)
		end)

		it("comes through a save and its migration", function()
			local profile, worker = cafe()
			Pet.pet(profile, worker, T)
			local loaded: any = ProfileSchema.migrate(profile, T + 60)
			expect(loaded.pet.uid).to.equal(worker)
			expect(loaded.pet.untilAt).to.equal(T + 3600)
			expect((ProfileSchema.migrate(profile, T + 4000) :: any).pet).to.equal(nil)
			expect((ProfileSchema.template(T) :: any).pet).to.equal(nil)
		end)
	end)

	describe("Pet.gain", function()
		it("doubles the cat alone and never passes the event money cap with the slot", function()
			expect(Pet.gain(1)).to.equal(1) -- 2x in all
			expect(Pet.gain(1.5)).to.equal(0.5) -- 2x in all
			expect(Pet.gain(2)).to.equal(0) -- a 2x party or the rest: nothing on top
			expect(Pet.gain(0)).to.equal(1)
			for _, money in { 1, 1.25, 1.5, 2 } do
				expect(money + Pet.gain(money) <= Config.EventMoneyMax).to.equal(true)
			end
		end)
	end)

	describe("Pet.seconds, label and shown", function()
		it("counts only the part of a window the heart ran", function()
			local save = { uid = "a", untilAt = T + 100 }
			expect(Pet.seconds(save, T, 60)).to.equal(60)
			expect(Pet.seconds(save, T + 70, 60)).to.equal(30)
			expect(Pet.seconds(save, T + 100, 60)).to.equal(0)
			expect(Pet.seconds(nil, T, 60)).to.equal(0)
			expect(Pet.seconds(save, T, 0)).to.equal(0)
		end)

		it("reads the time left in whole minutes, and the tag's doubled number", function()
			expect(Pet.label(T + 3600, T)).to.equal("Happy for 1 h")
			expect(Pet.label(T + 42 * 60, T)).to.equal("Happy for 42 m")
			expect(Pet.label(T + 5, T)).to.equal("Happy for 1 m")
			expect(Pet.label(T, T)).to.equal(nil)
			expect(Pet.label(nil, T)).to.equal(nil)
			local rate, happy = Pet.shown(3, T + 10, T)
			expect(rate).to.equal(6)
			expect(happy).to.equal(true)
			rate, happy = Pet.shown(3, T + 10, T + 10)
			expect(rate).to.equal(3)
			expect(happy).to.equal(false)
			rate, happy = Pet.shown(3, nil, T)
			expect(rate).to.equal(3)
			expect(happy).to.equal(false)
		end)
	end)

	describe("Economy's happy cat pay", function()
		it("pays the happy cat's own pay twice while the switch is on, and nothing more", function()
			local plain, _ = cafe()
			local petted, worker = cafe()
			Pet.pet(petted, worker, T)
			-- the switch off: a saved heart pays nothing
			Economy.setPetOn(false)
			expect(Economy.petRate(petted, T)).to.equal(0)
			Economy.setPetOn(true)
			-- the template's one working cat is the whole income
			expect(near(Economy.petRate(petted, T), Economy.incomePerSecond(petted))).to.equal(true)
			expect(Economy.petRate(plain, T)).to.equal(0)
			local a = Economy.settle(plain, T + 100)
			local b = Economy.settle(petted, T + 100)
			Economy.setPetOn(false)
			expect(a > 0).to.equal(true)
			expect(near(b, 2 * a)).to.equal(true)
			expect(near(petted.coins - plain.coins, a)).to.equal(true)
			-- not the event's doing
			expect(Economy.takeEventExtra(petted)).to.equal(0)
		end)

		it("pays only the share of the window the heart ran, then drops the heart", function()
			local plain, _ = cafe()
			local petted, worker = cafe()
			petted.pet = { uid = worker, untilAt = T + 25 }
			Economy.setPetOn(true)
			local a = Economy.settle(plain, T + 100)
			local b = Economy.settle(petted, T + 100)
			Economy.setPetOn(false)
			expect(near(b, 1.25 * a)).to.equal(true)
			expect(petted.pet).to.equal(nil)
		end)

		it("adds nothing in a 2x party or while resting, and never changes the day rate", function()
			local plain, _ = cafe()
			local petted, worker = cafe()
			Pet.pet(petted, worker, T)
			expect(Economy.incomePerSecond(petted)).to.equal(Economy.incomePerSecond(plain))
			Economy.setPetOn(true)
			Economy.setEventMoney(2)
			local a = Economy.settle(plain, T + 100)
			local b = Economy.settle(petted, T + 100)
			Economy.setEventMoney(1)
			Economy.setResting(petted, true)
			Economy.setResting(plain, true)
			local c = Economy.settle(plain, T + 200)
			local d = Economy.settle(petted, T + 200)
			Economy.setResting(petted, false)
			Economy.setResting(plain, false)
			Economy.setPetOn(false)
			expect(near(a, b)).to.equal(true)
			expect(near(c, d)).to.equal(true)
		end)

		it("gives a cat taken off its job nothing", function()
			local petted, worker = cafe()
			Pet.pet(petted, worker, T)
			petted.cats[worker].spotId = nil
			Economy.setPetOn(true)
			expect(Economy.petRate(petted, T)).to.equal(0)
			Economy.settle(petted, T + 100)
			Economy.setPetOn(false)
			expect(petted.pet).to.equal(nil)
		end)
	end)
end
