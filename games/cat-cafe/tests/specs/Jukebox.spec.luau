--!strict
-- Jukebox.luau (#1168 row 2): the Jukebox Pass's four songs, owned only through the pass, the pick SetJukeboxTrack
-- may save, and saves made whole.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local Jukebox = require(Shared.Jukebox)
	local ProfileSchema = require(Shared.ProfileSchema)

	local none = function(): boolean
		return false
	end
	local all = function(id: number): boolean
		return id ~= 0
	end

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

		it("owns the songs only with a made pass", function()
			expect(#Jukebox.owned(none)).to.equal(0)
			expect(#Jukebox.owned(function(id: number): boolean
				return id == 0
			end)).to.equal(0)
			if (Config :: any).JukeboxPassId ~= 0 then
				expect(#Jukebox.owned(all)).to.equal(4)
			end
		end)

		it("lets SetJukeboxTrack save the rotation always, a song only with the pass", function()
			for _, plain in { nil :: any, "", Jukebox.DEFAULT } do
				local ok, pick = Jukebox.pickFor(plain, none)
				expect(ok).to.equal(true)
				expect(pick).to.equal(nil)
			end
			local id = Jukebox.TRACKS[1].id
			expect(Jukebox.pickFor(id, none)).to.equal(false)
			expect(Jukebox.pickFor("nope", all)).to.equal(false)
			expect(Jukebox.pickFor(5, all)).to.equal(false)
			expect(Jukebox.shown(id, none)).to.equal(nil)
			if (Config :: any).JukeboxPassId ~= 0 then
				local ok, pick = Jukebox.pickFor(id, all)
				expect(ok).to.equal(true)
				expect(pick).to.equal(id)
				expect(Jukebox.shown(id, all)).to.equal(id)
			end
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
