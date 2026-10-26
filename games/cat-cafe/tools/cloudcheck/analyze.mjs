#!/usr/bin/env node
// Strict type check and lint for Purr Pot without luau-lsp installed.
//
//   node analyze.mjs [--project ../../default.project.json] [--tests] [--definitions path] [--all-lints]
//
// Uses the same Luau type checker luau-lsp wraps (via @luau-rs/luau) with the Roblox API
// definitions luau-lsp uses. Differences from the real gate (`./check.sh` on Derek's PC):
//   - `Enum` is typed as `any` (the full enum list is too large for the WebAssembly build).
//   - Instance-path requires are rewritten to module names before checking (luau-lsp uses a
//     sourcemap instead), so unusual require shapes may show as "could not resolve".
//   - `script.Parent.Foo` outside of require() is not typed from the tree; those lines are reported
//     as info, not errors.
// Treat a green run here as a strong hint, and the real gate as the truth.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { Analysis } from '@luau-rs/luau/analysis';
import { buildTree, walk, fullName } from './rojo-tree.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');
const args = parseArgs(process.argv.slice(2));

const projectFile = path.resolve(args.project || path.join(gameRoot, args.tests ? 'tests.project.json' : 'default.project.json'));
const DEFINITIONS_URL = 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau';
const IGNORE = [/^Packages\//, /^ServerPackages\//, /\/Vendor\//, /^tools\//];

// 1. Roblox API definitions (same file check.sh downloads), patched for the WebAssembly checker.
const definitionsPath = resolveDefinitions();
const definitions = patchDefinitions(fs.readFileSync(definitionsPath, 'utf8'));

// The full ENUM_LIST (650+ enums) makes the WebAssembly checker give up with "Code is too complex".
// Keep the enums listed in enum-keep.txt, let any other `Enum.X` through as `any`.
function patchDefinitions(text) {
  const keep = new Set(fs.readFileSync(path.join(here, 'enum-keep.txt'), 'utf8').split(/\s+/).filter(Boolean));
  const out = [];
  let inList = false;
  for (const line of text.split('\n')) {
    if (line.startsWith('--#METADATA#')) continue;
    if (line.startsWith('type ENUM_LIST = {')) { inList = true; out.push(line); continue; }
    if (inList) {
      if (line.startsWith('} & { GetEnums:')) { inList = false; out.push('\t[string]: any,', '}'); continue; }
      const m = /^\t([A-Za-z0-9_]+): /.exec(line);
      if (m && !keep.has(m[1])) continue;
    }
    out.push(line);
  }
  return out.join('\n');
}

const CLASS_NAMES = new Set([...definitions.matchAll(/^declare (?:extern )?(?:type|class) ([A-Za-z0-9_]+)/gm)].map((m) => m[1]));

// 2. Instance tree and module list.
const tree = buildTree(projectFile);
const scripts = [];
for (const node of walk(tree)) {
  if (!node.path || node.json) continue;
  const rel = path.relative(gameRoot, node.path).split(path.sep).join('/');
  if (IGNORE.some((re) => re.test(rel))) continue;
  node.moduleName = rel.replace(/\.luau?$/, '');
  node.rel = rel;
  scripts.push(node);
}

// 3. Rewrite instance-path requires into string requires the checker can follow.
const notes = [];
const TEST_GLOBALS = ['describe', 'describeSKIP', 'xdescribe', 'describeFOCUS', 'fdescribe', 'it', 'itSKIP', 'xit', 'itFOCUS', 'fit', 'beforeEach', 'afterEach', 'beforeAll', 'afterAll', 'expect'];
const analysis = await Analysis.create({ mode: 'strict', lint: true, definitions: [{ name: 'roblox', source: definitions }], globals: args.tests ? TEST_GLOBALS : [] });
for (const node of scripts) {
  const source = fs.readFileSync(node.path, 'utf8');
  const { rewritten: step1, unresolved } = rewriteRequires(source, node);
  const rewritten = castServiceAndInstanceNew(step1);
  for (const text of unresolved) notes.push(`${node.rel}: could not resolve ${text} statically (checked as any)`);
  const kind = node.className === 'ModuleScript' ? 'module' : 'script';
  analysis.setModule(node.moduleName, rewritten, kind);
}

// 4. Check everything and report.
const results = analysis.checkModules(scripts.map((n) => n.moduleName));
let errors = 0;
let warnings = 0;
let infos = 0;
const byModule = new Map(scripts.map((n) => [n.moduleName, n]));
// A check of one module reports diagnostics from everything it requires too, so attribute each
// diagnostic to the module it is in and report each one once.
const seen = new Set();
const grouped = new Map();
const timeouts = new Set();
for (const { result } of results) {
  for (const t of result.timeoutModules) timeouts.add(t);
  for (const d of result.diagnostics) {
    const key = `${d.module}|${d.location.begin.line}|${d.location.begin.column}|${d.message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    if (!grouped.has(d.module)) grouped.set(d.module, []);
    grouped.get(d.module).push(d);
  }
}
for (const node of scripts) {
  const diagnostics = (grouped.get(node.moduleName) || []).sort((a, b) => a.location.begin.line - b.location.begin.line);
  const lines = [];
  for (const d of diagnostics) {
    const where = `${node.rel}:${d.location.begin.line + 1}:${d.location.begin.column + 1}`;
    const severity = classify(d);
    if (severity === 'error') errors++;
    else if (severity === 'warning') warnings++;
    else infos++;
    if (severity === 'info' && !args.allLints) continue;
    lines.push(`  ${severity.toUpperCase().padEnd(7)} ${where}  ${d.message.replace(/\s*\n\s*/g, ' ')}${d.kind === 'lint' ? ` [lint ${d.code}]` : ''}`);
  }
  if (timeouts.has(node.moduleName)) lines.push(`  TIMEOUT ${node.rel}: checker gave up`);
  if (lines.length) {
    console.log(node.rel);
    for (const l of lines) console.log(l);
  }
}
if (notes.length) {
  console.log('');
  console.log('Notes:');
  for (const n of notes) console.log('  ' + n);
}
console.log('');
console.log(`Checked ${scripts.length} script(s) from ${path.relative(gameRoot, projectFile)}: ${errors} type error(s), ${warnings} lint warning(s), ${infos} info (pass --all-lints to list).`);
process.exit(errors > 0 ? 1 : 0);

// --- helpers ---------------------------------------------------------------

// luau-lsp types `Instance.new("Frame")` as Frame and `game:GetService("Players")` as Players through
// built-in "magic functions". The plain checker returns Instance, so add the cast ourselves.
function castServiceAndInstanceNew(source) {
  return source
    // luau-lsp lets `Enum.KeyCode` be used as a type; the checker only knows the EnumKeyCode item type.
    .replace(/\bEnum\.([A-Z][A-Za-z0-9_]*)(?![.\[A-Za-z0-9_])/g, (m, name) => (CLASS_NAMES.has(`Enum${name}`) ? `Enum${name}` : m))
    .replace(/\bInstance\.new\(\s*"([A-Za-z0-9_]+)"\s*\)/g, (m, cls) => (CLASS_NAMES.has(cls) ? `(Instance.new("${cls}") :: ${cls})` : m))
    .replace(/\b(game|Game)\s*:\s*GetService\(\s*"([A-Za-z0-9_]+)"\s*\)/g, (m, g, cls) => (CLASS_NAMES.has(cls) ? `(${g}:GetService("${cls}") :: ${cls})` : m));
}

function classify(d) {
  if (d.kind === 'lint') return d.severity === 'error' ? 'warning' : 'info';
  // Type errors caused by our missing sourcemap typing of script.Parent.X: downgrade to info.
  if (/not found in external type 'Instance'|not found in class 'Instance'/.test(d.message)) return 'info';
  if (/could be nil/.test(d.message) && /Instance\?/.test(d.message)) return 'info';
  return d.severity === 'error' ? 'error' : 'warning';
}

function resolveDefinitions() {
  if (args.definitions) return path.resolve(args.definitions);
  const candidates = [path.join(gameRoot, 'globalTypes.None.d.luau'), path.join(here, '.cache', 'globalTypes.None.d.luau')];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  const target = candidates[1];
  fs.mkdirSync(path.dirname(target), { recursive: true });
  console.log('Downloading Roblox API types for the checker (one time)...');
  const curl = spawnSync('curl', ['-fsSL', '-o', target, DEFINITIONS_URL], { stdio: 'inherit' });
  if (curl.status !== 0 || !fs.existsSync(target)) {
    console.error(`Could not download ${DEFINITIONS_URL}. Pass --definitions <path to globalTypes.None.d.luau>.`);
    process.exit(2);
  }
  return target;
}

// Finds `local Name = <instance path>` aliases and rewrites `require(<instance path>)`.
function rewriteRequires(source, node) {
  const aliases = new Map(); // local name -> instance node
  const unresolved = [];
  const lines = source.split('\n');

  const resolveExpr = (expr) => {
    const segments = parsePath(expr);
    if (!segments) return null;
    let current;
    const [head, ...rest] = segments;
    if (head.type === 'name' && head.value === 'game') current = tree;
    else if (head.type === 'name' && head.value === 'script') current = node;
    else if (head.type === 'name' && head.value === 'workspace') current = tree.children.Workspace || null;
    else if (head.type === 'name' && aliases.has(head.value)) current = aliases.get(head.value);
    else return null;
    for (const seg of rest) {
      if (!current) return null;
      if (seg.type === 'parent') current = parentOf(current);
      else current = current.children[seg.value] || null;
    }
    return current;
  };

  // Pass 1: aliases, in order (so `local Shared = ReplicatedStorage.Shared` chains work).
  for (const line of lines) {
    const m = /^\s*local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$/.exec(line);
    if (!m) continue;
    const target = resolveExpr(m[2]);
    if (target) aliases.set(m[1], target);
  }

  // Pass 2: rewrite require(...) calls.
  let out = '';
  let i = 0;
  while (i < source.length) {
    const idx = source.indexOf('require(', i);
    if (idx === -1) { out += source.slice(i); break; }
    // Make sure it's a standalone identifier.
    const before = idx > 0 ? source[idx - 1] : ' ';
    if (/[A-Za-z0-9_.:]/.test(before)) { out += source.slice(i, idx + 8); i = idx + 8; continue; }
    const close = matchParen(source, idx + 7);
    if (close === -1) { out += source.slice(i); break; }
    const inner = source.slice(idx + 8, close).trim();
    out += source.slice(i, idx);
    if (/^["'`]/.test(inner)) {
      out += source.slice(idx, close + 1);
    } else {
      const target = resolveExpr(inner);
      if (target && target.path && target.moduleName === undefined) {
        target.moduleName = path.relative(gameRoot, target.path).split(path.sep).join('/').replace(/\.luau?$/, '');
      }
      if (target && target.moduleName) {
        out += `require("${target.moduleName}")`;
      } else {
        unresolved.push(`require(${inner})`);
        out += `(require :: any)(nil :: any)`; // typed as any, no error spam
      }
    }
    i = close + 1;
  }
  return { rewritten: out, unresolved };
}

function parentOf(n) {
  for (const candidate of walk(tree)) if (Object.values(candidate.children).includes(n)) return candidate;
  return null;
}

// Parses `game:GetService("X").Shared:WaitForChild("Y").Parent.Z` into segments.
function parsePath(expr) {
  const segments = [];
  const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)/;
  const m = re.exec(expr);
  if (!m) return null;
  segments.push({ type: 'name', value: m[1] });
  let rest = expr.slice(m[0].length);
  while (rest.trim().length) {
    let s;
    if ((s = /^\s*\.\s*Parent\b/.exec(rest))) segments.push({ type: 'parent' });
    else if ((s = /^\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)/.exec(rest))) segments.push({ type: 'child', value: s[1] });
    else if ((s = /^\s*:\s*(GetService|WaitForChild|FindFirstChild)\s*\(\s*(["'])([^"']+)\2\s*\)/.exec(rest))) segments.push({ type: 'child', value: s[3] });
    else if ((s = /^\s*\[\s*(["'])([^"']+)\1\s*\]/.exec(rest))) segments.push({ type: 'child', value: s[2] });
    else return null;
    rest = rest.slice(s[0].length);
  }
  return segments;
}

function matchParen(src, openIdx) {
  let depth = 0;
  let quote = null;
  for (let k = openIdx; k < src.length; k++) {
    const ch = src[k];
    if (quote) { if (ch === '\\') k++; else if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") quote = ch;
    else if (ch === '(') depth++;
    else if (ch === ')') { depth--; if (depth === 0) return k; }
  }
  return -1;
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project') out.project = argv[++i];
    else if (a === '--definitions') out.definitions = argv[++i];
    else if (a === '--tests') out.tests = true;
    else if (a === '--all-lints') out.allLints = true;
    else if (a === '--help' || a === '-h') { console.log('usage: node analyze.mjs [--project file] [--tests] [--definitions path] [--all-lints]'); process.exit(0); }
    else throw new Error(`unknown argument ${a}`);
  }
  return out;
}
