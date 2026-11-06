--!strict
-- Jukebox.luau (#1168 row 2, free since #1875): the four cafe songs every player has, the pick SetJukeboxTrack may
-- save, and saves made whole.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Jukebox = require(Shared.Jukebox)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("Jukebox", function()
		it("lists four songs, each with its own id and client cue", function()
			expect(#Jukebox.TRACKS).to.equal(4)
			local seen = {}
			for _, track in Jukebox.TRACKS do
				expect(seen[track.id]).to.equal(nil)
				seen[track.id] = true
				expect(track.cue:match("^musicJukebox")).to.be.ok()
				expect(Jukebox.get(track.id)).to.equal(track)
			end
		end)

		it("gives every player all four songs, with no pass (#1875)", function()
			local ids = Jukebox.owned()
			expect(#ids).to.equal(4)
			for i, track in Jukebox.TRACKS do
				expect(ids[i]).to.equal(track.id)
			end
		end)

		it("lets SetJukeboxTrack save the rotation or any known song, and nothing else", function()
			for _, plain in { nil :: any, "", Jukebox.DEFAULT } do
				local ok, pick = Jukebox.pickFor(plain)
				expect(ok).to.equal(true)
				expect(pick).to.equal(nil)
			end
			for _, track in Jukebox.TRACKS do
				local ok, pick = Jukebox.pickFor(track.id)
				expect(ok).to.equal(true)
				expect(pick).to.equal(track.id)
				expect(Jukebox.shown(track.id)).to.equal(track.id)
			end
			expect(Jukebox.pickFor("nope")).to.equal(false)
			expect(Jukebox.pickFor(5)).to.equal(false)
			expect(Jukebox.pickFor({})).to.equal(false)
			expect(Jukebox.shown("nope")).to.equal(nil)
			expect(Jukebox.shown(nil)).to.equal(nil)
		end)

		it("keeps the pass id in Config so earlier buyers see no errors", function()
			expect(type((Config :: any).JukeboxPassId)).to.equal("number")
		end)

		it("keeps a known pick through a save, and drops anything else", function()
			local raw = ProfileSchema.template(1000) :: any
			raw.jukebox = Jukebox.TRACKS[2].id
			expect((ProfileSchema.migrate(raw, 1000) :: any).jukebox).to.equal(Jukebox.TRACKS[2].id)
			raw.jukebox = "nope"
			expect((ProfileSchema.migrate(raw, 1000) :: any).jukebox).to.equal(nil)
			expect(ProfileSchema.template(1000).jukebox).to.equal(nil)
		end)
	end)
end
