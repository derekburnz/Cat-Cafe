--!strict
-- The catch screen's words (F93, catch-rework.md section 3). Each circle pops its grade word the moment it is judged,
-- and when the last one is judged one result word slams in over the progress strip:
--   every circle Perfect           PURRFECT!   (gold, the biggest burst)
--   at least half Perfect          EXCELLENT!  (gold)
--   every circle Good or better    GREAT!      (mint)
--   a Miss, or no circles          So close!   (soft grey, no burst)
-- The rule is the same as Effects/Logic.catchWord, which picks the burst behind the word, so the two always agree.
--   result(grades, success) -> Result          which result word a finished catch earns
--   TEXT[result], GRADE_TEXT[grade]            the words themselves
-- Pure, so the cloud spec runner checks it.

local CatchWords = {}

export type Result = "purrfect" | "excellent" | "great" | "close"
export type Grade = "perfect" | "good" | "miss" -- shared Types.CircleGrade

CatchWords.TEXT = {
	purrfect = "PURRFECT!",
	excellent = "EXCELLENT!",
	great = "GREAT!",
	close = "So close!",
} :: { [string]: string }

CatchWords.GRADE_TEXT = {
	perfect = "PERFECT!",
	good = "GOOD",
	miss = "MISS",
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

return CatchWords
