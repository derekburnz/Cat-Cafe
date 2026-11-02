// Lists the gap between the unit tests and the QA test plan (docs/playtests/test-plan.md, owned by qa-playtester):
// every tests/specs/<Name>.spec.luau should be named in the plan as `<Name>.spec`, and every `<Name>.spec` the plan
// names should exist. Report only: it never fails `npm run check`, since the threads that add specs cannot write
// the plan. QA runs it after a merge and adds the rows.
//
//   node plan-coverage.mjs           the specs the plan never names, and the names the plan keeps for specs now gone
//   node plan-coverage.mjs --rows    the same, plus a draft 3.1 row for each unnamed spec from its header comment
//   node plan-coverage.mjs --strict  exit 1 when anything is listed (for QA's own use, not CI)
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const gameRoot = join(here, "..", "..");
const specsDir = join(gameRoot, "tests", "specs");
const planPath = join(gameRoot, "..", "..", "docs", "playtests", "test-plan.md");

const args = new Set(process.argv.slice(2));
const plan = readFileSync(planPath, "utf8");

const specs = readdirSync(specsDir)
	.filter((file) => file.endsWith(".spec.luau"))
	.map((file) => file.slice(0, -".luau".length))
	.sort();
const named = new Set([...plan.matchAll(/`([A-Za-z0-9]+\.spec)`/g)].map((match) => match[1]));

// Specs the plan still names on purpose, as the ones a newer spec replaced.
const RETIRED = new Set(["ShoveTarget.spec", "SlotLabelState.spec"]);

const unnamed = specs.filter((spec) => !named.has(spec));
const gone = [...named].filter((spec) => !specs.includes(spec) && !RETIRED.has(spec)).sort();

// The spec's opening comment, after any --!strict line, as one line of text.
function header(spec) {
	const lines = readFileSync(join(specsDir, `${spec}.luau`), "utf8").split("\n");
	const words = [];
	for (const line of lines) {
		const text = line.trim();
		if (text.startsWith("--!")) continue;
		if (!text.startsWith("--")) break;
		words.push(text.replace(/^--\s?/, ""));
	}
	return words.join(" ").replace(/\|/g, "/").trim();
}

// Feature ids and design docs the header names, for the Source column.
function sources(text) {
	const found = [];
	for (const match of text.matchAll(/\bF\d{2,3}\b|[a-z0-9-]+\.md/g)) {
		if (!found.includes(match[0])) found.push(match[0]);
	}
	return found.join(", ");
}

console.log(`Test plan coverage: ${specs.length} spec files, ${specs.length - unnamed.length} named in the plan`);
if (unnamed.length > 0) {
	console.log(`\nNot named in docs/playtests/test-plan.md (${unnamed.length}):`);
	for (const spec of unnamed) console.log(`  ${spec}`);
}
if (gone.length > 0) {
	console.log(`\nNamed in the plan with no file in tests/specs (${gone.length}):`);
	for (const spec of gone) console.log(`  ${spec}`);
}
if (args.has("--rows") && unnamed.length > 0) {
	console.log("\nDraft 3.1 rows (from each spec's header comment; check them before pasting):\n");
	for (const spec of unnamed) {
		const text = header(spec) || "(no header comment)";
		console.log(`| \`${spec}\` | ${text} | ${sources(text)} |`);
	}
}
if (args.has("--strict") && (unnamed.length > 0 || gone.length > 0)) {
	process.exitCode = 1;
}
