// Builds a fake Roblox instance tree from a Rojo project file.
// Each node: { id, name, className, path?, children: { [name]: node } }
// `path` is the absolute file path for scripts; `id` is a stable string used by the shim.
import fs from 'node:fs';
import path from 'node:path';

const SCRIPT_CLASS = [
  [/\.server\.luau?$/, 'Script'],
  [/\.client\.luau?$/, 'LocalScript'],
  [/\.luau?$/, 'ModuleScript'],
];

export function buildTree(projectFile) {
  const projectDir = path.dirname(projectFile);
  const project = JSON.parse(fs.readFileSync(projectFile, 'utf8'));
  const ignore = (project.globIgnorePaths || []).map(globToRegex);
  const root = instanceFromProjectNode(project.name || 'game', project.tree, projectDir, ignore, 'game');
  if (!root.className) root.className = 'DataModel';
  return root;
}

function globToRegex(glob) {
  // Supports ** and * only, enough for Rojo's typical ignore lists.
  const escaped = glob.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*\*\//g, '(?:.*/)?').replace(/\*\*/g, '.*').replace(/\*/g, '[^/]*');
  return new RegExp('^' + escaped + '$');
}

function isIgnored(relPath, ignore) {
  return ignore.some((re) => re.test(relPath) || re.test(path.basename(relPath)));
}

function instanceFromProjectNode(name, node, projectDir, ignore, id) {
  const inst = { id, name, className: node.$className || null, children: {} };
  if (node.$path !== undefined) {
    // Rojo spells an optional path as { "optional": "dir" }; the older { optional: true, path } form is accepted too.
    const spec =
      typeof node.$path === 'string'
        ? { path: node.$path, optional: false }
        : typeof node.$path.optional === 'string'
          ? { path: node.$path.optional, optional: true }
          : { path: node.$path.path, optional: Boolean(node.$path.optional) };
    const target = path.resolve(projectDir, spec.path);
    if (fs.existsSync(target)) {
      const fromDisk = instanceFromPath(name, target, ignore, id);
      inst.className = inst.className || fromDisk.className;
      inst.path = fromDisk.path;
      Object.assign(inst.children, fromDisk.children);
    } else if (!spec.optional) {
      throw new Error(`Rojo $path does not exist: ${target}`);
    }
  }
  for (const [key, child] of Object.entries(node)) {
    if (key.startsWith('$')) continue;
    inst.children[key] = instanceFromProjectNode(key, child, projectDir, ignore, `${id}/${key}`);
  }
  if (!inst.className) inst.className = 'Folder';
  return inst;
}

function instanceFromPath(name, target, ignore, id) {
  const stat = fs.statSync(target);
  if (stat.isFile()) {
    return fileInstance(name, target, id);
  }
  // Directory: Folder unless it has init.luau (then it is a ModuleScript) or a nested project file.
  const inst = { id, name, className: 'Folder', children: {} };
  const entries = fs.readdirSync(target, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    const full = path.join(target, entry.name);
    const rel = path.relative(path.dirname(target), full).split(path.sep).join('/');
    if (isIgnored(rel, ignore) || isIgnored(entry.name, ignore)) continue;
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
      inst.children[entry.name] = instanceFromPath(entry.name, full, ignore, `${id}/${entry.name}`);
      continue;
    }
    const initMatch = /^init(\.server|\.client)?\.luau?$/.exec(entry.name);
    if (initMatch) {
      inst.className = initMatch[1] === '.server' ? 'Script' : initMatch[1] === '.client' ? 'LocalScript' : 'ModuleScript';
      inst.path = full;
      continue;
    }
    if (/\.meta\.json$/.test(entry.name) || /\.project\.json$/.test(entry.name)) continue;
    const child = fileInstance(null, full, null);
    if (!child) continue;
    child.id = `${id}/${child.name}`;
    inst.children[child.name] = child;
  }
  return inst;
}

function fileInstance(forcedName, full, id) {
  const base = path.basename(full);
  for (const [re, className] of SCRIPT_CLASS) {
    if (re.test(base)) {
      const name = forcedName || base.replace(re, '');
      return { id: id || name, name, className, path: full, children: {} };
    }
  }
  if (/\.json$/.test(base)) {
    const name = forcedName || base.replace(/\.json$/, '');
    return { id: id || name, name, className: 'ModuleScript', path: full, json: true, children: {} };
  }
  if (/\.txt$/.test(base)) {
    const name = forcedName || base.replace(/\.txt$/, '');
    return { id: id || name, name, className: 'StringValue', path: full, children: {} };
  }
  if (/\.rbxmx?$/.test(base)) {
    const name = forcedName || base.replace(/\.rbxmx?$/, '');
    return { id: id || name, name, className: 'Model', children: {} };
  }
  return null;
}

export function* walk(node) {
  yield node;
  for (const child of Object.values(node.children)) yield* walk(child);
}

export function findByPath(root, segments) {
  let current = root;
  for (const segment of segments) {
    current = current.children[segment];
    if (!current) return null;
  }
  return current;
}

export function fullName(root, node) {
  const parts = [];
  let found = false;
  (function visit(current, trail) {
    if (found) return;
    if (current === node) { parts.push(...trail); found = true; return; }
    for (const [name, child] of Object.entries(current.children)) visit(child, [...trail, name]);
  })(root, []);
  return parts.join('.');
}

// Converts a JSON data file into Luau source that returns the same value (Rojo's .json ModuleScript rule).
export function jsonToLuau(text) {
  const value = JSON.parse(text);
  const lua = (v) => {
    if (v === null) return 'nil';
    if (typeof v === 'string') return JSON.stringify(v);
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    if (Array.isArray(v)) return '{' + v.map(lua).join(', ') + '}';
    return '{' + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}] = ${lua(x)}`).join(', ') + '}';
  };
  return 'return ' + lua(value);
}
