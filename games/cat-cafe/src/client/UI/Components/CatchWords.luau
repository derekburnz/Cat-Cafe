--!strict
-- The catch screen's word (F93, catch-rework.md section 3). When the last circle is judged one result word slams in
-- over the progress strip; the circles show no words of their own (Derek 2026-11-03):
--   every circle Perfect           PURRFECT!   (gold, the biggest burst)
--   at least half Perfect          EXCELLENT!  (gold)
--   every circle Good or better    GREAT!      (mint)
--   a Miss, or no circles          So close!   (soft grey, no burst)
-- The rule is the same as Effects/Logic.catchWord, which picks the burst behind the word, so the two always agree.
--   result(grades, success) -> Result          which result word a finished catch earns
--   finish(finish, grades, success) -> Result  Catch v3 (#1884, catch-rework.md 7d): the server's CatchResult finish
--                                              ("purrfect", "great", "nice" or "bolt") when it sends one, else result()
--   TEXT[result]                               the words themselves
-- Catch v3's finish: PURRFECT! (every tapped ring Perfect, no paw ring tapped; gold), GREAT! (at most one ring not
-- Perfect; mint), NICE! (any other catch; cream), "So close!" on a bolt.
-- Pure, so the cloud spec runner checks it.

local CatchWords = {}

export type Result = "purrfect" | "excellent" | "great" | "nice" | "close"
export type Grade = "perfect" | "good" | "miss" -- shared Types.CircleGrade

CatchWords.TEXT = {
	purrfect = "PURRFECT!",
	excellent = "EXCELLENT!",
	great = "GREAT!",
	nice = "NICE!", -- #1884
	close = "So close!",
} :: { [string]: string }

function CatchWords.result(grades: { Grade }, success: boolean): Result
	local count = #grades
	if not success or count == 0 then
		return "close"
	end
	local perfects = 0
	for _, grade in grades do
		if grade == "perfect" then
			perfects += 1
		elseif grade == "miss" then
			return "close"
		end
	end
	if perfects == count then
		return "purrfect"
	elseif perfects * 2 >= count then
		return "excellent"
	end
	return "great"
end

local FINISHES: { [string]: Result } = {
	purrfect = "purrfect",
	great = "great",
	nice = "nice",
	bolt = "close",
}

function CatchWords.finish(finish: string?, grades: { Grade }, success: boolean): Result
	local word: Result? = if type(finish) == "string" then FINISHES[finish] else nil
	if word ~= nil then
		return word :: Result
	end
	return CatchWords.result(grades, success)
end

return CatchWords
