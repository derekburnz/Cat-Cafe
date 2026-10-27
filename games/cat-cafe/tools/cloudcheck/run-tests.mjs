#!/usr/bin/env node
// Runs the Cat Cafe TestKit specs without Roblox Studio.
//
//   node run-tests.mjs [--project ../../tests.project.json] [--filter Economy] [--verbose] [--json out.json] [--shared]
//
// How it works: rojo-tree.mjs turns the Rojo project into a fake instance tree, roblox-shim.luau
// wraps it in Instance-like proxies and adds a few Roblox globals, and every ModuleScript is loaded
// with its own environment (script, require) so `require(script.Parent.X)` resolves to files on disk.
// Then it calls tests/StudioRunner.luau exactly as Studio would.
//
// Each spec file runs in its own fresh Luau state (README, "One Luau state per spec file"): one shared
// state for the whole suite hit a fault in the WebAssembly Luau build once the suite grew past a size,
// failing tests that pass on their own. --shared runs everything in one state, the old way, to reproduce it.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Lua } from '@luau-rs/luau';
import { buildTree, walk, findByPath, fullName, jsonToLuau } from './rojo-tree.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const gameRoot = path.resolve(here, '..', '..');

const args = parseArgs(process.argv.slice(2));
const projectFile = path.resolve(args.project || path.join(gameRoot, 'tests.project.json'));
const verbose = Boolean(args.verbose);

const tree = buildTree(projectFile);
const nodesById = new Map();
for (const node of walk(tree)) nodesById.set(node.id, node);

const shimSource = fs.readFileSync(path.join(here, 'roblox-shim.luau'), 'utf8');
const studioOnly = []; // modules that hit a shim limit

// A fresh Luau state with the shim loaded and its own module cache.
async function createState() {
  const lua = await Lua.create({ sandbox: false, libraries: 'all' });
  lua.globals.set('print', lua.createFunction((...parts) => console.log(parts.map(String).join(' '))));

  const moduleCache = new Map(); // node id -> returned value
  const loading = new Set();

  function requireNode(nodeId) {
    const node = nodesById.get(nodeId);
    if (!node) throw new Error(`require: unknown module id ${nodeId}`);
    if (moduleCache.has(nodeId)) return moduleCache.get(nodeId);
    if (loading.has(nodeId)) {
      throw new Error(`Requested module was required recursively: ${fullName(tree, node)}`);
    }
    if (!node.path) throw new Error(`require: ${fullName(tree, node)} has no source file`);
    loading.add(nodeId);
    try {
      let source = fs.readFileSync(node.path, 'utf8');
      if (node.json) source = jsonToLuau(source);
      const env = makeEnv.call(nodeId)[0];
      const chunkName = path.relative(gameRoot, node.path).split(path.sep).join('/');
      const fn = lua.load(source, { name: chunkName, environment: env });
      const results = fn.call();
      if (results.length === 0 || results[0] === undefined || results[0] === null) {
        throw new Error(`Module code did not return exactly one value: ${fullName(tree, node)}`);
      }
      moduleCache.set(nodeId, results[0]);
      return results[0];
    } catch (error) {
      const message = String(error && error.message ? error.message : error);
      if (/not available in cloud tests|Studio-only/.test(message)) studioOnly.push(fullName(tree, node));
      throw error;
    } finally {
      loading.delete(nodeId);
    }
  }

  const hostRequire = lua.createFunction((nodeId) => requireNode(String(nodeId)));
  const shim = lua.load(shimSource, { name: 'roblox-shim' }).call(tree, hostRequire)[0];
  const makeEnv = shim.rawGet('makeEnv');
  const getProxy = shim.rawGet('getProxy');
  return { lua, requireNode, getProxy };
}

const testsNode = findByPath(tree, ['ReplicatedStorage', 'Tests']);
if (!testsNode) {
  console.error(`No ReplicatedStorage.Tests in ${projectFile}. Use tests.project.json.`);
  process.exit(2);
}
const runnerNode = testsNode.children.StudioRunner;
if (!runnerNode) {
  console.error('tests/StudioRunner.luau is missing.');
  process.exit(2);
}

// Spec files in the order StudioRunner sorts them (by full name), filtered by name like StudioRunner's filter.
const specNames = [];
for (const node of walk(testsNode)) {
  if (node.className === 'ModuleScript' && node.name.endsWith('.spec')) {
    specNames.push({ name: node.name, full: fullName(tree, node) });
  }
}
specNames.sort((a, b) => (a.full < b.full ? -1 : a.full > b.full ? 1 : 0));
const selected = specNames
  .filter((spec) => args.filter == null || spec.name.includes(args.filter))
  .map((spec) => spec.name);

// Runs StudioRunner in a fresh state. `only` names one spec file exactly; nil runs every spec matching the filter.
async function runInFreshState(only, print) {
  const state = await createState();
  const runner = state.requireNode(runnerNode.id);
  const options = state.lua.createTable({
    verbose,
    filter: only ?? args.filter ?? null,
    exact: only != null,
    print: print ? state.lua.createFunction((line) => print(String(line))) : null,
  });
  const summary = runner.call(state.getProxy.call(testsNode.id)[0], options)[0];
  return {
    passed: Number(summary.rawGet('passed')),
    failed: Number(summary.rawGet('failed')),
    skipped: Number(summary.rawGet('skipped')),
    seconds: Number(summary.rawGet('durationSeconds')),
    failures: summary.rawGet('failures').toArray().map((entry) => ({
      path: String(entry.rawGet('path')),
      message: String(entry.rawGet('message') ?? ''),
    })),
  };
}

const probe = await Lua.create({ sandbox: false, libraries: 'all' });
console.log(`Cat Cafe cloud tests (Luau ${probe.version}) using ${path.relative(gameRoot, projectFile)}`);

let total;
try {
  if (args.shared) {
    total = await runInFreshState(null, null);
  } else {
    total = { passed: 0, failed: 0, skipped: 0, seconds: 0, failures: [] };
    console.log(`TestKit: running ${selected.length} spec file(s), one Luau state each`);
    for (const name of selected) {
      // Keep each run's per-test lines; the header, failure list and totals are printed once for the suite.
      let listing = true;
      const result = await runInFreshState(name, (line) => {
        if (line.startsWith('TestKit: running ')) return;
        if (line === 'Failures:' || line.startsWith('Tests: ')) listing = false;
        if (listing && line !== '') console.log(line);
      });
      if (result.passed + result.failed + result.skipped === 0 && result.failures.length === 0) {
        console.log(`  (no tests ran in ${name})`);
      }
      total.passed += result.passed;
      total.failed += result.failed;
      total.skipped += result.skipped;
      total.seconds += result.seconds;
      total.failures.push(...result.failures);
    }
    if (total.failures.length > 0) {
      console.log('');
      console.log('Failures:');
      total.failures.forEach((failure, index) => {
        console.log(`${index + 1}) ${failure.path}`);
        console.log('   ' + (failure.message || '(no message)').replaceAll('\n', '\n   '));
      });
    }
    console.log('');
    console.log(
      `Tests: ${total.passed} passed, ${total.failed} failed, ${total.skipped} skipped (${total.seconds.toFixed(2)}s)`
    );
  }
} catch (error) {
  console.error('Test run crashed:', error && error.message ? error.message : error);
  process.exit(2);
}

const { passed, failed, skipped, failures } = total;

if (studioOnly.length > 0) {
  console.log('');
  console.log('Studio-only modules (hit a Roblox API the cloud shim does not have):');
  for (const name of [...new Set(studioOnly)]) console.log('  - ' + name);
}

if (args.json) {
  const report = {
    projectFile,
    luauVersion: probe.version,
    passed,
    failed,
    skipped,
    failures,
    studioOnly: [...new Set(studioOnly)],
    isolated: !args.shared,
    ranAt: new Date().toISOString(),
  };
  fs.writeFileSync(path.resolve(args.json), JSON.stringify(report, null, 2));
  console.log(`JSON report written to ${args.json}`);
}

process.exit(failed > 0 ? 1 : 0);

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--verbose' || arg === '-v') out.verbose = true;
    else if (arg === '--project') out.project = argv[++i];
    else if (arg === '--filter') out.filter = argv[++i];
    else if (arg === '--json') out.json = argv[++i];
    else if (arg === '--shared') out.shared = true;
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node run-tests.mjs [--project file] [--filter text] [--verbose] [--json out.json] [--shared]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
