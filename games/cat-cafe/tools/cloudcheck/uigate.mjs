#!/usr/bin/env node
// UI gate (UI-Engineer, 2026-11-01; Derek picked "Skills and UI gate": "build a cloud check that fails tiny buttons,
// small text and off-screen windows").
//
//   node uigate.mjs [--out dir] [--profile phone] [--scene Quests] [--update-baseline] [--verbose]
//
// Builds the real UI (src/client/UI) in the cloud at three screen sizes, the ones the ui-review skill names:
// desktop 1280 x 720, laptop 1366 x 768 and a phone at 844 x 390 with touch. ui-shim.luau gives world-shim.luau a
// client (PlayerGui, camera, input), working signals on a virtual clock, and Roblox's 2D layout. uigate-scenes.luau
// starts the UI as UIController does with a mid-game player, then opens each window the way the game does.
// After each scene every GuiObject a player would see is read back in screen pixels and checked
// (uigate-checks.mjs):
//   tap      something pressable smaller than 44 px on a phone or 36 px with a mouse, after UIScale
//   text     text that renders under 9 px
//   offscreen  a button, text or scroll list partly past the screen edge or under Roblox's top bar
//   fonts    more than two font families on screen
//   error    a script error or warning while the scene built
// Warnings only (in the report, never a fail): pressables that overlap, and on the phone anything pressable under
// the thumbstick or the jump button.
// A finding already in uigate-baseline.json does not fail; a new one does. --update-baseline writes the current
// findings as the new baseline. The report, a picture of each scene (SVG) and an index.html go to <out> (default
// <system temp>/cat-cafe-uigate), never into the repo.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Lua } from '@luau-rs/luau';
import { buildTree, jsonToLuau } from './rojo-tree.mjs';
import { PROFILES, checkScene, compareBaseline, writeReport } from './uigate-checks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const args = parseArgs(process.argv.slice(2));
const outDir = path.resolve(args.out || path.join(os.tmpdir(), 'cat-cafe-uigate'));
const baselineFile = path.join(here, 'uigate-baseline.json');

const tree = buildTree(path.join(gameRoot, 'default.project.json'));
const worldSource = fs.readFileSync(path.join(here, 'world-shim.luau'), 'utf8');
const uiSource = fs.readFileSync(path.join(here, 'ui-shim.luau'), 'utf8');
const scenesSource = fs.readFileSync(path.join(here, 'uigate-scenes.luau'), 'utf8');

// One fresh Luau state per screen size, so nothing one size left behind leaks into the next.
async function runProfile(profile) {
  const lua = await Lua.create({ sandbox: false, libraries: 'all' });
  lua.gcStop(); // run-tests.mjs: the wasm collector can fault on big states
  lua.globals.set(
    'print',
    lua.createFunction((...parts) => {
      if (args.verbose) console.log(parts.map(String).join(' '));
    }),
  );
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
  const world = lua.load(worldSource, { name: 'world-shim' }).call(tree, hostLoad)[0];
  const ui = lua
    .load(uiSource, { name: 'ui-shim' })
    .call(world, { width: profile.width, height: profile.height, touch: profile.touch, inset: profile.inset })[0];
  // the scenes run with the game's globals (workspace, the virtual os.time), as a LocalScript would
  const env = world.rawGet('internals').rawGet('env');
  const scenes = lua.load(scenesSource, { name: 'uigate-scenes', environment: env }).call(ui)[0];
  const fn = (name) => ui.rawGet(name);
  const run = (f, settle) => fn('run').call(f, settle);
  const takeErrors = () => {
    const raw = String(fn('takeErrors').call()[0]);
    if (raw === '') return [];
    return raw.split('\0\0').map((pair) => {
      const cut = pair.indexOf('\0');
      return { kind: pair.slice(0, cut), text: pair.slice(cut + 1) };
    });
  };
  const snapshot = () =>
    String(fn('snapshot').call()[0])
      .split('\n')
      .filter(Boolean)
      .map((line) => JSON.parse(line));

  const results = [];
  run(scenes.rawGet('setup'), 3);
  run(scenes.rawGet('close'), 0.6); // a window the login opens by itself (a Daily Treat that is due)
  results.push({ scene: 'HUD', nodes: snapshot(), errors: takeErrors() });
  const names = scenes.rawGet('names').toArray().map(String);
  for (const name of names) {
    if (args.scene && args.scene !== name) continue;
    const open = lua.createFunction(() => scenes.rawGet('open').call(name));
    run(open, 1.5);
    results.push({ scene: name, nodes: snapshot(), errors: takeErrors() });
    run(scenes.rawGet('close'), 0.6);
    takeErrors();
  }
  return results;
}

const started = Date.now();
const all = [];
for (const profile of PROFILES) {
  if (args.profile && args.profile !== profile.name) continue;
  const t0 = Date.now();
  const scenes = await runProfile(profile);
  // The HUD stays on screen behind every window: a finding is listed once, in the first scene that shows it.
  const seen = new Set();
  for (const scene of scenes) {
    const findings = checkScene(profile, scene).filter((f) => {
      if (f.check === 'error' || f.check === 'warning') return true;
      const key = `${f.check}|${f.path}|${f.message}`;
      if (seen.has(key) && scene.scene !== 'HUD') return false;
      seen.add(key);
      return true;
    });
    all.push({ profile, scene: scene.scene, nodes: scene.nodes, errors: scene.errors, findings });
  }
  const nodes = scenes.reduce((n, s) => n + s.nodes.length, 0);
  console.log(
    `${profile.name} ${profile.width} x ${profile.height}: ${scenes.length} scenes, ${nodes} pieces, ${((Date.now() - t0) / 1000).toFixed(1)} s`,
  );
}

const baseline = fs.existsSync(baselineFile) ? JSON.parse(fs.readFileSync(baselineFile, 'utf8')) : { findings: {} };
const filtered = Boolean(args.profile || args.scene);
const { fresh, fixed, counts } = compareBaseline(all, baseline);
if (args.updateBaseline) {
  if (filtered) throw new Error('--update-baseline needs the full run (no --profile or --scene)');
  const out = { note: 'UI gate findings accepted on 2026-11-01; fix them and shrink this file, never grow it by hand.', findings: counts };
  fs.writeFileSync(baselineFile, JSON.stringify(out, null, 2) + '\n');
  console.log(`Wrote ${path.relative(process.cwd(), baselineFile)} (${Object.keys(counts).length} keys)`);
}
fs.mkdirSync(path.join(outDir, 'scenes'), { recursive: true });
for (const r of all) {
  // every piece of each scene, for a closer look at a finding
  fs.writeFileSync(path.join(outDir, 'scenes', `${r.profile.name}-${r.scene}.json`), JSON.stringify(r.nodes) + '\n');
}
writeReport(outDir, { results: all, fresh, fixed, seconds: (Date.now() - started) / 1000 });
console.log(`Report: ${path.join(outDir, 'index.html')}`);
if (fixed.length > 0 && !filtered) {
  console.log(`${fixed.length} baseline finding(s) are gone; run with --update-baseline to lock that in.`);
}
if (fresh.length > 0 && !args.updateBaseline) {
  console.log(`\nUI gate: ${fresh.length} new finding(s):`);
  for (const f of fresh.slice(0, 60)) console.log(`  ${f.profile} ${f.scene} ${f.check}: ${f.message}`);
  if (fresh.length > 60) console.log(`  ... and ${fresh.length - 60} more in the report`);
  process.exit(1);
}
console.log('UI gate passed');

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') out.out = argv[++i];
    else if (arg === '--profile') out.profile = argv[++i];
    else if (arg === '--scene') out.scene = argv[++i];
    else if (arg === '--update-baseline') out.updateBaseline = true;
    else if (arg === '--verbose' || arg === '-v') out.verbose = true;
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node uigate.mjs [--out dir] [--profile desktop|laptop|phone] [--scene Name] [--update-baseline] [--verbose]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
