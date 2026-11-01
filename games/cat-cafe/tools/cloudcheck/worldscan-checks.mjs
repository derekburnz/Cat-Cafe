// Geometry checks for worldscan.mjs. Every part is treated as a box: a cylinder as the box round it (Roblox
// cylinders run along local X, their diameter the smaller of Y and Z), a ball as a cube of its smallest side, a
// SpecialMesh sphere as the part's box times the mesh scale, a wedge as its whole box. Boxes are tested with the
// separating axis test, which gives the gap between two boxes (or how deep they sink into each other).
import fs from 'node:fs';
import path from 'node:path';

export const TOUCH = 0.1; // studs: closer than this counts as attached (the exporter drops bevels and rounds to 1e-4)
export const GAP_MIN = 0.05; // studs: a seam narrower than this cannot be seen
export const GAP_MAX = 0.6; // studs: a wider gap between two faces is spacing, not a seam
export const CLIP_MIN = 0.12; // studs: one model sunk this far into another is visible
export const INVISIBLE = 0.95; // transparency from which a part is not drawn for these checks
const CELL = 4;

export function parseParts(text) {
  const out = [];
  for (const line of text.split('\n')) {
    if (!line) continue;
    const f = line.split('\t');
    const part = {
      path: f[0],
      cls: f[1],
      shape: f[2],
      m: f.slice(3, 15).map(Number),
      size: f.slice(15, 18).map(Number),
      transparency: Number(f[18]),
      collide: f[19] === '1',
      mesh: f[20],
      unit: f[21],
      material: f[22],
      asset: f[23] || '',
    };
    out.push(withBox(part));
  }
  return out;
}

function withBox(part) {
  let [sx, sy, sz] = part.size;
  if (part.mesh) {
    const [type, kx, ky, kz] = part.mesh.split(' ');
    if (type === 'Sphere' || type === 'Brick' || type === 'Cylinder') {
      sx *= Number(kx);
      sy *= Number(ky);
      sz *= Number(kz);
    }
  } else if (part.shape === 'Ball') {
    const d = Math.min(sx, sy, sz);
    sx = sy = sz = d;
  } else if (part.shape === 'Cylinder') {
    const d = Math.min(sy, sz);
    sy = sz = d;
  }
  const m = part.m;
  part.c = [m[0], m[1], m[2]];
  // columns of the rotation: the part's own X, Y and Z axes in the world
  part.u = [
    [m[3], m[6], m[9]],
    [m[4], m[7], m[10]],
    [m[5], m[8], m[11]],
  ];
  part.e = [sx / 2, sy / 2, sz / 2];
  // world box round the part
  const ext = [0, 1, 2].map((k) => part.e[0] * Math.abs(part.u[0][k]) + part.e[1] * Math.abs(part.u[1][k]) + part.e[2] * Math.abs(part.u[2][k]));
  part.min = [part.c[0] - ext[0], part.c[1] - ext[1], part.c[2] - ext[2]];
  part.max = [part.c[0] + ext[0], part.c[1] + ext[1], part.c[2] + ext[2]];
  part.visible = part.transparency < INVISIBLE && part.size.every((s) => s > 0);
  part.name = part.path.split('.').pop();
  return part;
}

const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];

// Separating axis test. Returns { gap, axis, face } where gap > 0 is the distance the boxes stand apart along the best
// separating axis (a lower bound on their true distance, exact face to face) and gap <= 0 is minus the depth one sinks
// into the other. `face` is [box, k] when that axis is a face normal of box 0 (A) or 1 (B), else null.
export function sat(A, B) {
  const d = [B.c[0] - A.c[0], B.c[1] - A.c[1], B.c[2] - A.c[2]];
  let best = -Infinity;
  let bestAxis = null;
  let bestFace = null;
  let minOverlap = Infinity;
  let overlapAxis = null;
  let overlapFace = null;
  const test = (L, face) => {
    const len = Math.hypot(L[0], L[1], L[2]);
    if (len < 1e-6) return;
    const n = [L[0] / len, L[1] / len, L[2] / len];
    const ra = A.e[0] * Math.abs(dot(A.u[0], n)) + A.e[1] * Math.abs(dot(A.u[1], n)) + A.e[2] * Math.abs(dot(A.u[2], n));
    const rb = B.e[0] * Math.abs(dot(B.u[0], n)) + B.e[1] * Math.abs(dot(B.u[1], n)) + B.e[2] * Math.abs(dot(B.u[2], n));
    const r = Math.abs(dot(d, n)) - (ra + rb);
    if (r > best) {
      best = r;
      bestAxis = n;
      bestFace = face;
    }
    if (-r < minOverlap) {
      minOverlap = -r;
      overlapAxis = n;
      overlapFace = face;
    }
  };
  for (let k = 0; k < 3; k++) test(A.u[k], [0, k]);
  for (let k = 0; k < 3; k++) test(B.u[k], [1, k]);
  for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) test(cross(A.u[i], B.u[j]), null);
  if (best > 0) return { gap: best, axis: bestAxis, face: bestFace };
  return { gap: -minOverlap, axis: overlapAxis, face: overlapFace };
}

// How two boxes face each other across a face of one of them: the overlap of their shadows on that face's plane
// as [length, width] along the face's two edges, and five points in the gap between them (its middle and four
// points halfway to its corners), to see whether anything else fills it.
function faceOverlap(A, B, face) {
  const [which, k] = face;
  const P = which === 0 ? A : B;
  const Q = which === 0 ? B : A;
  const reach = (box, axis) => box.e[0] * Math.abs(dot(box.u[0], axis)) + box.e[1] * Math.abs(dot(box.u[1], axis)) + box.e[2] * Math.abs(dot(box.u[2], axis));
  const spans = [];
  const centres = [];
  const axes = [];
  for (let j = 0; j < 3; j++) {
    if (j === k) continue;
    const axis = P.u[j];
    const pc = dot(P.c, axis), pr = P.e[j];
    const qc = dot(Q.c, axis), qr = reach(Q, axis);
    const lo = Math.max(pc - pr, qc - qr), hi = Math.min(pc + pr, qc + qr);
    spans.push(hi - lo);
    centres.push((lo + hi) / 2);
    axes.push(axis);
  }
  const n = P.u[k];
  const side = Math.sign(dot([Q.c[0] - P.c[0], Q.c[1] - P.c[1], Q.c[2] - P.c[2]], n)) || 1;
  const pFace = dot(P.c, n) + side * P.e[k];
  const qFace = dot(Q.c, n) - side * reach(Q, n);
  // Five lines of sight across the gap, each sampled at a quarter, half and three quarters of the way, so a thin
  // part that fills one side of the gap (wallpaper on a wall) closes the line.
  const point = (s, t, f) => {
    const a = centres[0] + s * spans[0] / 4, b = centres[1] + t * spans[1] / 4;
    const depth = pFace + (qFace - pFace) * f;
    return [0, 1, 2].map((c) => n[c] * depth + axes[0][c] * a + axes[1][c] * b);
  };
  const samples = [[0, 0], [-1, -1], [1, -1], [-1, 1], [1, 1]].map(([s, t]) => [0.25, 0.5, 0.75].map((f) => point(s, t, f)));
  return { spans, samples };
}

// A uniform grid over the world boxes: candidate pairs (each once) and point queries.
function makeGrid(parts, pad) {
  const grid = new Map();
  const key = (x, y, z) => `${x},${y},${z}`;
  parts.forEach((p, index) => {
    const x0 = Math.floor((p.min[0] - pad) / CELL), x1 = Math.floor((p.max[0] + pad) / CELL);
    const y0 = Math.floor((p.min[1] - pad) / CELL), y1 = Math.floor((p.max[1] + pad) / CELL);
    const z0 = Math.floor((p.min[2] - pad) / CELL), z1 = Math.floor((p.max[2] + pad) / CELL);
    for (let x = x0; x <= x1; x++)
      for (let y = y0; y <= y1; y++)
        for (let z = z0; z <= z1; z++) {
          const k = key(x, y, z);
          let list = grid.get(k);
          if (!list) grid.set(k, (list = []));
          list.push(index);
        }
  });
  return {
    *pairs() {
      const seen = new Set();
      for (const list of grid.values()) {
        for (let a = 0; a < list.length; a++) {
          for (let b = a + 1; b < list.length; b++) {
            const i = list[a], j = list[b];
            const id = i < j ? i * 1e6 + j : j * 1e6 + i;
            if (seen.has(id)) continue;
            seen.add(id);
            const P = parts[i], Q = parts[j];
            if (P.min[0] - pad > Q.max[0] || Q.min[0] - pad > P.max[0]) continue;
            if (P.min[1] - pad > Q.max[1] || Q.min[1] - pad > P.max[1]) continue;
            if (P.min[2] - pad > Q.max[2] || Q.min[2] - pad > P.max[2]) continue;
            yield [i, j];
          }
        }
      }
    },
    // the parts whose box holds the point, within `slack` studs
    holding(point, slack = 0.01) {
      const list = grid.get(key(Math.floor(point[0] / CELL), Math.floor(point[1] / CELL), Math.floor(point[2] / CELL))) || [];
      return list.filter((i) => inside(parts[i], point, slack));
    },
  };
}

function inside(P, point, slack) {
  const d = [point[0] - P.c[0], point[1] - P.c[1], point[2] - P.c[2]];
  for (let k = 0; k < 3; k++) if (Math.abs(dot(d, P.u[k])) > P.e[k] + slack) return false;
  return true;
}

const GROUNDISH = /^(Ground|Street|Sidewalk)$/;
const round = (x, n = 2) => Number(x.toFixed(n));
const at = (p) => `(${round(p[0], 1)}, ${round(p[1], 1)}, ${round(p[2], 1)})`;

// Where a finding sits: the area or cafe it is in, read from the part's path.
export function placeOf(part, other) {
  if (other && GROUNDISH.test(part.path.split('.').pop()) && part.path.split('.').length <= 4) return placeOf(other);
  const bits = part.path.split('.');
  const i = bits.indexOf('World');
  if (i < 0) return part.asset || bits[0];
  const top = bits[i + 1];
  if (top === 'Plots') return bits[i + 2];
  return top;
}

function unitLabel(part) {
  const tail = part.unit ? part.unit.split('.').slice(-1)[0] : '';
  if (part.asset && part.asset !== tail) return `${tail} (${part.asset})`;
  return tail || part.path.split('.').slice(-2, -1)[0];
}

// The parts a player sees, the touch graph between them, gaps and clipping, in one pass over the candidate pairs.
function analyse(parts, { groundY = 0, crossUnitOnly = true } = {}) {
  const shown = parts.filter((p) => p.visible);
  const index = new Map(shown.map((p, i) => [p, i]));
  const links = shown.map(() => []);
  const gaps = [];
  const clips = [];
  const grid = makeGrid(shown, GAP_MAX);
  for (const [i, j] of grid.pairs()) {
    const A = shown[i], B = shown[j];
    const r = sat(A, B);
    if (r.gap <= TOUCH) {
      links[i].push(j);
      links[j].push(i);
    }
    if (r.gap > GAP_MIN && r.gap <= GAP_MAX && r.face) {
      const { spans, samples } = faceOverlap(A, B, r.face);
      // a seam: the faces overlap at least 0.3 by 0.3 studs and most of the gap between them is open (nothing else
      // drawn fills it, as a neck fills the space between a cat's body and head)
      if (spans[0] >= 0.3 && spans[1] >= 0.3 && seamKind(A, B, r)) {
        const open = samples.filter((line) => line.every((pt) => grid.holding(pt).every((h) => h === i || h === j))).length;
        if (open >= 3) gaps.push({ A, B, gap: r.gap, area: spans[0] * spans[1], axis: r.axis, open });
      }
    }
    if (r.gap < -CLIP_MIN && (!crossUnitOnly || A.unit !== B.unit) && !sinkIntoFloor(A, B, r) && !setInWall(A, B)) {
      clips.push({ A, B, depth: -r.gap, axis: r.axis });
    }
  }
  // grounded: everything reachable from a part that reaches the ground
  const grounded = new Array(shown.length).fill(false);
  const queue = [];
  shown.forEach((p, i) => {
    if (p.min[1] <= groundY + TOUCH) {
      grounded[i] = true;
      queue.push(i);
    }
  });
  while (queue.length) {
    const i = queue.pop();
    for (const j of links[i]) {
      if (!grounded[j]) {
        grounded[j] = true;
        queue.push(j);
      }
    }
  }
  // floating groups: connected parts never reaching the ground
  const groupOf = new Array(shown.length).fill(-1);
  const groups = [];
  shown.forEach((_, start) => {
    if (grounded[start] || groupOf[start] >= 0) return;
    const members = [];
    const stack = [start];
    groupOf[start] = groups.length;
    while (stack.length) {
      const i = stack.pop();
      members.push(i);
      for (const j of links[i]) {
        if (groupOf[j] < 0) {
          groupOf[j] = groups.length;
          stack.push(j);
        }
      }
    }
    groups.push(members.map((i) => shown[i]));
  });
  return { shown, index, grounded, groups, gaps, clips };
}

// Something standing sunk into the ground or a floor slab (pushed down, not sideways) is how props are set on a
// floor and does not show; the same for a slab laid into the ground.
const FLOORS = /^(Ground|Street|Sidewalk|Floor|FrontGarden|Patio|Deck|Paving)|_Floor|_Paving|_Ground|_Path|Slab|Rug|Carpet|Grass|Ridge|Water/;
function sinkIntoFloor(A, B, r) {
  if (Math.abs(r.axis[1]) < 0.9) return false;
  const lower = A.c[1] < B.c[1] ? A : B;
  const flat = lower.max[1] - lower.min[1] <= 1.5 || FLOORS.test(lower.name);
  return flat || FLOORS.test(lower.name);
}

// Which near faces make a seam worth fixing. Side by side (the gap runs across, not up): walls, trims, panes and
// frames that should meet, but not a piece of furniture or a prop standing a little way off a wall, and not lights.
// One above the other: only a wall or other tall piece standing just above the ground or a floor, where daylight
// shows under it (anything else up in the air is the floating check's).
const LOOSE = /^CatCafe_(Furniture|Decor|Prop|Cat|Accessory|Food|Coin|Crate|Toy|Customer|Item)_/;
function seamKind(A, B, r) {
  if (LIGHTS.test(A.name) || LIGHTS.test(B.name)) return false;
  if (Math.abs(r.axis[1]) < 0.5) {
    const loose = LOOSE.test(A.asset) || LOOSE.test(B.asset);
    return !loose || r.gap <= 0.15;
  }
  const [low, high] = A.c[1] < B.c[1] ? [A, B] : [B, A];
  return (FLOORS.test(low.name) || low.max[1] - low.min[1] <= 1.5) && high.max[1] - high.min[1] >= 2;
}

// Door and window frames are set into their walls on purpose.
const OPENINGS = /Door|Window|Frame|Arch|Gate|Sill|Shutter/;
const WALLS = /Wall|Shell|Interior|Paint|Wallpaper|Building|House|Cafe_/;
function setInWall(A, B) {
  return (OPENINGS.test(A.name) && WALLS.test(B.name)) || (OPENINGS.test(B.name) && WALLS.test(A.name));
}

// The nearest visible part under a floating group (inside its footprint), and the drop to it.
function dropUnder(group, near, inGroup) {
  const lo = Math.min(...group.map((p) => p.min[1]));
  const minX = Math.min(...group.map((p) => p.min[0])), maxX = Math.max(...group.map((p) => p.max[0]));
  const minZ = Math.min(...group.map((p) => p.min[2])), maxZ = Math.max(...group.map((p) => p.max[2]));
  let best = null;
  for (const q of near) {
    if (inGroup.has(q)) continue;
    if (q.max[1] > lo + TOUCH || q.max[0] < minX || q.min[0] > maxX || q.max[2] < minZ || q.min[2] > maxZ) continue;
    const drop = Math.max(0, lo - q.max[1]);
    if (best === null || drop < best.drop) best = { drop, part: q };
  }
  return best;
}

// The closest visible part to a floating group from outside it: the gap that would join it on.
function nearestTo(group, near, inGroup) {
  let best = null;
  for (const q of near) {
    if (inGroup.has(q)) continue;
    for (const p of group) {
      const r = sat(p, q);
      if (best === null || r.gap < best.gap) best = { gap: r.gap, part: q, from: p };
    }
  }
  return best;
}

function around(group, shown, reach) {
  const minB = [0, 1, 2].map((k) => Math.min(...group.map((p) => p.min[k])) - reach);
  const maxB = [0, 1, 2].map((k) => Math.max(...group.map((p) => p.max[k])) + reach);
  minB[1] = -Infinity; // everything below, for the drop
  return shown.filter((q) => !(q.max[0] < minB[0] || q.min[0] > maxB[0] || q.max[1] < minB[1] || q.min[1] > maxB[1] || q.max[2] < minB[2] || q.min[2] > maxB[2]));
}

const LIGHTS = /StringLights|Bulb|Lantern|Lamp|Bunting|Firefl/;

function describeGroups(groups, shown) {
  return groups.map((group) => {
    const inGroup = new Set(group);
    const near = around(group, shown, 4);
    const under = dropUnder(group, near, inGroup);
    const close = nearestTo(group, near, inGroup);
    const units = new Set(group.map((p) => p.unit));
    return {
      place: placeOf(group[0]),
      what: [...new Set(group.map(unitLabel))].join(', '),
      names: [...new Set(group.map((p) => p.name))].slice(0, 4).join(', '),
      parts: group.length,
      at: [0, 1, 2].map((k) => group.reduce((s, p) => s + p.c[k], 0) / group.length),
      drop: under ? under.drop : null,
      over: under ? `${under.part.name} in ${unitLabel(under.part)}` : 'nothing',
      nearest: close ? close.gap : null,
      nearTo: close ? `${close.part.name} in ${unitLabel(close.part)}` : '',
      scope: close && units.has(close.part.unit) ? 'inside one model' : 'placement',
      lights: group.some((p) => LIGHTS.test(p.name)),
    };
  });
}

export function scanWorld(parts) {
  const { shown, groups, gaps, clips } = analyse(parts, { groundY: 0 });
  return {
    floating: describeGroups(groups, shown),
    gaps: gaps.map((g) => ({
      place: placeOf(g.A, g.B),
      a: `${g.A.name} in ${unitLabel(g.A)}`,
      b: `${g.B.name} in ${unitLabel(g.B)}`,
      gap: g.gap,
      area: g.area,
      at: midpoint(g.A, g.B),
      scope: g.A.unit === g.B.unit ? 'inside one model' : 'placement',
    })),
    clips: clips.map((c) => ({
      place: placeOf(c.A, c.B),
      a: `${c.A.name} in ${unitLabel(c.A)}`,
      b: `${c.B.name} in ${unitLabel(c.B)}`,
      depth: c.depth,
      at: midpoint(c.A, c.B),
      // cut right through a thin panel (a poster, sign, pane or board under half a stud thick along the push)
      through: cutsThrough(c),
    })),
    counts: { parts: parts.length, shown: shown.length },
  };
}

export function scanAsset(name, parts) {
  const drawn = parts.filter((p) => p.visible);
  if (drawn.length === 0) return [];
  const groundY = Math.min(...drawn.map((p) => p.min[1]));
  const { shown, groups, gaps } = analyse(parts, { groundY, crossUnitOnly: true });
  const out = [];
  for (const g of describeGroups(groups, shown)) out.push({ asset: name, kind: 'floating', ...g });
  for (const g of gaps) {
    out.push({ asset: name, kind: 'seam', names: `${g.A.name} / ${g.B.name}`, gap: g.gap, area: g.area, at: midpoint(g.A, g.B) });
  }
  return out;
}

function cutsThrough(c) {
  const thick = (box) => 2 * (box.e[0] * Math.abs(dot(box.u[0], c.axis)) + box.e[1] * Math.abs(dot(box.u[1], c.axis)) + box.e[2] * Math.abs(dot(box.u[2], c.axis)));
  const thin = Math.min(thick(c.A), thick(c.B));
  return thin <= 0.5 && c.depth >= thin - 0.01;
}

function midpoint(A, B) {
  return [0, 1, 2].map((k) => (Math.max(A.min[k], B.min[k]) + Math.min(A.max[k], B.max[k])) / 2);
}

// The 8 cafes repeat one another and the area sets number their pieces: one row per kind of problem, with where.
const norm = (s) =>
  String(s)
    .replace(/CatCafe_Plot_Cafe_[A-Za-z]+/g, 'CatCafe_Plot_Cafe_<colour>')
    .replace(/_(SetV?\d*)_\d{3}_/g, '_$1_<n>_')
    .replace(/\b(bed|entertainer|table|seat|spot|decor)_\d+/gi, '$1_<n>')
    .replace(/Plot_\d+/g, 'Plot_<n>');

const SECTIONS = [
  ['Cafes', (place) => /^Plot_\d+$/.test(place)],
  ['Areas', (place) => /^(Alley|Park|Neighbourhood|Woods|Sewer)$/.test(place)],
  ['Town', () => true],
];
const sectionOf = (place) => SECTIONS.find(([, test]) => test(place))[0];

function collapse(rows, keyOf, worse) {
  const map = new Map();
  for (const r of rows) {
    const key = `${sectionOf(r.place)}|${keyOf(r)}`;
    const prev = map.get(key);
    if (!prev) map.set(key, { ...r, section: sectionOf(r.place), where: new Set([r.place]), times: 1 });
    else {
      prev.where.add(r.place);
      prev.times += 1;
      if (worse(r, prev)) Object.assign(prev, { ...r, section: prev.section, where: prev.where, times: prev.times });
    }
  }
  return [...map.values()].map((r) => ({ ...r, where: [...r.where].sort().join(' ') }));
}

const csv = (rows, cols) =>
  [cols.join(',')]
    .concat(
      rows.map((r) =>
        cols
          .map((c) => {
            const v = r[c];
            const s = Array.isArray(v) ? v.map((x) => (typeof x === 'number' ? round(x, 1) : x)).join(' ') : typeof v === 'number' ? String(round(v, 3)) : String(v ?? '');
            return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
          })
          .join(',')
      )
    )
    .join('\n') + '\n';

const cell = (s) => String(s).replaceAll('|', '/');

export function writeReport(outDir, { parts, findings, assetFindings, tier, seconds }) {
  const f = findings;
  const floating = collapse(f.floating, (r) => `${r.scope}|${norm(r.what)}|${norm(r.names)}|${norm(r.nearTo)}`, (r, p) => (r.nearest ?? 99) > (p.nearest ?? 99));
  // With --assets the seams inside one model are listed per model at the end, so the world sections keep placement only.
  const seams = collapse(
    f.gaps.filter((r) => r.scope === 'placement' || !assetFindings),
    (r) => `${r.scope}|${norm(r.a)}|${norm(r.b)}`,
    (r, p) => r.gap > p.gap
  );
  const clips = collapse(f.clips, (r) => `${norm(r.a)}|${norm(r.b)}`, (r, p) => r.depth > p.depth);

  fs.writeFileSync(path.join(outDir, 'floating.csv'), csv(f.floating, ['place', 'scope', 'what', 'names', 'parts', 'at', 'drop', 'over', 'nearest', 'nearTo', 'lights']));
  fs.writeFileSync(path.join(outDir, 'seams.csv'), csv(f.gaps, ['place', 'scope', 'a', 'b', 'gap', 'area', 'at']));
  fs.writeFileSync(path.join(outDir, 'clipping.csv'), csv(f.clips, ['place', 'a', 'b', 'depth', 'through', 'at']));
  if (assetFindings) fs.writeFileSync(path.join(outDir, 'models.csv'), csv(assetFindings, ['asset', 'kind', 'names', 'parts', 'at', 'drop', 'over', 'nearest', 'nearTo', 'gap', 'area']));

  const L = [];
  const count = (rows, section) => rows.filter((r) => r.section === section).length;
  L.push('# World scan');
  L.push('');
  L.push(`Made by \`games/cat-cafe/tools/cloudcheck/worldscan.mjs\`: the real \`WorldBuilder.build()\` run in the cloud with every model in \`assets/cat-cafe/rbx/\`, each cafe dressed at Tier ${tier} with its patio open. ${parts.length} parts, ${f.counts.shown} of them drawn, ${round(seconds, 0)} s. Every part is checked as a box (a cylinder or ball as the box round it), so a reported gap is at least that wide and a reported overlap at least that deep.`);
  L.push('');
  L.push('| | Cafes | Town | Areas | rows in the CSV |');
  L.push('|---|---|---|---|---|');
  L.push(`| Floating: drawn parts joined to nothing that reaches the ground (gap over ${TOUCH} studs) | ${count(floating, 'Cafes')} | ${count(floating, 'Town')} | ${count(floating, 'Areas')} | ${f.floating.length} |`);
  L.push(`| Seams: two faces ${GAP_MIN} to ${GAP_MAX} studs apart with the space between them open | ${count(seams, 'Cafes')} | ${count(seams, 'Town')} | ${count(seams, 'Areas')} | ${f.gaps.length} |`);
  L.push(`| Clipping: a part of one placed model at least ${CLIP_MIN} studs into another model | ${count(clips, 'Cafes')} | ${count(clips, 'Town')} | ${count(clips, 'Areas')} | ${f.clips.length} |`);
  L.push('');
  L.push('Rows are folded: the eight cafes and the area sets\' numbered pieces repeat, so one row stands for every copy, with `where` listing them and the worst copy\'s position. Positions are world studs (x, y, z) with y up and the Town Square at (0, 0, 0). "Placement" rows are between two separately placed things (fixed where they are placed, or by moving one model\'s pieces); "inside one model" rows are within one model file.');
  for (const section of ['Cafes', 'Town', 'Areas']) {
    L.push('');
    L.push(`## ${section}`);
    const fl = floating.filter((r) => r.section === section).sort((a, b) => (a.scope < b.scope ? 1 : a.scope > b.scope ? -1 : (b.nearest ?? 0) - (a.nearest ?? 0)));
    L.push('');
    L.push(`### Floating (${fl.length})`);
    L.push('');
    if (fl.length) {
      L.push('| scope | what | parts | where | at | gap to the nearest part | drop to the part under it |');
      L.push('|---|---|---|---|---|---|---|');
      for (const r of fl.slice(0, 120)) {
        L.push(`| ${r.scope}${r.lights ? ', lights' : ''} | ${cell(r.what)}: ${cell(r.names)} | ${r.parts} | ${r.where} | ${at(r.at)} | ${r.nearest === null ? '' : `${round(r.nearest)} to ${cell(r.nearTo)}`} | ${r.drop === null ? 'nothing under it' : `${round(r.drop)} to ${cell(r.over)}`} |`);
      }
    }
    const sm = seams.filter((r) => r.section === section).sort((a, b) => (a.scope < b.scope ? 1 : a.scope > b.scope ? -1 : b.gap - a.gap));
    L.push('');
    L.push(`### Seams (${sm.length})`);
    L.push('');
    if (sm.length) {
      L.push('| scope | between | and | widest gap | where | at |');
      L.push('|---|---|---|---|---|---|');
      for (const r of sm.slice(0, 150)) L.push(`| ${r.scope} | ${cell(r.a)} | ${cell(r.b)} | ${round(r.gap)} | ${r.where} | ${at(r.at)} |`);
    }
    const cl = clips.filter((r) => r.section === section).sort((a, b) => Number(b.through) - Number(a.through) || b.depth - a.depth);
    L.push('');
    L.push(`### Clipping (${cl.length})`);
    L.push('');
    if (cl.length) {
      L.push('| part | sunk into | deepest | pokes through | where | at |');
      L.push('|---|---|---|---|---|---|');
      for (const r of cl.slice(0, 150)) L.push(`| ${cell(r.a)} | ${cell(r.b)} | ${round(r.depth)} | ${r.through ? 'yes' : ''} | ${r.where} | ${at(r.at)} |`);
    }
  }
  if (assetFindings) {
    const byAsset = new Map();
    for (const r of assetFindings) {
      const e = byAsset.get(r.asset) || { asset: r.asset, floating: 0, seams: 0, worstFloat: 0, worstSeam: 0, examples: new Set() };
      if (r.kind === 'floating') {
        e.floating += 1;
        e.worstFloat = Math.max(e.worstFloat, r.nearest ?? 0);
      } else {
        e.seams += 1;
        e.worstSeam = Math.max(e.worstSeam, r.gap);
      }
      if (e.examples.size < 3) e.examples.add(r.names.split(', ')[0]);
      byAsset.set(r.asset, e);
    }
    const rows = [...byAsset.values()].sort((a, b) => b.worstFloat - a.worstFloat || b.worstSeam - a.worstSeam);
    L.push('');
    L.push(`## Inside the model files (${rows.length} of the models in assets/cat-cafe/rbx)`);
    L.push('');
    L.push('Each model on its own at its pivot: pieces joined to nothing that reaches the model\'s base, and open seams between its own faces. `models.csv` has every piece with its position in the model.');
    L.push('');
    L.push('| model | floating pieces | widest float gap | seams | widest seam | e.g. |');
    L.push('|---|---|---|---|---|---|');
    for (const e of rows) L.push(`| ${e.asset} | ${e.floating} | ${e.floating ? round(e.worstFloat) : ''} | ${e.seams} | ${e.seams ? round(e.worstSeam) : ''} | ${cell([...e.examples].join(', '))} |`);
  }
  fs.writeFileSync(path.join(outDir, 'world-scan.md'), L.join('\n') + '\n');
}
