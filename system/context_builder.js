const fs   = require("fs");
const path = require("path");
const { loadIndex } = require("./scanner");

// ── Tokens de relevancia semántica ────────────────────────────────────────
// Cuánto peso tiene cada tipo de coincidencia al rankear archivos para un task
const RELEVANCE_WEIGHTS = {
  path_keyword:    10,   // el nombre del archivo está en el task
  class_keyword:    9,   // la class_name está en el task
  func_keyword:     7,   // una función del archivo está en el task
  signal_keyword:   6,   // una signal del archivo está en el task
  var_keyword:      4,   // una variable de estado está en el task
  dep_of_relevant:  5,   // es dependencia directa de un archivo ya relevante
  autoload_ref:     8,   // es un autoload (siempre relevante como contexto base)
  is_autoload:      9,   // ES un autoload declarado
  extends_match:    6,   // extends una clase mencionada en el task
};

// Autoloads conocidos del proyecto (siempre incluir como base)
const KNOWN_AUTOLOADS = new Set([
  "game_manager", "gamemanager",
  "gamestate",    "game_state",
  "voyagemanager","voyage_manager",
  "gpsservice",   "gps_service",
  "supabase",
  "supabaseconfig","supabase_config",
]);

// ── Tokenizar task a palabras útiles ──────────────────────────────────────
function tokenizeTask(task) {
  return task
    .toLowerCase()
    .replace(/[^a-z0-9_\s]/g, " ")
    .split(/\s+/)
    .filter(t => t.length > 2);
}

// ── Score de relevancia de un entry contra el task ────────────────────────
function scoreEntry(entry, taskTokens, depGraph) {
  let score = 0;
  const notes = [];

  const entryTokens = [
    path.basename(entry.path, ".gd").toLowerCase(),
    path.basename(entry.path, ".tscn").toLowerCase(),
    (entry.class_name || "").toLowerCase(),
    ...(entry.funcs    || []).map(f => f.name.toLowerCase()),
    ...(entry.signals  || []).map(s => s.name.toLowerCase()),
    ...(entry.stateVars|| []).map(v => v.name.toLowerCase()),
    ...(entry.groups   || []).map(g => g.toLowerCase()),
  ];

  const basename = path.basename(entry.path, ".gd").toLowerCase();

  // Autoload base — siempre presentes en el contexto
  if (KNOWN_AUTOLOADS.has(basename) || KNOWN_AUTOLOADS.has((entry.class_name || "").toLowerCase())) {
    score += RELEVANCE_WEIGHTS.is_autoload;
    notes.push("autoload");
  }

  // Coincidencias de tokens del task con tokens del entry
  for (const t of taskTokens) {
    if (basename.includes(t) || t.includes(basename)) {
      score += RELEVANCE_WEIGHTS.path_keyword;
      notes.push(`path:${t}`);
    }
    if (entry.class_name && entry.class_name.toLowerCase().includes(t)) {
      score += RELEVANCE_WEIGHTS.class_keyword;
      notes.push(`class:${t}`);
    }
    for (const et of entryTokens) {
      if (et.length > 3 && et.includes(t)) {
        score += 2;
      }
    }
    if ((entry.extends || "").toLowerCase().includes(t)) {
      score += RELEVANCE_WEIGHTS.extends_match;
      notes.push(`extends:${t}`);
    }
  }

  // Señales relevantes al task
  for (const s of (entry.signals || [])) {
    for (const t of taskTokens) {
      if (s.name.toLowerCase().includes(t)) {
        score += RELEVANCE_WEIGHTS.signal_keyword;
        notes.push(`signal:${s.name}`);
      }
    }
  }

  // Funciones relevantes al task
  for (const f of (entry.funcs || [])) {
    for (const t of taskTokens) {
      if (f.name.toLowerCase().includes(t)) {
        score += RELEVANCE_WEIGHTS.func_keyword;
        notes.push(`func:${f.name}`);
      }
    }
  }

  return { score, notes };
}

// ── Expandir selección con dependencias directas ──────────────────────────
function expandWithDeps(selected, allEntries, depGraph, budget) {
  const selectedPaths = new Set(selected.map(e => e.path));
  const extras = [];

  for (const entry of selected) {
    const node = depGraph[entry.path];
    if (!node) continue;
    for (const dep of node.deps) {
      if (selectedPaths.has(dep)) continue;
      const depEntry = allEntries.find(e => e.path === dep);
      if (depEntry) {
        extras.push({ entry: depEntry, score: RELEVANCE_WEIGHTS.dep_of_relevant });
        selectedPaths.add(dep);
      }
    }
  }

  // Ordenar extras por score y respetar budget
  extras.sort((a, b) => b.score - a.score);
  const available = budget - selected.length;
  return extras.slice(0, available).map(e => e.entry);
}

// ── Serializar un entry como bloque de contexto para el LLM ──────────────
function serializeEntry(entry, depGraph, verbose = false) {
  if (entry.type === "scene") {
    return [
      `=== SCENE: ${entry.path} ===`,
      `Scripts vinculados: ${(entry.scripts || []).join(", ") || "ninguno"}`,
      `Nodos raíz: ${(entry.nodes || []).slice(0, 8).map(n => `${n.name}(${n.type})`).join(", ")}`,
    ].join("\n");
  }

  const node = depGraph[entry.path] || {};
  const lines = [
    `=== SCRIPT: ${entry.path} ===`,
    entry.class_name ? `class_name: ${entry.class_name}` : null,
    entry.extends    ? `extends: ${entry.extends}`        : null,
  ].filter(Boolean);

  if ((entry.signals || []).length) {
    lines.push(`signals: ${entry.signals.map(s =>
      s.params.length ? `${s.name}(${s.params.join(",")})` : s.name
    ).join(" | ")}`);
  }

  if ((entry.stateVars || []).length) {
    const varsStr = entry.stateVars.slice(0, 12).map(v => {
      const t = v.type ? `: ${v.type}` : "";
      const d = v.default ? ` = ${v.default}` : "";
      return `${v.name}${t}${d}`;
    }).join(", ");
    lines.push(`vars: ${varsStr}`);
  }

  if ((entry.consts || []).length) {
    lines.push(`consts: ${entry.consts.map(c => `${c.name}=${c.value}`).join(" | ")}`);
  }

  if ((entry.enums || []).length) {
    lines.push(`enums: ${entry.enums.map(e => `${e.name}{${e.values.join(",")}}`).join(" | ")}`);
  }

  if ((entry.funcs || []).length) {
    lines.push(`funcs: ${entry.funcs.map(f => {
      const r = f.returns !== "void" ? `→${f.returns}` : "";
      return `${f.name}(${f.params})${r}`;
    }).join(" | ")}`);
  }

  if ((entry.groups || []).length) {
    lines.push(`groups: ${entry.groups.join(", ")}`);
  }

  if ((node.deps || []).length) {
    lines.push(`deps: ${node.deps.join(", ")}`);
  }

  if ((entry.connects || []).length) {
    lines.push(`connects_to_signals: ${entry.connects.slice(0, 6).join(", ")}`);
  }

  if ((entry.emits || []).length) {
    lines.push(`emits: ${entry.emits.slice(0, 6).join(", ")}`);
  }

  if (verbose) {
    lines.push(`--- snippet ---`);
    lines.push(entry.summary || "");
  }

  lines.push(`LOC: ${entry.loc || "?"}`);

  return lines.join("\n");
}

// ── API principal ──────────────────────────────────────────────────────────
/**
 * buildContext(task, options)
 *
 * @param {string} task  - El paso/instrucción actual del pipeline
 * @param {object} opts
 *   maxFiles  {number}  - Máximo de archivos en contexto (default 15)
 *   verbose   {boolean} - Incluir snippet de código (default false)
 *   withDeps  {boolean} - Expandir con dependencias directas (default true)
 *   forceInclude {string[]} - Paths que siempre deben estar
 */
function buildContext(task = "", opts = {}) {
  const {
    maxFiles     = 15,
    verbose      = false,
    withDeps     = true,
    forceInclude = [],
  } = opts;

  const data = loadIndex();
  if (!data) return "⚠️ project_index.json no encontrado. Ejecuta buildIndex() primero.";

  const { index, depGraph } = data;
  const gdEntries = index.filter(e => e.type !== "scene");

  const taskTokens = tokenizeTask(task);

  // Score todos los entries
  const scored = gdEntries.map(entry => {
    const { score, notes } = scoreEntry(entry, taskTokens, depGraph);
    return { entry, score, notes };
  });

  // Ordenar por score descendente
  scored.sort((a, b) => b.score - a.score);

  // Selección primaria: top N por score
  const primaryBudget = Math.floor(maxFiles * 0.7);
  let selected = scored.slice(0, primaryBudget).map(s => s.entry);

  // Forzar includes
  for (const fp of forceInclude) {
    if (!selected.find(e => e.path === fp)) {
      const entry = gdEntries.find(e => e.path === fp);
      if (entry) selected.push(entry);
    }
  }

  // Expandir con deps directas
  if (withDeps) {
    const extras = expandWithDeps(selected, gdEntries, depGraph, maxFiles);
    selected = [...selected, ...extras];
  }

  // Deduplicar
  const seen = new Set();
  selected = selected.filter(e => {
    if (seen.has(e.path)) return false;
    seen.add(e.path);
    return true;
  });

  // Serializar
  const blocks = selected.map(entry => serializeEntry(entry, depGraph, verbose));

  // Incluir escenas relevantes (máx 3)
  const scenes = index.filter(e => e.type === "scene");
  const relScenes = scenes.filter(s => {
    return taskTokens.some(t => s.path.toLowerCase().includes(t));
  }).slice(0, 3);
  const sceneBlocks = relScenes.map(s => serializeEntry(s, depGraph, false));

  const header = [
    `TASK: ${task}`,
    `Archivos seleccionados: ${selected.length} de ${gdEntries.length} scripts`,
    `Escenas incluidas: ${relScenes.length}`,
    `Tokens del task: [${taskTokens.join(", ")}]`,
    "─".repeat(60),
  ].join("\n");

  return [header, ...blocks, ...sceneBlocks].join("\n\n");
}

// ── Utilidad: resumen del grafo completo (para el Senior Thinker) ──────────
function buildDepSummary() {
  const data = loadIndex();
  if (!data) return "";
  const { depGraph } = data;

  const lines = ["DEPENDENCY GRAPH SUMMARY:"];
  for (const [file, node] of Object.entries(depGraph)) {
    const base = path.basename(file);
    if (node.deps.length || node.signals.length) {
      lines.push(`${base}: deps=[${node.deps.map(d => path.basename(d)).join(",")}] signals=[${node.signals.join(",")}]`);
    }
  }
  return lines.join("\n");
}

module.exports = { buildContext, buildDepSummary, serializeEntry, tokenizeTask };
