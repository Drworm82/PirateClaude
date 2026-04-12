const fs   = require("fs");
const path = require("path");

const { buildIndex, loadIndex }        = require("./scanner");
const { buildContext, buildDepSummary, serializeEntry } = require("./context_builder");
const { runLLM }                       = require("./llm");

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════
const PROJECT_PATH = path.resolve(__dirname, "..");
const REPORT_PATH  = path.join(PROJECT_PATH, "DIAGNOSIS_REPORT.json");
const LARGE_FILE_THRESHOLD = 4000;   // chars
const GOD_SCRIPT_THRESHOLD = 15;     // funciones

// ═══════════════════════════════════════════════════════════════════════════
// ANÁLISIS ESTÁTICO
// ═══════════════════════════════════════════════════════════════════════════

function readFileSafe(filePath) {
  try { return fs.readFileSync(filePath, "utf-8"); } catch { return ""; }
}

// Duplicados por contenido normalizado
function detectDuplicates(entries) {
  const map = new Map();
  const duplicates = [];
  for (const entry of entries) {
    const key = (entry.summary || "").replace(/\s+/g, "").toLowerCase();
    if (key.length < 50) continue;   // archivos casi vacíos — ignorar
    if (map.has(key)) {
      duplicates.push({ a: map.get(key), b: entry.path });
    } else {
      map.set(key, entry.path);
    }
  }
  return duplicates;
}

// Archivos grandes (posibles God Scripts)
function detectLargeFiles(entries) {
  return entries
    .map(e => ({ path: e.path, loc: e.loc || 0, funcs: (e.funcs || []).length }))
    .filter(e => e.loc > LARGE_FILE_THRESHOLD / 80)   // estimado: 80 chars/línea
    .sort((a, b) => b.loc - a.loc);
}

// God Scripts — demasiadas funciones en un solo archivo
function detectGodScripts(entries) {
  return entries
    .filter(e => (e.funcs || []).length > GOD_SCRIPT_THRESHOLD)
    .map(e => ({
      path:  e.path,
      funcs: e.funcs.length,
      names: e.funcs.map(f => f.name).join(", ")
    }));
}

// Scripts sin class_name (difíciles de referenciar desde el agent)
function detectAnonymousScripts(entries) {
  return entries
    .filter(e => !e.class_name && e.loc > 10)
    .map(e => ({ path: e.path, extends: e.extends || "?" }));
}

// Variables de estado sin tipo declarado (riesgo de bugs silenciosos)
function detectUntypedVars(entries) {
  const results = [];
  for (const entry of entries) {
    const untyped = (entry.stateVars || []).filter(v => !v.type);
    if (untyped.length > 3) {
      results.push({ path: entry.path, count: untyped.length, vars: untyped.map(v => v.name) });
    }
  }
  return results;
}

// Signals declaradas pero que ningún otro archivo conecta
function detectOrphanSignals(entries, depGraph) {
  const allConnects = new Set();
  for (const node of Object.values(depGraph)) {
    (node.connects || []).forEach(s => allConnects.add(s));
  }
  const results = [];
  for (const entry of entries) {
    const orphans = (entry.signals || []).filter(s => !allConnects.has(s.name));
    if (orphans.length) {
      results.push({ path: entry.path, signals: orphans.map(s => s.name) });
    }
  }
  return results;
}

// Scripts que nada depende de ellos Y ninguna escena los vincula
function detectIsolatedScripts(entries, depGraph) {
  const referencedByOthers = new Set();

  // Referenciados por preload/autoload de otros scripts
  for (const node of Object.values(depGraph)) {
    node.deps.forEach(d => referencedByOthers.add(d));
  }

  const AUTOLOAD_BASES = new Set([
    "game_manager", "gamestate",    "game_state",
    "voyagemanager","voyage_manager","gpsservice",
    "gps_service",  "supabase",     "supabaseconfig", "supabase_config"
  ]);

  return entries
    .filter(e => {
      const base = path.basename(e.path, ".gd").toLowerCase();
      // Excluir autoloads conocidos
      if (AUTOLOAD_BASES.has(base)) return false;
      // Excluir si otro script lo referencia
      if (referencedByOthers.has(e.path)) return false;
      // Excluir si alguna escena .tscn lo vincula
      const node = depGraph[e.path];
      if (node && node.usedByScenes && node.usedByScenes.length > 0) return false;
      return true;
    })
    .map(e => ({
      path: e.path,
      reason: "sin referencias en scripts ni escenas"
    }));
}

// ═══════════════════════════════════════════════════════════════════════════
// ANÁLISIS LLM
// ═══════════════════════════════════════════════════════════════════════════

async function runLLMAnalysis(indexData) {
  const { index, depGraph } = indexData;
  const gdEntries = index.filter(e => e.type !== "scene");

  // Contexto compacto — solo lo esencial, sin snippets
  // qwen2:7b se queda sin tokens con prompts largos
  const compactContext = gdEntries.map(e => {
    const parts = [`FILE: ${e.path}`];
    if (e.class_name) parts.push(`class: ${e.class_name}`);
    if (e.extends)    parts.push(`extends: ${e.extends}`);
    if ((e.funcs   || []).length) parts.push(`funcs: ${e.funcs.map(f => f.name).join(", ")}`);
    if ((e.signals || []).length) parts.push(`signals: ${e.signals.map(s => s.name).join(", ")}`);
    if ((e.stateVars || []).length) parts.push(`vars: ${e.stateVars.slice(0, 6).map(v => v.name).join(", ")}`);
    return parts.join(" | ");
  }).join("\n");

  const prompt = `You are auditing a Godot 4 GPS pirate RPG (PirateWorld).
Autoloads: GameManager, GameState, VoyageManager, GpsService, Supabase.
Two views: GPSMap (overworld) and Dungeon (island interior).

PROJECT FILES:
${compactContext}

Respond ONLY with this JSON, no markdown, no extra text:
{
  "architectural_issues": [{"severity":"high|medium|low","file":"...","issue":"...","fix":"..."}],
  "missing_systems": [{"name":"...","why_needed":"...","suggested_file":"..."}],
  "risk_areas": [{"area":"...","reason":"...","affected_files":["..."]}],
  "refactor_suggestions": [{"priority":"high|medium|low","description":"...","files":["..."]}],
  "overall_health": "good|fair|critical",
  "sprint_recommendation": "..."
}`.trim();

  try {
    // Intentar deepseek-coder primero (mejor para JSON estructurado)
    // Si no está disponible, fallback a qwen2:7b
    let raw;
    try {
      raw = await runLLM(prompt, "deepseek-coder:6.7b");
    } catch {
      console.log("   deepseek-coder no disponible, usando qwen2:7b...");
      raw = await runLLM(prompt, "qwen2:7b");
    }

    const jsonStart = raw.indexOf("{");
    const jsonEnd   = raw.lastIndexOf("}");

    if (jsonStart === -1 || jsonEnd === -1) {
      return { error: "LLM no devolvió JSON válido", raw: raw.slice(0, 300) };
    }

    return JSON.parse(raw.slice(jsonStart, jsonEnd + 1));

  } catch (err) {
    console.error("❌ LLM error:", err.code || err.message);
    return { error: err.message || err.code || "unknown" };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPORTE EN CONSOLA
// ═══════════════════════════════════════════════════════════════════════════

function printSection(title, items, formatter) {
  const line = "─".repeat(52);
  console.log(`\n${line}`);
  console.log(` ${title}`);
  console.log(line);
  if (!items || items.length === 0) {
    console.log("  ✓ ninguno");
    return;
  }
  items.forEach(item => console.log("  " + formatter(item)));
}

function printLLMReport(analysis) {
  if (!analysis || analysis.error) {
    console.log(`\n⚠️  LLM analysis error: ${analysis?.error || "unknown"}`);
    return;
  }

  const line = "═".repeat(52);
  console.log(`\n${line}`);
  console.log(` AI ANALYSIS  —  health: ${(analysis.overall_health || "?").toUpperCase()}`);
  console.log(line);

  if (analysis.architectural_issues?.length) {
    console.log("\n🏗  ARCHITECTURAL ISSUES:");
    analysis.architectural_issues.forEach(i =>
      console.log(`  [${i.severity?.toUpperCase()}] ${i.file}: ${i.issue}\n    → ${i.fix}`)
    );
  }

  if (analysis.risk_areas?.length) {
    console.log("\n⚠️  RISK AREAS:");
    analysis.risk_areas.forEach(r =>
      console.log(`  ${r.area}: ${r.reason}`)
    );
  }

  if (analysis.missing_systems?.length) {
    console.log("\n🔧 MISSING SYSTEMS:");
    analysis.missing_systems.forEach(m =>
      console.log(`  ${m.name} → ${m.suggested_file}\n    ${m.why_needed}`)
    );
  }

  if (analysis.refactor_suggestions?.length) {
    console.log("\n♻️  REFACTOR SUGGESTIONS:");
    analysis.refactor_suggestions.forEach(r =>
      console.log(`  [${r.priority?.toUpperCase()}] ${r.description}`)
    );
  }

  if (analysis.sprint_recommendation) {
    console.log(`\n🚀 SPRINT RECOMMENDATION:\n  ${analysis.sprint_recommendation}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

async function runDiagnosis(options = {}) {
  const { skipLLM = false, forceRescan = true } = options;

  console.log("🔍 PirateWorld AI Diagnosis\n");

  // 1. Scan ─────────────────────────────────────────────────────────────────
  console.log("📦 Escaneando proyecto...");
  const indexData = forceRescan
    ? buildIndex(PROJECT_PATH)
    : (loadIndex() || buildIndex(PROJECT_PATH));

  const { index, depGraph } = indexData;
  const gdEntries = index.filter(e => e.type !== "scene");
  const scenes    = index.filter(e => e.type === "scene");

  console.log(`   ${gdEntries.length} scripts .gd | ${scenes.length} escenas .tscn`);

  // 2. Análisis estático ────────────────────────────────────────────────────
  console.log("\n🔬 Análisis estático...");

  const duplicates      = detectDuplicates(gdEntries);
  const largeFiles      = detectLargeFiles(gdEntries);
  const godScripts      = detectGodScripts(gdEntries);
  const anonymous       = detectAnonymousScripts(gdEntries);
  const untypedVars     = detectUntypedVars(gdEntries);
  const orphanSignals   = detectOrphanSignals(gdEntries, depGraph);
  const isolatedScripts = detectIsolatedScripts(gdEntries, depGraph);

  printSection("Duplicados", duplicates,
    d => `${path.basename(d.a)}  ≈  ${path.basename(d.b)}`);

  printSection("Archivos grandes (God Script risk)", largeFiles,
    f => `${path.basename(f.path)}  ${f.loc} LOC  ${f.funcs} funciones`);

  printSection("God Scripts (>${GOD_SCRIPT_THRESHOLD} funciones)", godScripts,
    g => `${path.basename(g.path)}  [${g.funcs} funcs]`);

  printSection("Scripts sin class_name", anonymous,
    a => `${a.path}  extends ${a.extends}`);

  printSection("Scripts con vars sin tipo (>${3})", untypedVars,
    u => `${path.basename(u.path)}  ${u.count} vars: ${u.vars.slice(0, 5).join(", ")}`);

  printSection("Signals huérfanas (nadie las conecta)", orphanSignals,
    o => `${path.basename(o.path)}: ${o.signals.join(", ")}`);

  printSection("Scripts aislados (nadie los referencia)", isolatedScripts,
    f => `${path.basename(f.path)}  — ${f.reason}`);

  // 3. Análisis LLM ─────────────────────────────────────────────────────────
  let llmAnalysis = null;
  if (!skipLLM) {
    console.log("\n🤖 Analizando con LLM (puede tardar ~30s)...");
    llmAnalysis = await runLLMAnalysis(indexData);
    printLLMReport(llmAnalysis);
  }

  // 4. Guardar reporte ───────────────────────────────────────────────────────
  const report = {
    generated:  new Date().toISOString(),
    project:    PROJECT_PATH,
    stats: {
      gdScripts:   gdEntries.length,
      scenes:      scenes.length,
      totalFiles:  index.length,
    },
    static_analysis: {
      duplicates,
      largeFiles,
      godScripts,
      anonymous,
      untypedVars,
      orphanSignals,
      isolatedScripts,
    },
    llmAnalysis,
  };

  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2));
  console.log(`\n✅ Diagnóstico completo.`);
  console.log(`📄 Reporte: ${REPORT_PATH}`);

  return report;
}

module.exports = { runDiagnosis };

if (require.main === module) {
  // node system/project_diagnosis.js [--skip-llm] [--no-rescan]
  const skipLLM    = process.argv.includes("--skip-llm");
  const forceRescan = !process.argv.includes("--no-rescan");
  runDiagnosis({ skipLLM, forceRescan });
}