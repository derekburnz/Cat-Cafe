--!strict
-- shared/OwnerTest (#1770, owner test mode): only Derek2's user id is an owner, and nothing a product grants can be
-- traded, so a grant with no Robux can never reach another player.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local OwnerTest = require(Shared.OwnerTest)
	local Remotes = require(Shared.Remotes)

	describe("OwnerTest", function()
		it(
			"lists only Derek2's user id (the account named 2573351 is user id 140223517)",
			function()
				expect(#Config.OwnerTestUserIds).to.equal(1)
				expect(Config.OwnerTestUserIds[1]).to.equal(140223517)
				expect(OwnerTest.isOwner(140223517)).to.equal(true)
				-- user id 2573351 is a different player
				expect(OwnerTest.isOwner(2573351)).to.equal(false)
				expect(OwnerTest.isOwner(0)).to.equal(false)
				expect(OwnerTest.isOwner("140223517")).to.equal(false)
				expect(OwnerTest.isOwner(nil)).to.equal(false)
			end
		)

		it("grants nothing tradeable: every product's cats are exclusive", function()
			for _, product in Catalog.products do
				local loose = OwnerTest.tradeableIn(product)
				if #loose > 0 then
					error(
						string.format(
							"%s holds tradeable %s",
							product.id,
							table.concat(loose, ", ")
						)
					)
				end
			end
		end)

		it("reads the /event command on any chat path (#2754)", function()
			expect(OwnerTest.isEventCommand("/event")).to.equal(true)
			expect(OwnerTest.isEventCommand("/event full 5")).to.equal(true)
			expect(OwnerTest.isEventCommand("/EVENT stop")).to.equal(true)
			expect(OwnerTest.isEventCommand("/events")).to.equal(false)
			expect(OwnerTest.isEventCommand("hello qa")).to.equal(false)
			expect(OwnerTest.isEventCommand(" /event")).to.equal(false)
			expect(OwnerTest.isEventCommand(nil)).to.equal(false)
		end)

		it(
			"reads /event 10 as the full party for ten minutes, and keeps the presets (#3212)",
			function()
				local ask = OwnerTest.eventAsk("/event 10")
				expect(ask.stop).to.equal(false)
				expect(ask.preset).to.equal("full")
				expect(ask.minutes).to.equal(10)
				ask = OwnerTest.eventAsk("/EVENT Money 45")
				expect(ask.preset).to.equal("money")
				expect(ask.minutes).to.equal(45)
				ask = OwnerTest.eventAsk("/event luck")
				expect(ask.preset).to.equal("luck")
				expect(ask.minutes).to.equal(OwnerTest.EVENT_MINUTES)
				ask = OwnerTest.eventAsk("/event   stop")
				expect(ask.stop).to.equal(true)
				expect(ask.preset).to.equal("stop")
				-- a bare /event names no preset, so the reply lists them
				ask = OwnerTest.eventAsk("/event")
				expect(ask.stop).to.equal(false)
				expect(ask.preset).to.equal("")
				-- "nan" is no number of minutes
				ask = OwnerTest.eventAsk("/event nan")
				expect(ask.preset).to.equal("nan")
				expect(ask.minutes).to.equal(OwnerTest.EVENT_MINUTES)
			end
		)

		it(
			"reads a /shout line: quotes off, one line, at most SHOUT_MAX characters (#3212)",
			function()
				expect(OwnerTest.isShoutCommand("/shout hi")).to.equal(true)
				expect(OwnerTest.isShoutCommand("/SHOUT hi")).to.equal(true)
				expect(OwnerTest.isShoutCommand("/shouting")).to.equal(false)
				expect(OwnerTest.isShoutCommand(nil)).to.equal(false)
				expect(OwnerTest.isCommand("/shout hi")).to.equal(true)
				expect(OwnerTest.isCommand("/event 10")).to.equal(true)
				expect(OwnerTest.isCommand("hello")).to.equal(false)

				expect(OwnerTest.shoutText('/shout "Party in 5 minutes!"')).to.equal(
					"Party in 5 minutes!"
				)
				expect(OwnerTest.shoutText("/shout   Party  now ")).to.equal("Party now")
				expect(OwnerTest.shoutText("/shout 'hi all'")).to.equal("hi all")
				expect(
					OwnerTest.shoutText("/shout " .. utf8.char(0x201C) .. "hi" .. utf8.char(0x201D))
				).to.equal("hi")
				expect(OwnerTest.shoutText('/shout say "hi" to Mochi')).to.equal(
					'say "hi" to Mochi'
				)
				expect(OwnerTest.shoutText("/shout line one\nline two")).to.equal(
					"line one line two"
				)
				expect(OwnerTest.shoutText("/shout")).to.equal(nil)
				expect(OwnerTest.shoutText('/shout ""')).to.equal(nil)
				expect(OwnerTest.shoutText("/shout    ")).to.equal(nil)
				expect(OwnerTest.shoutText("/event 10")).to.equal(nil)

				local long = OwnerTest.shoutText("/shout " .. string.rep("é", 300))
				expect(utf8.len(assert(long))).to.equal(OwnerTest.SHOUT_MAX)
			end
		)

		it("lets one shout through every SHOUT_GAP_SECONDS (#3212)", function()
			expect(OwnerTest.shoutReady(nil, 100)).to.equal(true)
			expect(OwnerTest.shoutReady(100, 100 + OwnerTest.SHOUT_GAP_SECONDS - 1)).to.equal(false)
			expect(OwnerTest.shoutReady(100, 100 + OwnerTest.SHOUT_GAP_SECONDS)).to.equal(true)
		end)

		it("reads only a well-formed message from another server (#3212)", function()
			local kind, text =
				OwnerTest.parseMessage(OwnerTest.shoutMessage("hi all", "job-a"), "job-b")
			expect(kind).to.equal("shout")
			expect(text).to.equal("hi all")
			-- this server's own message: it already showed the shout
			expect((OwnerTest.parseMessage(OwnerTest.shoutMessage("hi all", "job-a"), "job-a"))).to.equal(
				nil
			)
			kind, text = OwnerTest.parseMessage(OwnerTest.eventMessage("job-a"), "job-b")
			expect(kind).to.equal("event")
			expect(text).to.equal(nil)
			expect((OwnerTest.parseMessage(nil, "job-b"))).to.equal(nil)
			expect((OwnerTest.parseMessage("shout", "job-b"))).to.equal(nil)
			expect((OwnerTest.parseMessage({ k = "shout", t = "hi" }, "job-b"))).to.equal(nil)
			expect((OwnerTest.parseMessage({ k = "shout", t = 5, j = "job-a" }, "job-b"))).to.equal(
				nil
			)
			expect((OwnerTest.parseMessage({ k = "shout", t = "", j = "job-a" }, "job-b"))).to.equal(
				nil
			)
			expect((OwnerTest.parseMessage({ k = "other", t = "hi", j = "job-a" }, "job-b"))).to.equal(
				nil
			)
			local long = string.rep("a", OwnerTest.SHOUT_MAX + 1)
			expect((OwnerTest.parseMessage({ k = "shout", t = long, j = "job-a" }, "job-b"))).to.equal(
				nil
			)
		end)

		it("answers a line two chat paths both deliver only once (#2754)", function()
			local last = { userId = 1, text = "/event full 5", at = 10 }
			expect(OwnerTest.isRepeat(nil, 1, "/event full 5", 10, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 1, "/event full 5", 10.5, 1)).to.equal(true)
			expect(OwnerTest.isRepeat(last, 1, "/event full 5", 11.2, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 1, "/event stop", 10.5, 1)).to.equal(false)
			expect(OwnerTest.isRepeat(last, 2, "/event full 5", 10.5, 1)).to.equal(false)
		end)

		it("has the OwnerGrant remote and an owner_test_ sku apart from sales", function()
			expect(table.find(Remotes.ClientToServer, "OwnerGrant")).to.be.ok()
			expect(OwnerTest.SKU_PREFIX).to.equal("owner_test_")
			expect(OwnerTest.ATTRIBUTE).to.equal("OwnerTest")
			expect(OwnerTest.LABEL).to.equal("Owner test mode")
		end)
	end)
end
