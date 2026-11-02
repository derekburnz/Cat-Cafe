#!/usr/bin/env node
// Cafe fit check (QA, 2026-11-02, for the bigger cafes: Model-Agent's 44 x 34 shell with Gameplay's Config and
// Layout points). Builds the world as worldscan.mjs does, then dresses the eight cafes as owners have them
// (cafefit-dress.luau): For Rent and Tiers 1 to 5 side by side, every table and chair, the shop decor on its anchors,
// big crate pieces at all eight decor spots, the cat beds and nap beds, a full front lawn with its path and fence.
//
//   node --max-old-space-size=10000 cafefit.mjs [--out dir] [--tiers 0,1,2,3,4,5,5,5] [--pieces a,b,...]
//
// It scans the hometown (floating, seams and clipping, as worldscan-checks.mjs does) and adds four checks:
//   dressing   every clash that involves a dressed piece (decor, lawn, tables and chairs, beds, the espresso
//              machine, the Lucky Cat), per cafe and tier
//   routes     each customer's walk as CustomerController makes it (Entry, Door, Order, the chair's Aisle and
//              Approach, the seat), swept as a body 1.6 wide from 0.8 to 4.5 studs up: anything drawn in the way
//   back door  the way out of the back door straight through the yard to past the yard fence, 3 wide from 1.2 up
//   fence ends the lawn fence's ends against the cafe's front corners, in plot space
// The report is <out>/cafe-fit.md (default out: <system temp>/cat-cafe-cafefit), with world-scan.md for the town.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Lua } from '@luau-rs/luau';
import { buildTree, jsonToLuau } from './rojo-tree.mjs';
import { parseParts, sat, scanWorld, writeReport } from './worldscan-checks.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const args = parseArgs(process.argv.slice(2));
const outDir = path.resolve(args.out || path.join(os.tmpdir(), 'cat-cafe-cafefit'));
const tiers = (args.tiers || '0,1,2,3,4,5,5,5').split(',').map(Number);
const BIG = ['CatCafe_Decor_DuckFountain', 'CatCafe_Decor_BathtubSofa', 'CatCafe_Decor_HollowLogBooth', 'CatCafe_Decor_PicnicTable', 'CatCafe_Decor_PorchSwing'];
const pieces = args.pieces ? args.pieces.split(',') : BIG;
const TOWN = 400; // the hometown is inside |x|, |z| < 400; the catching areas are 2000 out

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
const secs = () => ((Date.now() - started) / 1000).toFixed(1);
const shim = lua.load(fs.readFileSync(path.join(here, 'world-shim.luau'), 'utf8'), { name: 'world-shim' }).call(tree, hostLoad)[0];
console.log(`Loaded ${shim.rawGet('assetsLoaded')} asset models in ${secs()} s`);
const call = (name, ...rest) => shim.rawGet(name).call(...rest);
const builder = call('require', call('find', 'ServerScriptService.Server.World.WorldBuilder')[0])[0];
const world = builder.rawGet('build').call()[0];

// Dress the cafes in Luau, with the shim's globals.
const baseEnv = shim.rawGet('internals').rawGet('env');
const env = lua.createTable();
const envMeta = lua.createTable();
envMeta.rawSet('__index', baseEnv);
lua.globals.get('setmetatable').call(env, envMeta);
const dress = lua.load(fs.readFileSync(path.join(here, 'cafefit-dress.luau'), 'utf8'), { name: 'cafefit-dress', environment: env });
const options = lua.createTable();
const tierList = lua.createTable();
tiers.forEach((t, i) => tierList.rawSet(i + 1, t));
const pieceList = lua.createTable();
pieces.forEach((p, i) => pieceList.rawSet(i + 1, p));
options.rawSet('tiers', tierList);
options.rawSet('pieces', pieceList);
const info = String(dress.call(shim, world, builder, options)[0]);
const dump = String(call('dumpParts', world.rawGet('folder'))[0]);
const all = parseParts(dump);
const parts = all.filter((p) => Math.abs(p.c[0]) < TOWN && Math.abs(p.c[2]) < TOWN);
console.log(`Built and dressed the world: ${all.length} parts, ${parts.length} in the hometown (${secs()} s)`);

// What the dresser said about each plot.
const plots = new Map();
for (const line of info.split('\n')) {
  const f = line.split('\t');
  const p = Number(f[1]);
  if (!plots.has(p)) plots.set(p, { p, chairs: [], way: {} });
  const plot = plots.get(p);
  if (f[0] === 'PLOT') {
    plot.tier = Number(f[2]);
    plot.cf = f.slice(3, 15).map(Number);
  } else if (f[0] === 'CHAIR') {
    const n = f.slice(4).map(Number);
    plot.chairs.push({ table: Number(f[2]), seat: Number(f[3]), pivot: n.slice(0, 3), aisle: n.slice(3, 6), approach: n.slice(6, 9) });
  } else if (f[0] === 'WAY') {
    plot.way[f[2]] = f.slice(3, 6).map(Number);
  } else if (f[0] === 'BACKDOOR') {
    plot.backDoor = f.slice(2, 14).map(Number);
  }
}

// Plot space: x across (-x left facing in), y up, z into the cafe from the street (-z the front).
function toLocal(cf, w) {
  const d = [w[0] - cf[0], w[1] - cf[1], w[2] - cf[2]];
  // cf[3..11] is the rotation row by row; its columns are the plot's axes in the world
  return [0, 1, 2].map((k) => d[0] * cf[3 + k] + d[1] * cf[6 + k] + d[2] * cf[9 + k]);
}
const plotName = (p) => `Plot_${p}`;
const inPlot = (part, p) => part.path.includes(`.Plots.${plotName(p)}.`) || part.path.endsWith(`.Plots.${plotName(p)}`);

// A box swept along the floor from a to b (world points), half `w` wide, from y0 to y1 above the floor at a.
function sweepBox(a, b, w, y0, y1, trim = 0) {
  const dx = b[0] - a[0], dz = b[2] - a[2];
  const len = Math.hypot(dx, dz);
  if (len - 2 * trim < 0.05) return null;
  const u0 = [dx / len, 0, dz / len];
  const u1 = [0, 1, 0];
  const u2 = [-u0[2], 0, u0[0]];
  const c = [(a[0] + b[0]) / 2, a[1] + (y0 + y1) / 2, (a[2] + b[2]) / 2];
  const e = [len / 2 - trim, (y1 - y0) / 2, w];
  const ext = [0, 1, 2].map((k) => e[0] * Math.abs(u0[k]) + e[1] * Math.abs(u1[k]) + e[2] * Math.abs(u2[k]));
  return { c, u: [u0, u1, u2], e, min: c.map((v, k) => v - ext[k]), max: c.map((v, k) => v + ext[k]) };
}
const boxesMeet = (A, B) => A.min.every((v, k) => v <= B.max[k] && B.min[k] <= A.max[k]);
function hits(box, candidates, skip) {
  const out = [];
  for (const part of candidates) {
    if (!boxesMeet(box, part) || skip(part)) continue;
    const r = sat(box, part);
    if (r.gap < -0.1) out.push({ part, depth: -r.gap });
  }
  return out;
}
const label = (part) => {
  const unit = part.unit ? part.unit.split('.').slice(-1)[0] : '';
  return `${part.name} in ${unit}${part.asset && part.asset !== unit ? ` (${part.asset})` : ''}`;
};

const drawn = parts.filter((p) => p.visible);
const report = [];
const head = (s) => report.push('', `## ${s}`, '');

// 1. The town scan, folded as worldscan.mjs folds it.
const findings = scanWorld(parts);
fs.mkdirSync(outDir, { recursive: true });
writeReport(outDir, { parts, findings, assetFindings: null, tier: tiers.join(','), seconds: (Date.now() - started) / 1000 });

// 2. Clashes that involve a dressed piece, per cafe.
const DRESSED = /\.(Decor|Lawn|Tables|Dressing\.(bed_\d|NapBed_\d))\.|\.(Espresso|LuckyCat)\b/;
const plotOf = (s) => (s.match(/Plot_(\d+)/) || [])[1];
const dressedClips = [];
for (const part of drawn) part._dressed = DRESSED.test(part.path);
{
  // re-run the clipping pairs on the dressed parts only, so every cafe's rows are kept apart
  const dressed = drawn.filter((p) => p._dressed);
  for (const A of dressed) {
    const p = plotOf(A.path);
    const near = drawn.filter((B) => B !== A && B.unit !== A.unit && boxesMeet(A, B) && plotOf(B.path) === p);
    for (const B of near) {
      if (B._dressed && B.path < A.path) continue; // each dressed pair once
      if (/^(Floor|FrontGarden|Ground|Grass|Patio|Deck)/.test(B.name) && A.min[1] >= B.max[1] - 0.25) continue;
      const r = sat(A, B);
      if (r.gap < -0.12) dressedClips.push({ p: Number(p), a: label(A), b: label(B), depth: -r.gap, at: A.c });
    }
  }
}
head('Dressed pieces clipping (decor at the spots, lawn, tables and chairs, beds, espresso, Lucky Cat)');
const foldClips = new Map();
for (const c of dressedClips) {
  const key = `${c.a.replace(/Spot\d+_/, 'Spot#_').replace(/table_\d/, 'table_#')} | ${c.b}`;
  const row = foldClips.get(key) || { a: c.a, b: c.b, depth: 0, plots: new Set() };
  row.depth = Math.max(row.depth, c.depth);
  row.plots.add(`${c.p} (T${plots.get(c.p)?.tier})`);
  foldClips.set(key, row);
}
if (foldClips.size === 0) report.push('None over 0.12 studs.');
else {
  report.push('| piece | sunk into | deepest | cafes (tier) |', '|---|---|---|---|');
  for (const r of [...foldClips.values()].sort((x, y) => y.depth - x.depth)) {
    report.push(`| ${r.a} | ${r.b} | ${r.depth.toFixed(2)} | ${[...r.plots].join(', ')} |`);
  }
}

// 3. Customer routes.
const LEGS = ['Entry', 'Door', 'Order', 'Aisle', 'Approach', 'seat'];
head('Customer routes (Entry, Door, Order, Aisle, Approach, seat; a body 1.6 wide from 0.8 to 4.5 up)');
const routeRows = [];
let routeCount = 0;
for (const plot of plots.values()) {
  if (plot.tier < 1) continue;
  const local = drawn.filter((part) => inPlot(part, plot.p));
  for (const chair of plot.chairs) {
    const pts = [plot.way.Entry, plot.way.Door, plot.way.Order, chair.aisle, chair.approach, chair.pivot].filter(Boolean);
    const floorY = plot.cf[1]; // the plot's origin is the floor's top centre
    routeCount++;
    for (let i = 0; i + 1 < pts.length; i++) {
      const a = [pts[i][0], floorY, pts[i][2]], b = [pts[i + 1][0], floorY, pts[i + 1][2]];
      const last = i + 2 === pts.length;
      const box = sweepBox(a, b, 0.8, 0.8, 4.5, 0.4);
      if (!box) continue;
      const skip = (part) =>
        /Door|CatFlap|Customer|Waypoint/.test(part.path) ||
        (last && part.path.includes(`.Tables.table_${chair.table}.`)) ||
        (i === 2 && /\.Counter\b/.test(part.path));
      for (const h of hits(box, local, skip)) {
        const c = toLocal(plot.cf, h.part.c).map((v) => v.toFixed(1)).join(', ');
        routeRows.push({ p: plot.p, tier: plot.tier, chair: `table ${chair.table} seat ${chair.seat}`, leg: LEGS[i] + ' to ' + LEGS[i + 1], what: `${label(h.part)} at (${c}) size ${h.part.size.map((v) => v.toFixed(1)).join(' x ')}`, depth: h.depth });
      }
    }
  }
}
report.push(`${routeCount} chairs walked.`, '');
for (const plot of plots.values()) {
  if (plot.tier < 1) continue;
  const w = ['Entry', 'Door', 'Order'].map((k) => (plot.way[k] ? `${k} (${toLocal(plot.cf, plot.way[k]).map((v) => v.toFixed(1)).join(', ')})` : `${k} none`));
  report.push(`- cafe ${plot.p} (T${plot.tier}) in plot space: ${w.join(', ')}`);
  break;
}
if (routeRows.length === 0) report.push('', 'Nothing drawn stands in any route.');
else {
  report.push('', '| cafe (tier) | chair | leg | in the way | depth |', '|---|---|---|---|---|');
  for (const r of routeRows.sort((x, y) => y.depth - x.depth).slice(0, 80)) {
    report.push(`| ${r.p} (T${r.tier}) | ${r.chair} | ${r.leg} | ${r.what} | ${r.depth.toFixed(2)} |`);
  }
}

// 4. The back door's way out through the yard.
head('Back door to the old yard gate (3 wide, from 1.2 up, straight out to the yard fence, which closes the gate since F84)');
const doorRows = [];
for (const plot of plots.values()) {
  if (plot.tier < 1 || !plot.backDoor) continue;
  const local = drawn.filter((part) => inPlot(part, plot.p));
  const door = toLocal(plot.cf, plot.backDoor.slice(0, 3));
  const fence = local.filter((part) => part.asset === 'CatCafe_Plot_YardFence');
  const fenceZ = Math.max(...fence.map((part) => toLocal(plot.cf, part.c)[2]));
  const fromW = plot.backDoor.slice(0, 3);
  // the door's outward direction: +z of the plot
  const toW = [0, 1, 2].map((k) => plot.cf[k] + plot.cf[3 + k * 3] * door[0] + plot.cf[3 + k * 3 + 2] * (fenceZ + 3));
  const floorY = fromW[1] - 3.5;
  const box = sweepBox([fromW[0], floorY, fromW[2]], [toW[0], floorY, toW[2]], 1.5, 1.2, 6, 0.8);
  // the yard fence closes the old gate (v4, F84), so it is where the way ends, not something in it
  const found = box ? hits(box, local, (part) => /BackDoor|CatFlap|DoorBack/.test(part.path) || part.asset === 'CatCafe_Plot_YardFence') : [];
  // the deck path from the door: the long low strip of wood at the door's x, in the tier sets or the shell
  const deck = local.filter((part) => {
    const q = toLocal(plot.cf, part.c);
    return part.max[1] - plot.cf[1] < 0.4 && q[2] > door[2] + 2 && Math.abs(q[0] - door[0]) < 4 && part.size.some((v) => v > 6);
  });
  const strips = new Set(
    deck
      .filter((part) => !/^(Floor|Ground|Grass)$/.test(part.name))
      .map((part) => {
        const a = toLocal(plot.cf, part.min)[0], b = toLocal(plot.cf, part.max)[0];
        return `${part.unit.split('.').pop()} x ${Math.min(a, b).toFixed(2)} to ${Math.max(a, b).toFixed(2)}`;
      }),
  );
  const deckX = strips.size ? [...strips].join('; ') : null;
  doorRows.push({ p: plot.p, tier: plot.tier, door: door.map((v) => v.toFixed(2)).join(', '), fenceZ: fenceZ.toFixed(2), deckX, found });
}
report.push('| cafe (tier) | back door (plot space) | yard fence back z | low strips out from the door | in the way |', '|---|---|---|---|---|');
for (const r of doorRows) {
  const what = r.found.length === 0 ? 'clear' : r.found.map((h) => `${label(h.part)} at (${toLocal(plots.get(r.p).cf, h.part.c).map((v) => v.toFixed(1)).join(', ')}) ${h.depth.toFixed(2)}`).slice(0, 6).join('; ');
  report.push(`| ${r.p} (T${r.tier}) | (${r.door}) | ${r.fenceZ} | ${r.deckX == null ? 'none' : r.deckX} | ${what} |`);
}

// 5. The lawn fence's ends against the cafe's front corners.
head('Lawn fence ends and the cafe front (plot space)');
report.push('| cafe (tier) | fence x | fence z | shell x | shell front z | x gap left, right |', '|---|---|---|---|---|---|');
for (const plot of plots.values()) {
  const local = drawn.filter((part) => inPlot(part, plot.p));
  const fence = local.filter((part) => /\.Lawn\.Fence\./.test(part.path));
  // the shell's walls at the ground (eaves and roof overhang left out), and the plot's floor edge
  const shell = local.filter((part) => /\.Shell\./.test(part.path) && !/_Path|Path$/.test(part.path) && part.min[1] - plot.cf[1] < 1 && part.max[1] - plot.cf[1] > 3);
  if (fence.length === 0 || shell.length === 0) continue;
  const span = (list, k) => {
    const v = list.flatMap((part) => [toLocal(plot.cf, part.min)[k], toLocal(plot.cf, part.max)[k]]);
    return [Math.min(...v), Math.max(...v)];
  };
  const fx = span(fence, 0), fz = span(fence, 2), sx = span(shell, 0), sz = span(shell, 2);
  report.push(`| ${plot.p} (T${plot.tier}) | ${fx.map((v) => v.toFixed(2)).join(' to ')} | ${fz.map((v) => v.toFixed(2)).join(' to ')} | ${sx.map((v) => v.toFixed(2)).join(' to ')} | ${sz[0].toFixed(2)} | ${(fx[0] - sx[0]).toFixed(2)}, ${(sx[1] - fx[1]).toFixed(2)} |`);
}

// 6. The town's own rows from the scan (gardens, ends, paving).
head('Town and square from the scan');
const townRows = [];
for (const kind of ['floating', 'gaps', 'clips']) {
  for (const f of findings[kind]) {
    if (/^Plot_/.test(f.place || '')) continue;
    townRows.push({ kind, place: f.place, what: f.a ? `${f.a} / ${f.b}` : (f.parts || f.what || JSON.stringify(f).slice(0, 120)), size: f.gap ?? f.depth ?? f.drop ?? '' });
  }
}
const townFold = new Map();
for (const r of townRows) {
  const key = `${r.kind} | ${r.place} | ${r.what}`;
  if (!townFold.has(key)) townFold.set(key, r);
}
report.push(`${townFold.size} distinct rows outside the cafes (world-scan.md has them in full).`, '', '| check | place | parts | size |', '|---|---|---|---|');
for (const r of [...townFold.values()].slice(0, 60)) report.push(`| ${r.kind} | ${r.place} | ${r.what} | ${typeof r.size === 'number' ? r.size.toFixed(2) : r.size} |`);

const summary = [
  '# Cafe fit check',
  '',
  `Made by \`games/cat-cafe/tools/cloudcheck/cafefit.mjs\` in ${secs()} s: the real \`WorldBuilder.build()\` with every model in \`assets/cat-cafe/rbx/\`, the eight cafes at tiers ${tiers.join(', ')} (0 is For Rent), each owned one dressed in full (cafefit-dress.luau) with ${pieces.map((p) => p.replace('CatCafe_Decor_', '')).join(', ')} rotated over the eight decor spots. ${parts.length} parts in the hometown.`,
  '',
  '| check | rows |',
  '|---|---|',
  `| dressed pieces clipping | ${foldClips.size} |`,
  `| customer route legs blocked | ${routeRows.length} |`,
  `| back doors with something in the way | ${doorRows.filter((r) => r.found.length > 0).length} of ${doorRows.length} |`,
  `| town rows (floating, seams, clipping) | ${townFold.size} |`,
];
fs.writeFileSync(path.join(outDir, 'cafe-fit.md'), [...summary, ...report, ''].join('\n'));
console.log(`Report: ${path.join(outDir, 'cafe-fit.md')}`);

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--out') out.out = argv[++i];
    else if (arg === '--tiers') out.tiers = argv[++i];
    else if (arg === '--pieces') out.pieces = argv[++i];
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node --max-old-space-size=10000 cafefit.mjs [--out dir] [--tiers 0,1,2,3,4,5,5,5] [--pieces a,b]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
