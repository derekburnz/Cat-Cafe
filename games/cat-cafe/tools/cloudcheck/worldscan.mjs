#!/usr/bin/env node
// World scan (QA, 2026-11-01; Derek 2026-10-30: "lots of models are not connected to each other and are floating
// or have gaps especially around the cafe", "sometimes models with unfortunate placement clip into each other").
//
//   node worldscan.mjs [--out dir] [--tier 1..5] [--assets] [--verbose]
//
// Runs the real WorldBuilder.build() in the cloud on world-shim.luau, a small Roblox with geometry, with every
// model from assets/cat-cafe/rbx/ loaded as ReplicatedStorage.Assets the way Rojo syncs it. Then it reads back every
// part and checks the geometry (worldscan-checks.mjs):
//   floating  a visible group of parts that touches nothing that leads down to the ground
//   gap       two visible solid parts whose faces stand 0.05 to 0.6 studs apart with open space between (light shows through)
//   clipping  a visible part of one placed model sunk into a visible part of another model
// With --assets it also checks every asset model on its own, at its pivot, for floating pieces and gaps inside it.
// The report goes to <out>/world-scan.md (default out: <system temp>/cat-cafe-worldscan) with a CSV per check,
// positions in world studs. world-parts.tsv beside it lists every part for a closer look.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Lua } from '@luau-rs/luau';
import { buildTree, jsonToLuau } from './rojo-tree.mjs';
import { parseParts, scanWorld, scanAsset, writeReport } from './worldscan-checks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const args = parseArgs(process.argv.slice(2));
// Outside the repo by default, so a scan never ends up in a commit.
const outDir = path.resolve(args.out || path.join(os.tmpdir(), 'cat-cafe-worldscan'));

const tree = buildTree(path.join(gameRoot, 'default.project.json'));
const lua = await Lua.create({ sandbox: false, libraries: 'all' });
lua.gcStop();
lua.globals.set('print', lua.createFunction((...parts) => console.log(parts.map(String).join(' '))));

const hostLoad = lua.createFunction((kind, key, env) => {
  const file = String(key);
  if (String(kind) === 'asset') {
    return lua.load(jsonToLuau(fs.readFileSync(file, 'utf8')), { name: path.basename(file) });
  }
  let source = fs.readFileSync(file, 'utf8');
  if (file.endsWith('.json')) source = jsonToLuau(source);
  const chunkName = path.relative(gameRoot, file).split(path.sep).join('/');
  return lua.load(source, { name: chunkName, environment: env });
});

const started = Date.now();
const shimSource = fs.readFileSync(path.join(here, 'world-shim.luau'), 'utf8');
const shim = lua.load(shimSource, { name: 'world-shim' }).call(tree, hostLoad)[0];
shim.rawSet('verbose', Boolean(args.verbose));
console.log(`Loaded ${shim.rawGet('assetsLoaded')} asset models in ${((Date.now() - started) / 1000).toFixed(1)} s`);

const call = (name, ...rest) => shim.rawGet(name).call(...rest);
const builder = call('require', call('find', 'ServerScriptService.Server.World.WorldBuilder')[0])[0];
const world = builder.rawGet('build').call()[0];

// Each cafe dressed at a tier (default 5, the most dressing), every patio expansion open, as an owner sees it.
const tier = Number(args.tier || 5);
const plots = world.rawGet('plots').toArray();
for (const plot of plots) {
  builder.rawGet('setDressing').call(plot, tier);
  builder.rawGet('setBackDoorOpen').call(plot, true);
  for (const expansion of plot.rawGet('expansions').toArray()) builder.rawGet('setExpansionOpen').call(expansion, true);
}
const worldFolder = world.rawGet('folder');
const dump = String(call('dumpParts', worldFolder)[0]);
const parts = parseParts(dump);
console.log(`Built the world: ${parts.length} parts (${((Date.now() - started) / 1000).toFixed(1)} s)`);

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'world-parts.tsv'), dump + '\n');
const findings = scanWorld(parts);

let assetFindings = null;
if (args.assets) {
  assetFindings = [];
  const assets = call('find', 'ReplicatedStorage.Assets')[0];
  const names = call('assetNames')[0].toArray().map(String);
  // The area sets are laid out on the area's code-built floor, so on their own every piece looks loose; the world
  // sections already check them in place.
  const own = names.filter((n) => !/_Set(V\d+)?$/.test(n));
  for (const name of own) {
    const model = assets.get(name);
    const assetParts = parseParts(String(call('dumpParts', model)[0]));
    assetFindings.push(...scanAsset(name, assetParts));
  }
  console.log(`Checked ${own.length} asset models on their own (area sets are checked in place)`);
}

writeReport(outDir, { parts, findings, assetFindings, tier, seconds: (Date.now() - started) / 1000 });
console.log(`Report: ${path.join(outDir, 'world-scan.md')}`);

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') out.out = argv[++i];
    else if (arg === '--tier') out.tier = argv[++i];
    else if (arg === '--assets') out.assets = true;
    else if (arg === '--verbose' || arg === '-v') out.verbose = true;
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node worldscan.mjs [--out dir] [--tier 1..5] [--assets] [--verbose]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
