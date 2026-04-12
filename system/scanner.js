const fs = require("fs");
const path = require("path");

// ── Directorios que nunca deben escanearse ──────────────────────────────────
const SKIP_DIRS = new Set([
  "android", ".git", ".godot", "addons", "node_modules",
  "system", ".import", "export_presets"
]);

// ── Regex para análisis semántico de GDScript ──────────────────────────────
const RE = {
  class_name:  /^class_name\s+(\w+)/m,
  extends:     /^extends\s+(\S+)/m,
  signals:     /^signal\s+(\w+)(?:\(([^)]*)\))?/gm,
  vars:        /^(?:@export\s+)?var\s+(\w+)\s*(?::\s*(\w+))?\s*(?:=\s*(.+))?/gm,
  consts:      /^const\s+(\w+)\s*(?::=|=)\s*(.+)/gm,
  funcs:       /^func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*(\S+))?/gm,
  preloads:    /(?:preload|load)\s*\(\s*["']([^"']+\.(?:gd|tscn|tres))["']\s*\)/gm,
  autoloads:   /\b(GameManager|GameState|VoyageManager|GpsService|Supabase|SupabaseConfig)\b/g,
  onready:     /@onready\s+var\s+(\w+)\s*(?::\s*\w+)?\s*=\s*(?:\$|get_node\s*\()["']?([^"'\n]+?)["']?\)?/gm,
  node_refs:   /\$["']?([A-Za-z0-9_\/]+)["']?/g,
  class_inst:  /(?:var\s+\w+\s*(?::\s*(\w+))?\s*=\s*(\w+)\.new\(\)|:\s*(\w+)\s*=)/gm,
  enums:       /^enum\s+(\w+)\s*\{([^}]+)\}/gm,
  groups:      /add_to_group\s*\(\s*["']([^"']+)["']\s*\)/gm,
  connects:    /\.connect\s*\(\s*["']([^"']+)["']/gm,
  emits:       /emit_signal\s*\(\s*["']([^"']+)["']|\.emit\s*\(/gm,
};

// ── Parser de un archivo .gd ───────────────────────────────────────────────
function parseGDScript(filePath, content) {
  const rel = filePath;

  const extract = (re, content) => {
    const results = [];
    let m;
    const regex = new RegExp(re.source, re.flags);
    while ((m = regex.exec(content)) !== null) results.push(m);
    return results;
  };

  // Extraer funciones con línea de inicio
  const funcs = [];
  const lines = content.split("\n");
  lines.forEach((line, i) => {
    const m = line.match(/^func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*(\S+))?/);
    if (m) funcs.push({ name: m[1], params: m[2].trim(), returns: m[3] || "void", line: i + 1 });
  });

  // Extraer vars de estado real (primeras 60 líneas para vars de estado global)
  const stateVars = [];
  lines.slice(0, 80).forEach((line, i) => {
    const m = line.match(/^(?:@export\s+)?var\s+(\w+)\s*(?::\s*(\w+))?\s*(?:=\s*(.+))?/);
    if (m) stateVars.push({
      name: m[1],
      type: m[2] || null,
      default: m[3] ? m[3].trim().slice(0, 60) : null,
      line: i + 1
    });
  });

  // Signals
  const signals = extract(RE.signals, content).map(m => ({
    name: m[1],
    params: m[2] ? m[2].split(",").map(p => p.trim()).filter(Boolean) : []
  }));

  // Preloads → dependencias directas
  const preloads = extract(RE.preloads, content).map(m => m[1]);

  // Referencias a autoloads → dependencias implícitas
  const autoloadRefs = [...new Set(
    extract(RE.autoloads, content).map(m => m[1])
  )];

  // @onready nodes
  const onready = extract(RE.onready, content).map(m => ({
    varName: m[1], nodePath: m[2]
  }));

  // Grupos
  const groups = [...new Set(extract(RE.groups, content).map(m => m[1]))];

  // Signals que se conectan (para el grafo de señales)
  const connects = extract(RE.connects, content).map(m => m[1]);

  // Signals que se emiten
  const emits = extract(RE.emits, content).map(m => m[1]).filter(Boolean);

  // Enums
  const enums = extract(RE.enums, content).map(m => ({
    name: m[1],
    values: m[2].split(",").map(v => v.trim().split("=")[0].trim()).filter(Boolean)
  }));

  // Consts
  const consts = [];
  lines.slice(0, 30).forEach((line) => {
    const m = line.match(/^const\s+(\w+)\s*(?::=|=)\s*(.+)/);
    if (m) consts.push({ name: m[1], value: m[2].trim().slice(0, 80) });
  });

  const classNameMatch = content.match(RE.class_name);
  const extendsMatch   = content.match(RE.extends);

  return {
    path:        rel,
    class_name:  classNameMatch ? classNameMatch[1] : null,
    extends:     extendsMatch   ? extendsMatch[1]   : null,
    signals,
    funcs,
    stateVars,
    consts,
    enums,
    groups,
    preloads,
    autoloadRefs,
    onready,
    connects,
    emits,
    loc: lines.length,
    // Snapshot legible para el LLM (500 chars)
    summary: content.slice(0, 500).replace(/\t/g, "  ")
  };
}

// ── Parser de un archivo .tscn ─────────────────────────────────────────────
function parseTSCN(filePath, content) {
  const scripts = [];
  const extResRe = /\[ext_resource[^\]]+path="([^"]+\.gd)"[^\]]*\]/g;
  let m;
  while ((m = extResRe.exec(content)) !== null) scripts.push(m[1]);

  const nodeRe = /\[node name="([^"]+)" type="([^"]+)"(?:[^\]]*parent="([^"]+)")?\]/g;
  const nodes = [];
  while ((m = nodeRe.exec(content)) !== null) {
    nodes.push({ name: m[1], type: m[2], parent: m[3] || null });
  }

  const subResRe = /\[sub_resource type="([^"]+)"/g;
  const subResources = [];
  while ((m = subResRe.exec(content)) !== null) subResources.push(m[1]);

  return {
    path:        filePath,
    type:        "scene",
    scripts,
    nodes,
    subResources,
    summary:     content.slice(0, 300)
  };
}

// ── Scan recursivo ignorando carpetas bloqueadas ───────────────────────────
function scanDir(dir, fileList = []) {
  let entries;
  try { entries = fs.readdirSync(dir); } catch { return fileList; }

  for (const file of entries) {
    if (SKIP_DIRS.has(file)) continue;
    const fullPath = path.join(dir, file);
    let stat;
    try { stat = fs.statSync(fullPath); } catch { continue; }

    if (stat.isDirectory()) {
      scanDir(fullPath, fileList);
    } else if (file.endsWith(".gd") || file.endsWith(".tscn")) {
      fileList.push(fullPath);
    }
  }
  return fileList;
}

// ── Construir grafo de dependencias entre scripts ─────────────────────────
function buildDepGraph(index) {
  // Mapa rápido: basename sin ext → path relativo completo
  const pathMap = {};
  for (const entry of index) {
    if (entry.type === "scene") continue;
    const base = path.basename(entry.path, ".gd").toLowerCase();
    pathMap[base] = entry.path;
    if (entry.class_name) pathMap[entry.class_name.toLowerCase()] = entry.path;
  }

  // ── Construir mapa inverso: qué scripts están vinculados a qué escenas ──
  // Las escenas referencian scripts via ext_resource path="res://scripts/foo.gd"
  // Esto evita falsos positivos de "scripts aislados" en detectIsolatedScripts
  const scriptToScenes = {};   // scriptPath → [scenePath, ...]
  for (const entry of index) {
    if (entry.type !== "scene") continue;
    for (const scriptRef of (entry.scripts || [])) {
      // scriptRef es algo como "res://scripts/gps_map.gd" o "scripts/gps_map.gd"
      const normalized = scriptRef
        .replace(/^res:\/\//, "")   // quitar prefijo res://
        .replace(/\\/g, "/");
      const base = path.basename(normalized, ".gd").toLowerCase();
      // Buscar el path real en el index
      const realPath = pathMap[base];
      if (realPath) {
        if (!scriptToScenes[realPath]) scriptToScenes[realPath] = [];
        scriptToScenes[realPath].push(entry.path);
      }
    }
  }

  const graph = {};
  for (const entry of index) {
    if (entry.type === "scene") continue;
    const deps = new Set();

    // Preloads directos
    for (const p of (entry.preloads || [])) {
      const base = path.basename(p, ".gd").toLowerCase();
      if (pathMap[base]) deps.add(pathMap[base]);
    }

    // Autoloads referenciados
    for (const a of (entry.autoloadRefs || [])) {
      const key = a.toLowerCase();
      if (pathMap[key]) deps.add(pathMap[key]);
    }

    graph[entry.path] = {
      deps:        [...deps],
      signals:     (entry.signals  || []).map(s => s.name),
      connects:    entry.connects  || [],
      emits:       entry.emits     || [],
      groups:      entry.groups    || [],
      class_name:  entry.class_name,
      // escenas que vinculan este script — clave para detectIsolatedScripts
      usedByScenes: scriptToScenes[entry.path] || [],
    };
  }
  return graph;
}

// ── Entry point ───────────────────────────────────────────────────────────
function buildIndex(projectDir) {
  const baseDir = projectDir || process.cwd();
  const files   = scanDir(baseDir);

  const index = [];

  for (const file of files) {
    let content;
    try { content = fs.readFileSync(file, "utf-8"); } catch { continue; }

    const rel = file.replace(baseDir + path.sep, "").replace(/\\/g, "/");

    if (file.endsWith(".gd")) {
      index.push(parseGDScript(rel, content));
    } else if (file.endsWith(".tscn")) {
      index.push(parseTSCN(rel, content));
    }
  }

  const depGraph = buildDepGraph(index);

  const output = { index, depGraph, scannedAt: new Date().toISOString() };

  fs.mkdirSync("system", { recursive: true });
  fs.writeFileSync("system/project_index.json", JSON.stringify(output, null, 2));

  const gdCount   = index.filter(f => f.type !== "scene").length;
  const tscnCount = index.filter(f => f.type === "scene").length;
  console.log(`📦 Proyecto indexado: ${gdCount} scripts, ${tscnCount} escenas`);
  console.log(`🔗 Grafo de dependencias: ${Object.keys(depGraph).length} nodos`);

  return output;
}

// ── Utilidad: leer index ya construido ────────────────────────────────────
function loadIndex() {
  if (!fs.existsSync("system/project_index.json")) return null;
  return JSON.parse(fs.readFileSync("system/project_index.json", "utf-8"));
}

module.exports = { buildIndex, loadIndex, parseGDScript, parseTSCN, buildDepGraph };
