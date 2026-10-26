#!/usr/bin/env node
// Runs the Purr Pot TestKit specs without Roblox Studio.
//
//   node run-tests.mjs [--project ../../tests.project.json] [--filter Economy] [--verbose] [--json out.json]
//
// How it works: rojo-tree.mjs turns the Rojo project into a fake instance tree, roblox-shim.luau
// wraps it in Instance-like proxies and adds a few Roblox globals, and every ModuleScript is loaded
// with its own environment (script, require) so `require(script.Parent.X)` resolves to files on disk.
// Then it calls tests/StudioRunner.luau exactly as Studio would.
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

const lua = await Lua.create({ sandbox: false, libraries: 'all' });
lua.globals.set('print', lua.createFunction((...parts) => console.log(parts.map(String).join(' '))));

const moduleCache = new Map(); // node id -> returned value
const loading = new Set();
const studioOnly = []; // modules that hit a shim limit

const hostRequire = lua.createFunction((nodeId) => requireNode(String(nodeId)));
const shimSource = fs.readFileSync(path.join(here, 'roblox-shim.luau'), 'utf8');
const shim = lua.load(shimSource, { name: 'roblox-shim' }).call(tree, hostRequire)[0];
const makeEnv = shim.rawGet('makeEnv');
const getProxy = shim.rawGet('getProxy');

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

console.log(`Purr Pot cloud tests (Luau ${lua.version}) using ${path.relative(gameRoot, projectFile)}`);
let summary;
try {
  const runner = requireNode(runnerNode.id);
  const options = lua.createTable({ verbose, filter: args.filter ?? null });
  summary = runner.call(getProxy.call(testsNode.id)[0], options)[0];
} catch (error) {
  console.error('Test run crashed:', error && error.message ? error.message : error);
  process.exit(2);
}

const passed = Number(summary.rawGet('passed'));
const failed = Number(summary.rawGet('failed'));
const skipped = Number(summary.rawGet('skipped'));
const failures = summary.rawGet('failures').toArray().map((entry) => ({
  path: String(entry.rawGet('path')),
  message: String(entry.rawGet('message') ?? ''),
}));

if (studioOnly.length > 0) {
  console.log('');
  console.log('Studio-only modules (hit a Roblox API the cloud shim does not have):');
  for (const name of [...new Set(studioOnly)]) console.log('  - ' + name);
}

if (args.json) {
  const report = { projectFile, luauVersion: lua.version, passed, failed, skipped, failures, studioOnly: [...new Set(studioOnly)], ranAt: new Date().toISOString() };
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
    else if (arg === '--help' || arg === '-h') {
      console.log('usage: node run-tests.mjs [--project file] [--filter text] [--verbose] [--json out.json]');
      process.exit(0);
    } else throw new Error(`unknown argument ${arg}`);
  }
  return out;
}
