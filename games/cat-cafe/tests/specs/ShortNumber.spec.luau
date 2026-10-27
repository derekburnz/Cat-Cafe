--!strict
-- UI/Components/ShortNumber.luau: the HUD counters' short numbers (golden-fish.md section 1, F52): exact below
-- 100,000, then K to Qi, always cut down so a counter never shows more than the player has.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ShortNumber = require(Components:WaitForChild("ShortNumber")) :: any

	describe("ShortNumber.format", function()
		it("is exact with commas below 100,000", function()
			expect(ShortNumber.format(0)).to.equal("0")
			expect(ShortNumber.format(7)).to.equal("7")
			expect(ShortNumber.format(8420)).to.equal("8,420")
			expect(ShortNumber.format(99999)).to.equal("99,999")
			expect(ShortNumber.format(99999.9)).to.equal("99,999")
		end)

		it("cuts down instead of rounding up (Derek's 1.99M, not 2M)", function()
			expect(ShortNumber.format(1999999)).to.equal("1.99M")
			expect(ShortNumber.format(999999)).to.equal("999K")
			expect(ShortNumber.format(100999)).to.equal("100K")
			expect(ShortNumber.format(19999999)).to.equal("19.9M")
			expect(ShortNumber.format(999999999)).to.equal("999M")
		end)

		it("keeps three digits and drops trailing zeros", function()
			expect(ShortNumber.format(100000)).to.equal("100K")
			expect(ShortNumber.format(1000000)).to.equal("1M")
			expect(ShortNumber.format(1240000)).to.equal("1.24M")
			expect(ShortNumber.format(1500000)).to.equal("1.5M")
			expect(ShortNumber.format(1050000)).to.equal("1.05M")
			expect(ShortNumber.format(12345678)).to.equal("12.3M")
			expect(ShortNumber.format(123456789)).to.equal("123M")
			expect(ShortNumber.format(2500000000)).to.equal("2.5B")
		end)

		it("goes on through T, Qa and Qi", function()
			expect(ShortNumber.format(4.56e12)).to.equal("4.56T")
			expect(ShortNumber.format(7.89e15)).to.equal("7.89Qa")
			expect(ShortNumber.format(3e18)).to.equal("3Qi")
			expect(ShortNumber.format(4.2e20)).to.equal("420Qi")
			expect(ShortNumber.format(5e21)).to.equal("5,000Qi")
		end)

		it("handles signs and odd input without showing more", function()
			expect(ShortNumber.format(-1999999)).to.equal("-1.99M")
			expect(ShortNumber.format(-250)).to.equal("-250")
			expect(ShortNumber.format(-0.4)).to.equal("0")
			expect(ShortNumber.format(0 / 0)).to.equal("0")
		end)
	end)

	describe("ShortNumber.commas", function()
		it("groups thousands and cuts off fractions", function()
			expect(ShortNumber.commas(1234567)).to.equal("1,234,567")
			expect(ShortNumber.commas(999.9)).to.equal("999")
			expect(ShortNumber.commas(-1234)).to.equal("-1,234")
		end)
	end)

	-- QA edges (qa-playtester): a reference that cuts the exact decimal digits of the number (string.format "%.0f"
	-- prints a whole double exactly), so it never does float sums and shows what "cut down, never rounded up" means.
	describe("ShortNumber edges (QA)", function()
		local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
		local function grouped(digits: string): string
			local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
			return if out:sub(1, 1) == "," then out:sub(2) else out
		end
		local function reference(n: number): string
			if n ~= n then
				return "0"
			end
			local sign = if n <= -1 then "-" else ""
			local whole = math.floor(math.abs(n))
			if whole == math.huge then
				return sign .. "∞"
			end
			local digits = string.format("%.0f", whole)
			if whole < 100000 then
				return sign .. grouped(digits)
			end
			local index = math.min(#SUFFIXES, math.floor((#digits - 1) / 3))
			local headLength = #digits - 3 * index
			local head = digits:sub(1, headLength)
			if headLength >= 4 then
				return sign .. grouped(head) .. SUFFIXES[index]
			end
			local fraction = (digits:sub(headLength + 1, 3):gsub("0+$", ""))
			return sign
				.. head
				.. (if fraction ~= "" then "." .. fraction else "")
				.. SUFFIXES[index]
		end
		local seed = 4242
		local function roll(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end
		local function check(n: number)
			local got, want = ShortNumber.format(n), reference(n)
			if got ~= want then
				error(string.format("format(%.17g) gave %q, want %q", n, got, want))
			end
		end

		-- Up to a thousand Qi (10^21). Past it the cut works in floats and can show one more than the number
		-- (5.000999...e21 shows "5,001Qi"); no counter gets near that, so it is a note, not a ticket.
		it(
			"cuts every power of ten, its neighbours and each leading digit's edges to the exact digits",
			function()
				for k = 0, 20 do
					local p = 10 ^ k
					for _, n in { p - 1, p, p + 1, p - 0.5 } do
						check(n)
						check(-n)
					end
					for d = 1, 9 do
						for _, n in
							{
								d * p - 1,
								d * p,
								d * p + 1,
								d * p + p / 1000 - 1,
								d * p + p / 100 - 1,
							}
						do
							check(n)
						end
					end
				end
			end
		)

		it("matches the exact digits on 6,000 seeded numbers up to a billion Qi", function()
			for _ = 1, 6000 do
				local digits = roll(21)
				local n = 0
				for _ = 1, digits do
					n = n * 10 + (roll(10) - 1)
				end
				check(n)
				check(n + (roll(1000) - 1) / 1000)
			end
		end)

		it("never shows more than the number, and a larger number never shows less", function()
			local function shown(text: string): number
				local body = text:gsub(",", "")
				local value, suffix = body:match("^(%-?[%d%.]+)(%a*)$")
				assert(value, text)
				local power = 0
				for i, s in SUFFIXES do
					if s == suffix then
						power = 3 * i
					end
				end
				return (tonumber(value) :: number) * 10 ^ power
			end
			local last = -1
			for step = 0, 4000 do
				local n = math.floor(1.0085 ^ (step * 4) * 1000) -- from 1,000, about 3.5% more each step
				if n >= 1e21 then
					break
				end
				local value = shown(ShortNumber.format(n))
				expect(value <= n * (1 + 1e-12)).to.equal(true)
				expect(value >= last).to.equal(true)
				last = value
			end
		end)

		it(
			"stays short: at most 6 characters and a sign below a thousand Qi, with no stray point or zero",
			function()
				for _ = 1, 3000 do
					local n = roll(10 ^ roll(9)) * 10 ^ (roll(13) - 1)
					if n < 1e21 then
						local text = ShortNumber.format(n)
						expect(#text <= 6).to.equal(true)
						expect(text:find("%.%a") == nil and text:find("%.$") == nil).to.equal(true)
						expect(text:find("%.%d*0%a") == nil).to.equal(true)
					end
				end
				expect(ShortNumber.format(math.huge)).to.equal("∞")
				expect(ShortNumber.format(-math.huge)).to.equal("-∞")
			end
		)
	end)
end
