// The UI gate's checks, baseline and report (uigate.mjs). Every number is in real screen pixels, after UIScale.
import fs from 'node:fs';
import path from 'node:path';

// The ui-review skill's three sizes. inset is Roblox's top bar (GuiService:GetGuiInset()).
export const PROFILES = [
  { name: 'desktop', width: 1280, height: 720, touch: false, inset: 58 },
  { name: 'laptop', width: 1366, height: 768, touch: false, inset: 58 },
  { name: 'phone', width: 844, height: 390, touch: true, inset: 58 },
];

// More devices (Derek 2026-11-02: "make sure the ui is fine for all devices"), run on their own with --devices: a tablet held
// sideways (iPad Air, 1180 x 820 points), the smallest phone still sold (iPhone SE, 667 x 375) and a console on a
// 1080p TV, which plays with a gamepad (no tap floor, the mouse one stands in for a cursor).
export const DEVICE_PROFILES = [
  { name: 'tablet', width: 1180, height: 820, touch: true, inset: 58 },
  { name: 'smallphone', width: 667, height: 375, touch: true, inset: 58 },
  { name: 'console', width: 1920, height: 1080, touch: false, inset: 58 },
];

export const LIMITS = {
  tapTouch: 44, // Theme.sizes.touchMin, Apple and Google's own floor
  tapMouse: 36,
  tapSlack: 0.5,
  text: 9, // textTiny 12 at the phone's 0.75 scale
  textSlack: 0.25,
  edge: 2, // px past the screen edge before it counts
  fonts: 2, // Fredoka One and Nunito
  topbarLeft: 184, // Roblox's menu and chat buttons sit left of TopbarInset.Min.X
  overlap: 0.25, // share of the smaller pressable covered by another
};

// gate: fails the run when new; warn: in the report only
const GATED = new Set(['tap', 'text', 'offscreen', 'topbar', 'fonts', 'jitter', 'error']);

function visibleRect(node) {
  let x1 = node.x;
  let y1 = node.y;
  let x2 = node.x + node.w;
  let y2 = node.y + node.h;
  if (node.clip) {
    x1 = Math.max(x1, node.clip[0]);
    y1 = Math.max(y1, node.clip[1]);
    x2 = Math.min(x2, node.clip[2]);
    y2 = Math.min(y2, node.clip[3]);
  }
  if (x2 - x1 <= 0.5 || y2 - y1 <= 0.5) return null;
  return { x1, y1, x2, y2 };
}

function intersect(a, b) {
  const x1 = Math.max(a.x1, b.x1);
  const y1 = Math.max(a.y1, b.y1);
  const x2 = Math.min(a.x2, b.x2);
  const y2 = Math.min(a.y2, b.y2);
  if (x2 - x1 <= 0 || y2 - y1 <= 0) return null;
  return { x1, y1, x2, y2, w: x2 - x1, h: y2 - y1 };
}

const area = (r) => (r.x2 - r.x1) * (r.y2 - r.y1);
const px = (n) => `${Math.round(n * 10) / 10}`;
const label = (node) => (node.text ? ` "${node.text.slice(0, 40)}"` : '');

// Every finding for one scene at one screen size.
export function checkScene(profile, scene) {
  const W = profile.width;
  const H = profile.height;
  const findings = [];
  const add = (check, node, message, where) =>
    findings.push({
      profile: profile.name,
      scene: scene.scene,
      check,
      gated: GATED.has(check),
      path: where ?? (node ? node.path : ''),
      box: node ? [node.x, node.y, node.w, node.h] : null,
      message,
    });

  const screen = { x1: 0, y1: 0, x2: W, y2: H };
  const shown = [];
  for (const node of scene.nodes) {
    const rect = visibleRect(node);
    if (!rect) continue; // scrolled out of its list or clipped away
    shown.push({ node, rect });
  }

  const tapMin = profile.touch ? LIMITS.tapTouch : LIMITS.tapMouse;
  for (const { node, rect } of shown) {
    if (node.press && (node.w < tapMin - LIMITS.tapSlack || node.h < tapMin - LIMITS.tapSlack)) {
      add('tap', node, `${px(node.w)} x ${px(node.h)} px, needs ${tapMin}${label(node)}`);
    }
    if (node.text !== undefined && node.ts < LIMITS.text - LIMITS.textSlack) {
      add('text', node, `text renders at ${px(node.ts)} px, needs ${LIMITS.text}${label(node)}`);
    }
    // a word that runs past its box (TextScaled and wrapped text shrink or break instead)
    if (node.text !== undefined && !node.scaled && !node.trunc) {
      const inner = node.w;
      // glyph widths are averages, so only a clear miss counts
      if (node.tw > inner + 4 && node.tw > inner * 1.15 && !node.wrap) {
        add('fit', node, `text about ${px(node.tw)} px wide in a ${px(inner)} px box${label(node)}`);
      } else if (node.wrap && node.th > node.h + 4 && node.th > node.h * 1.15) {
        add('fit', node, `wrapped text about ${px(node.th)} px tall in a ${px(node.h)} px box${label(node)}`);
      }
    }
    const matters = node.press || node.text !== undefined || node.scroller;
    if (matters) {
      const onScreen = intersect(rect, screen);
      if (onScreen) {
        const past = Math.max(-rect.x1, -rect.y1, rect.x2 - W, rect.y2 - H);
        if (past > LIMITS.edge) add('offscreen', node, `${px(past)} px past the screen edge${label(node)}`);
        const bar = intersect(rect, { x1: 0, y1: 0, x2: LIMITS.topbarLeft, y2: profile.inset });
        // a tap catcher over the whole screen (the rescue bar, the catch circles) is under Roblox's buttons by design:
        // they take their own taps first and every other spot still counts
        const catcher = node.press && !node.text && rect.x1 <= 0 && rect.y1 <= 0 && rect.x2 >= W && rect.y2 >= H;
        if (bar && bar.w > LIMITS.edge && bar.h > LIMITS.edge && !catcher) {
          add('topbar', node, `under Roblox's menu buttons (top left ${LIMITS.topbarLeft} x ${profile.inset})${label(node)}`);
        }
      }
      // fully off-screen is parked (slid out, or waiting to tween in), not broken
    }
  }

  const families = new Map();
  for (const { node } of shown) {
    // an emoji or a symbol draws from the emoji font whatever the label's font
    if (node.text === undefined || !/[\p{L}\p{N}]/u.test(node.text)) continue;
    if (!families.has(node.font)) families.set(node.font, node);
  }
  if (families.size > LIMITS.fonts) {
    const extra = [...families.keys()].filter((f) => f !== 'FredokaOne' && f !== 'Nunito');
    for (const family of extra) {
      add('fonts', families.get(family), `font ${family} on screen besides Fredoka One and Nunito`);
    }
  }

  // pressables on top of each other in the same screen (one may steal the other's taps)
  const presses = shown.filter(({ node }) => node.press);
  for (let i = 0; i < presses.length; i++) {
    for (let j = i + 1; j < presses.length; j++) {
      const a = presses[i];
      const b = presses[j];
      if (a.node.gui !== b.node.gui) continue;
      if (b.node.path.startsWith(a.node.path + '/') || a.node.path.startsWith(b.node.path + '/')) continue;
      const both = intersect(a.rect, b.rect);
      if (!both) continue;
      if (area(both) > LIMITS.overlap * Math.min(area(a.rect), area(b.rect))) {
        add('overlap', b.node, `covers ${a.node.path}${label(a.node)}`);
      }
    }
  }

  // a view that hides Roblox's touch controls (GuiService.TouchControlsEnabled, the Edit lawn view) has none to check
  if (profile.touch && scene.touchControls !== false) {
    // Roblox's own touch controls: thumbstick bottom left; the jump button 70 px at (W-95, H-90) on a small screen
    // (short side 500 or less), else 120 px at (W-170, H-210), as Components/NetButtonPlace.jump has it
    const small = Math.min(W, H) <= 500;
    const jump = small
      ? { x1: W - 95, y1: H - 90, x2: W - 25, y2: H - 20 }
      : { x1: W - 170, y1: H - 210, x2: W - 50, y2: H - 90 };
    const zones = [
      { name: 'the thumbstick', r: { x1: 0, y1: H - 180, x2: 200, y2: H } },
      { name: 'the jump button', r: jump },
    ];
    for (const { node, rect } of presses) {
      for (const zone of zones) {
        const hit = intersect(rect, zone.r);
        if (hit && hit.w > 6 && hit.h > 6) add('thumbs', node, `under ${zone.name}${label(node)}`);
      }
    }
  }

  // a settled screen that keeps changing between the same few values shakes (Derek 2026-10-28, reward rows)
  const boxes = new Map(scene.nodes.map((n) => [n.path, n]));
  for (const j of scene.jitter || []) {
    const owner = boxes.get(j.path) || boxes.get(j.path.split('/').slice(0, -1).join('/')) || null;
    add('jitter', owner, `${j.prop} changed ${j.changes} times in 1 s between ${j.distinct} values`, `${j.path}.${j.prop}`);
  }

  for (const e of scene.errors) {
    if (e.kind === 'error') add('error', null, e.text.split('\n').slice(0, 6).join(' | '));
    else add('warning', null, e.text.split('\n')[0]);
  }
  return findings;
}

const keyOf = (f) => `${f.profile}|${f.scene}|${f.check}|${f.path || f.message.slice(0, 80)}`;

// New findings are the ones over the baseline's count for their key; fixed are baseline keys with fewer now.
// A run limited to one scene cannot tell which earlier window first showed a shared piece (the window frame, the
// HUD behind it), so there a finding the baseline holds under any scene of the same size passes (review N275).
export function compareBaseline(results, baseline, filtered = false) {
  const counts = {};
  const byKey = new Map();
  for (const r of results) {
    for (const f of r.findings) {
      if (!f.gated) continue;
      const key = keyOf(f);
      counts[key] = (counts[key] || 0) + 1;
      if (!byKey.has(key)) byKey.set(key, []);
      byKey.get(key).push(f);
    }
  }
  const accepted = baseline.findings || {};
  const anyScene = new Map();
  for (const [key, count] of Object.entries(accepted)) {
    const [profile, , check, ...rest] = key.split('|');
    const loose = `${profile}|${check}|${rest.join('|')}`;
    anyScene.set(loose, (anyScene.get(loose) || 0) + count);
  }
  const fresh = [];
  for (const [key, list] of byKey) {
    let allowed = accepted[key] || 0;
    if (filtered && allowed === 0) {
      const [profile, , check, ...rest] = key.split('|');
      allowed = anyScene.get(`${profile}|${check}|${rest.join('|')}`) || 0;
    }
    for (const f of list.slice(allowed)) {
      f.fresh = true;
      fresh.push(f);
    }
  }
  const ran = new Set(results.map((r) => `${r.profile.name}|${r.scene}`));
  const fixed = Object.keys(accepted).filter((key) => {
    const [profile, scene] = key.split('|');
    return ran.has(`${profile}|${scene}`) && (counts[key] || 0) < accepted[key];
  });
  const sorted = {};
  for (const key of Object.keys(counts).sort()) sorted[key] = counts[key];
  return { fresh, fixed, counts: sorted };
}

// ---------------------------------------------------------------------------------------------------------------
// Report: index.html with every scene's picture, report.md with the findings

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const FONT_CSS = {
  FredokaOne: "'Fredoka One', 'Fredoka', 'Arial Rounded MT Bold', sans-serif",
  Nunito: "'Nunito', 'Segoe UI', sans-serif",
};

function sceneSvg(profile, result) {
  const W = profile.width;
  const H = profile.height;
  const parts = [
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" font-family="sans-serif">`,
    `<rect width="${W}" height="${H}" fill="#6d8a6a"/>`,
    `<rect width="${LIMITS.topbarLeft}" height="${profile.inset}" fill="#000" fill-opacity="0.35"/>`,
  ];
  if (profile.touch && result.touchControls !== false) {
    parts.push(`<circle cx="100" cy="${H - 90}" r="60" fill="#fff" fill-opacity="0.18"/>`);
    parts.push(`<circle cx="${W - 60}" cy="${H - 55}" r="35" fill="#fff" fill-opacity="0.18"/>`);
  }
  const ordered = [...result.nodes].map((n, i) => ({ n, i })).sort((a, b) => a.n.order - b.n.order || a.i - b.i);
  let clipId = 0;
  for (const { n } of ordered) {
    const r = visibleRect(n);
    if (!r) continue;
    const rw = r.x2 - r.x1;
    const rh = r.y2 - r.y1;
    const rx = n.r ? ` rx="${px(Math.min(n.r, rw / 2, rh / 2))}"` : '';
    const at = `x="${px(r.x1)}" y="${px(r.y1)}" width="${px(rw)}" height="${px(rh)}"${rx}`;
    if (n.bgT < 0.98) parts.push(`<rect ${at} fill="#${n.bg}" fill-opacity="${(1 - n.bgT).toFixed(2)}"/>`);
    // pictures are not downloaded: a tinted box stands in (9-slice faces come out right, icons as a square)
    if (n.image && n.imageT < 0.98) {
      parts.push(
        `<rect ${at} fill="#${n.ic || 'ffffff'}" fill-opacity="${(0.55 * (1 - n.imageT)).toFixed(2)}" stroke="#ffffff" stroke-opacity="0.3" stroke-dasharray="3 3"/>`,
      );
    }
    if (n.bs) {
      parts.push(`<rect ${at} fill="none" stroke="#${n.bs[0]}" stroke-width="${px(n.bs[1])}" stroke-opacity="${n.bs[2]}"/>`);
    }
    if (n.text !== undefined) {
      const anchor = n.tx === 'Left' ? 'start' : n.tx === 'Right' ? 'end' : 'middle';
      const tx = n.tx === 'Left' ? n.x : n.tx === 'Right' ? n.x + n.w : n.x + n.w / 2;
      const clipped = n.clip !== undefined;
      let open = '';
      if (clipped) {
        clipId += 1;
        parts.push(`<clipPath id="c${clipId}"><rect x="${px(r.x1)}" y="${px(r.y1)}" width="${px(rw)}" height="${px(rh)}"/></clipPath>`);
        open = ` clip-path="url(#c${clipId})"`;
      }
      const outline = n.ts2
        ? ` stroke="#${n.ts2[0]}" stroke-width="${px(n.ts2[1] * 2)}" stroke-opacity="${n.ts2[2]}" paint-order="stroke" stroke-linejoin="round"`
        : '';
      parts.push(
        `<text x="${px(tx)}" y="${px(n.y + n.h / 2)}" dominant-baseline="central" text-anchor="${anchor}" font-size="${px(n.ts)}" fill="#${n.tc}" fill-opacity="${n.ta ?? 1}"${outline} style="font-family:${FONT_CSS[n.font] || 'sans-serif'}"${open}>${esc(n.text)}</text>`,
      );
    }
  }
  for (const f of result.findings) {
    if (!f.box) continue;
    const colour = f.gated ? (f.fresh ? '#ff2d2d' : '#ff9a2d') : '#2db6ff';
    const [x, y, w, h] = f.box;
    parts.push(
      `<rect x="${px(x)}" y="${px(y)}" width="${px(Math.max(w, 2))}" height="${px(Math.max(h, 2))}" fill="none" stroke="${colour}" stroke-width="2"><title>${esc(`${f.check}: ${f.path} ${f.message}`)}</title></rect>`,
    );
  }
  parts.push('</svg>');
  return parts.join('\n');
}

export function writeReport(outDir, { results, fresh, fixed, seconds }) {
  const md = [
    '# UI gate report',
    '',
    `${results.length} scenes in ${seconds.toFixed(1)} s. ${fresh.length} new finding(s) fail the gate; baseline findings are listed but pass.`,
    '',
  ];
  if (fixed.length) {
    md.push(`Gone since the baseline (shrink it with --update-baseline): ${fixed.length}`, '');
    for (const key of fixed) md.push(`- ${key}`);
    md.push('');
  }
  const html = [
    '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">',
    '<title>UI gate</title>',
    '<style>body{font-family:system-ui,sans-serif;margin:16px;background:#fdf7ee;color:#3b2a20}h2{margin-top:32px}',
    'img{max-width:100%;border:1px solid #c9b8a6}li.new{color:#c01616;font-weight:600}li.base{color:#9a5a00}li.warn{color:#26627e}',
    '.key{font-size:13px}</style></head><body>',
    '<h1>UI gate</h1>',
    `<p>${results.length} scenes, ${fresh.length} new finding(s). Red: new, fails the gate. Orange: in the baseline. Blue: warning only. Hover a box for its finding.</p>`,
  ];
  for (const result of results) {
    const file = `${result.profile.name}-${result.scene}.svg`;
    fs.writeFileSync(path.join(outDir, file), sceneSvg(result.profile, result));
    const title = `${result.scene} at ${result.profile.name} (${result.profile.width} x ${result.profile.height})`;
    md.push(`## ${title}`, '');
    html.push(`<h2>${esc(title)}</h2><img src="${file}" alt="${esc(title)}">`);
    if (result.findings.length === 0) {
      md.push('Nothing found.', '');
      continue;
    }
    html.push('<ul class="key">');
    for (const f of result.findings) {
      const kind = !f.gated ? 'warn' : f.fresh ? 'new' : 'base';
      const tag = kind === 'new' ? 'NEW' : kind === 'base' ? 'baseline' : 'warning';
      md.push(`- **${f.check}** (${tag}) \`${f.path}\`: ${f.message}`);
      html.push(`<li class="${kind}"><b>${esc(f.check)}</b> ${esc(f.path)}: ${esc(f.message)}</li>`);
    }
    md.push('');
    html.push('</ul>');
  }
  html.push('</body></html>');
  fs.writeFileSync(path.join(outDir, 'report.md'), md.join('\n') + '\n');
  fs.writeFileSync(path.join(outDir, 'index.html'), html.join('\n') + '\n');
  fs.writeFileSync(
    path.join(outDir, 'findings.json'),
    JSON.stringify(results.flatMap((r) => r.findings), null, 1) + '\n',
  );
}
