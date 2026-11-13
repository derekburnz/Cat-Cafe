#!/usr/bin/env node
// UI gate (UI-Engineer, 2026-11-01; Derek picked "Skills and UI gate": "build a cloud check that fails tiny buttons,
// small text and off-screen windows").
//
//   node uigate.mjs [--out dir] [--devices] [--tablets] [--profile phone] [--scene Quests] [--update-baseline] [--verbose]
//   node uigate.mjs --shard 2/4 --save dir     (CI: build one quarter of the scenes, write them to dir, check nothing)
//   node uigate.mjs --merge dir                (CI: read every shard back in order and check them as one full run)
//
// Builds the real UI (src/client/UI) in the cloud at three screen sizes, the ones the ui-review skill names:
// desktop 1280 x 720, laptop 1366 x 768 and a phone at 844 x 390 with touch; --devices runs a tablet, a small phone
// and a console instead (DEVICE_PROFILES), which CI leaves out to keep its time. ui-shim.luau gives world-shim.luau a
// client (PlayerGui, camera, input), working signals on a virtual clock, and Roblox's 2D layout. uigate-scenes.luau
// starts the UI as UIController does with a mid-game player, then opens each window the way the game does.
// After each scene every GuiObject a player would see is read back in screen pixels and checked
// (uigate-checks.mjs):
//   tap      something pressable smaller than 44 px on a phone or 36 px with a mouse, after UIScale
//   text     text that renders under 9 px
//   offscreen  a button, text or scroll list partly past the screen edge or under Roblox's top bar
//   fonts    more than two font families on screen
//   jitter   a property that flips between two or three values every few frames once the scene has settled
//            (Derek 2026-10-28: reward rows "spassing back and forth")
//   error    a script error or warning while the scene built
//   tiles    two HUD tiles, both in the left column or the bottom right corner, whose drawn edges (outline, key cap,
//            dot, glow) come closer than their outline (#1210); any other pair is 'tilesnear', a warning
// Warnings only (in the report, never a fail): pressables that overlap, and on the phone anything pressable under
// the thumbstick or the jump button.
// A finding already in uigate-baseline.json does not fail; a new one does. --update-baseline writes the current
// findings as the new baseline. The report, a picture of each scene (SVG) and an index.html go to <out> (default
// <system temp>/cat-cafe-uigate), never into the repo.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Lua } from '@luau-rs/luau';
import { buildTree, jsonToLuau } from './rojo-tree.mjs';
import { DEVICE_PROFILES, PROFILES, TABLET_PROFILES, checkScene, compareBaseline, writeReport } from './uigate-checks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const args = parseArgs(process.argv.slice(2));
const outDir = path.resolve(args.out || path.join(os.tmpdir(), 'cat-cafe-uigate'));
const baselineFile = path.join(here, 'uigate-baseline.json');

const tree = buildTree(path.join(gameRoot, 'default.project.json'));
const worldSource = fs.readFileSync(path.join(here, 'world-shim.luau'), 'utf8');
const uiSource = fs.readFileSync(path.join(here, 'ui-shim.luau'), 'utf8');
const scenesSource = fs.readFileSync(path.join(here, 'uigate-scenes.luau'), 'utf8');

// The state runs with its collector off (run-tests.mjs: the wasm collector can fault mid-run), so every scene's
// garbage stayed until the end; by #1923 (2026-11-06) the desktop run's one state passed the wasm's memory ceiling
// ("not enough memory" in watch(), about 24 minutes in). A full collection between scenes, when no Luau code is
// running, frees it; --mem prints the heap after each scene.
function collect(lua, name) {
  lua.gcRestart();
  lua.gcCollect();
  lua.gcStop();
  if (args.mem) console.error(`uigate mem ${name}: ${(lua.usedMemory / 1048576).toFixed(1)} MB`);
}

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

  // one settled second with every property write recorded: what flips back and forth is jitter
  const watch = () =>
    String(fn('watch').call(1, 6)[0])
      .split('\n')
      .filter(Boolean)
      .map((line) => {
        const [where, prop, changes, distinct] = line.split('\t');
        return { path: where, prop, changes: Number(changes), distinct: Number(distinct) };
      });
  const results = [];
  // --flag a,b: those live switches read true from the start, as on a server that has them on (the UI builds its
  // windows once, at setup)
  for (const flag of (process.env.UIGATE_FLAG || '').split(',').filter((f) => /^[A-Za-z0-9]+$/.test(f))) {
    lua.load(`game:GetService("ReplicatedStorage"):SetAttribute("LiveFlag_${flag}", true)`, { name: 'uigate-flag', environment: env }).call();
  }
  run(scenes.rawGet('setup'), 3);
  run(scenes.rawGet('close'), 0.6); // a window the login opens by itself (a Daily Treat that is due)
  const hudJitter = watch();
  const hud = { scene: 'HUD', nodes: snapshot(), errors: takeErrors(), jitter: hudJitter };
  // --shard k/n: a contiguous slice of the sorted scene list, in its own fresh state after the same setup. Only the
  // first shard keeps the HUD scene, so the merged run reads exactly like one full run (#2304).
  const shard = parseShard(args.shard);
  if (!shard || shard.k === 1) results.push(hud);
  let names = scenes.rawGet('names').toArray().map(String);
  if (shard) {
    const size = Math.ceil(names.length / shard.n);
    names = names.slice((shard.k - 1) * size, shard.k * size);
  }
  for (const name of names) {
    if (args.scene && !args.scene.split(',').includes(name)) continue; // one scene, or several in list order: A,B,C
    // a Lua closure, not a host function: a pcall under a JS callback fails in luau-rs ("invalid async callback
    // continuation"), and the card picture's living cat (Effects/Portrait) guards its first draw with one
    const open = lua.load('local open, name = ... return function() return open(name) end').call(scenes.rawGet('open'), name)[0];
    run(open, 1.5);
    const jitter = watch();
    const touchControls = fn('touchControls').call()[0] !== false;
    results.push({ scene: name, nodes: snapshot(), errors: takeErrors(), jitter, touchControls });
    run(scenes.rawGet('close'), 0.6);
    takeErrors();
    collect(lua, name);
  }
  return results;
}

const started = Date.now();
const all = [];
// --devices runs the three device sizes on their own. Each size also runs in its own node process (--emit), so
// every size gets a fresh wasm heap: three Luau states in one process sat at the wasm's memory ceiling, and on
// 2026-11-03 CI's phone run died with "not enough memory" after desktop and laptop.
const profiles = args.tablets
  ? TABLET_PROFILES
  : args.devices
    ? DEVICE_PROFILES
    : args.profile
      ? [...PROFILES, ...DEVICE_PROFILES, ...TABLET_PROFILES]
      : PROFILES;
const wanted = profiles.filter((profile) => !args.profile || args.profile === profile.name);
// The sizes run side by side, one child process each (CI has 4 cores; run in turn they took about 25 minutes of the
// job's 31, 2026-11-06). Their scenes are read back in order below, so the report and the baseline check are the same.
const childScenes = new Map();
if (args.save && !args.emit) {
  // CI shard: every size side by side over this shard's scenes, saved for the --merge job; nothing is checked here.
  const shard = parseShard(args.shard);
  if (!shard) throw new Error('--save needs --shard k/n');
  fs.mkdirSync(args.save, { recursive: true });
  await Promise.all(
    wanted.map((profile) => runChild(profile, path.join(args.save, `${profile.name}-${shard.k}-of-${shard.n}.json`), true)),
  );
  console.log(`Shard ${shard.k}/${shard.n}: ${wanted.length} sizes ran side by side in ${((Date.now() - started) / 1000).toFixed(1)} s`);
  process.exit(0);
}
if (args.merge) {
  // CI: the shards' scenes in shard order are the full run, so the dedupe, the report and the baseline check below
  // are the same as one run's. A missing shard fails, so a lost artifact can never pass the gate.
  for (const profile of wanted) {
    const parts = fs.readdirSync(args.merge).flatMap((file) => {
      const m = file.match(new RegExp(`^${profile.name}-(\\d+)-of-(\\d+)\\.json$`));
      return m ? [{ file, k: Number(m[1]), n: Number(m[2]) }] : [];
    });
    parts.sort((a, b) => a.k - b.k);
    const n = parts[0]?.n;
    if (!n || parts.length !== n || parts.some((p, i) => p.k !== i + 1 || p.n !== n)) {
      throw new Error(`UI gate --merge: ${profile.name} has shards ${parts.map((p) => `${p.k}/${p.n}`).join(', ') || 'none'} in ${args.merge}`);
    }
    childScenes.set(profile.name, parts.flatMap((p) => JSON.parse(fs.readFileSync(path.join(args.merge, p.file), 'utf8'))));
  }
} else if (!args.emit && wanted.length > 1) {
  await Promise.all(wanted.map(async (profile) => childScenes.set(profile.name, await runChild(profile))));
  console.log(`${wanted.length} sizes ran side by side in ${((Date.now() - started) / 1000).toFixed(1)} s`);
}
for (const profile of wanted) {
  const t0 = Date.now();
  const scenes =
    !args.merge && (args.emit || wanted.length === 1) ? await runProfile(profile) : childScenes.get(profile.name);
  if (args.emit) {
    fs.writeFileSync(args.emit, JSON.stringify(scenes));
    process.exit(0);
  }
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
    all.push({ profile, scene: scene.scene, nodes: scene.nodes, errors: scene.errors, findings, touchControls: scene.touchControls });
  }
  const nodes = scenes.reduce((n, s) => n + s.nodes.length, 0);
  console.log(
    `${profile.name} ${profile.width} x ${profile.height}: ${scenes.length} scenes, ${nodes} pieces, ${((Date.now() - t0) / 1000).toFixed(1)} s`,
  );
}

const baseline = fs.existsSync(baselineFile) ? JSON.parse(fs.readFileSync(baselineFile, 'utf8')) : { findings: {} };
const filtered = Boolean(args.profile || args.scene);
const { fresh, fixed, counts } = compareBaseline(all, baseline, filtered);
if (args.updateBaseline) {
  if (filtered) throw new Error('--update-baseline needs the full run (no --profile or --scene)');
  // the sizes this run left out (the device sizes, or the usual three under --devices) keep their accepted findings
  const ran = new Set(all.map((r) => r.profile.name));
  const kept = {};
  for (const [key, count] of Object.entries({ ...(baseline.findings || {}), ...counts })) {
    if (key in counts || !ran.has(key.split('|')[0])) kept[key] = counts[key] ?? count;
  }
  const findings = {};
  for (const key of Object.keys(kept).sort()) findings[key] = kept[key];
  const out = { note: 'UI gate findings accepted on 2026-11-01; fix them and shrink this file, never grow it by hand.', findings };
  fs.writeFileSync(baselineFile, JSON.stringify(out, null, 2) + '\n');
  console.log(`Wrote ${path.relative(process.cwd(), baselineFile)} (${Object.keys(findings).length} keys)`);
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

// One screen size in a child process: the same script with --profile and --emit, its scenes read back from a file.
// Resolves when the child is done, so the sizes can run at once.
async function runChild(profile, file = path.join(os.tmpdir(), `cat-cafe-uigate-${process.pid}-${profile.name}.json`), keep = false) {
  const childArgs = [...process.execArgv, fileURLToPath(import.meta.url), '--profile', profile.name, '--emit', file];
  if (args.scene) childArgs.push('--scene', args.scene);
  if (args.shard) childArgs.push('--shard', args.shard);
  if (args.verbose) childArgs.push('--verbose');
  if (args.mem) childArgs.push('--mem');
  const status = await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, childArgs, { stdio: 'inherit' });
    child.on('error', reject);
    child.on('exit', (code) => resolve(code));
  });
  if (status !== 0) throw new Error(`UI gate: the ${profile.name} run failed (exit ${status})`);
  if (keep) return null;
  const scenes = JSON.parse(fs.readFileSync(file, 'utf8'));
  fs.rmSync(file, { force: true });
  return scenes;
}

// '2/4' -> { k: 2, n: 4 }; nothing -> null.
function parseShard(text) {
  if (!text) return null;
  const m = /^(\d+)\/(\d+)$/.exec(text);
  const k = m && Number(m[1]);
  const n = m && Number(m[2]);
  if (!m || n < 1 || k < 1 || k > n) throw new Error(`--shard wants k/n with 1 <= k <= n, got ${text}`);
  return { k, n };
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') out.out = argv[++i];
    else if (arg === '--profile') out.profile = argv[++i];
    else if (arg === '--devices') out.devices = true;
    else if (arg === '--tablets') out.tablets = true;
    else if (arg === '--scene') out.scene = argv[++i];
    else if (arg === '--flag') process.env.UIGATE_FLAG = argv[++i]; // live switches set true before the UI is built, comma separated (#3558: menuFamily)
    else if (arg === '--update-baseline') out.updateBaseline = true;
    else if (arg === '--verbose' || arg === '-v') out.verbose = true;
    else if (arg === '--mem') out.mem = true; // the Luau heap after each scene, on stderr
    else if (arg === '--emit') out.emit = argv[++i]; // internal: run one --profile and write its scenes as JSON
    else if (arg === '--shard') out.shard = argv[++i]; // k/n: only the k-th of n slices of the scenes
    else if (arg === '--save') out.save = argv[++i]; // with --shard: write each size's scenes to this folder
    else if (arg === '--merge') out.merge = argv[++i]; // check the scenes every --save shard wrote to this folder
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node uigate.mjs [--out dir] [--devices] [--tablets] [--profile desktop|laptop|phone|tablet|smallphone|console|ipadmini|ipad43|ipadpro|tab1610|fire7] [--scene Name] [--flag menuFamily] [--update-baseline] [--verbose]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
