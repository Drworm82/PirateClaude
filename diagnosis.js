const fs = require("fs");
const path = require("path");

// ✅ rutas correctas según tu estructura
const { buildIndex } = require("./system/scanner");
const { buildContext } = require("./system/context_builder");
const { runLLM } = require("./system/llm");

// === CONFIG ===
const PROJECT_PATH = __dirname;

// === HELPERS ===

function readFileSafe(file) {
  try {
    return fs.readFileSync(file, "utf-8");
  } catch {
    return "";
  }
}

function detectDuplicates(files) {
  const map = new Map();
  const duplicates = [];

  for (const file of files) {
    const content = readFileSafe(file);

    const normalized = content
      .replace(/\s+/g, "")
      .toLowerCase();

    if (map.has(normalized)) {
      duplicates.push([map.get(normalized), file]);
    } else {
      map.set(normalized, file);
    }
  }

  return duplicates;
}

function detectLargeFiles(files) {
  return files
    .map(f => ({
      file: f,
      size: readFileSafe(f).length
    }))
    .filter(f => f.size > 4000)
    .sort((a, b) => b.size - a.size);
}

function detectGodScripts(files) {
  return files
    .map(f => {
      const content = readFileSafe(f);
      const functions = (content.match(/func /g) || []).length;

      return { file: f, functions };
    })
    .filter(f => f.functions > 15);
}

// === MAIN ===

async function runDiagnosis() {
  console.log("🔍 Running PirateWorld AI Diagnosis...\n");

  // ✅ usa buildIndex (no scanProject)
  const indexData = buildIndex(PROJECT_PATH);

  // extrae rutas reales
  const files = indexData.index.map(e => e.path);

  const gdFiles = files.filter(f => f.endsWith(".gd"));
  const jsFiles = files.filter(f => f.endsWith(".js"));

  // ✅ FIX: buildContext necesita string, no array
  const context = buildContext("full project diagnosis");

  // === STATIC ANALYSIS ===

  const duplicates = detectDuplicates(gdFiles);
  const largeFiles = detectLargeFiles(gdFiles);
  const godScripts = detectGodScripts(gdFiles);

  // === LLM ANALYSIS ===

  const prompt = `
You are a senior game developer auditing a Godot 4 project.

Analyze the following project context and provide:

1. Architectural issues
2. Code smells
3. Missing systems
4. Risk areas
5. Refactor suggestions

Be direct, critical, and specific.

PROJECT CONTEXT:
${context.slice(0, 15000)}
`;

  const llmResponse = await runLLM(prompt);

  // === REPORT ===

  const report = {
    summary: "PirateWorld AI Diagnosis",
    stats: {
      totalFiles: files.length,
      gdScripts: gdFiles.length,
      jsSystemFiles: jsFiles.length
    },
    issues: {
      duplicates,
      largeFiles,
      godScripts
    },
    aiAnalysis: llmResponse
  };

  const outputPath = path.join(PROJECT_PATH, "DIAGNOSIS_REPORT.json");
  fs.writeFileSync(outputPath, JSON.stringify(report, null, 2));

  console.log("✅ Diagnosis complete.");
  console.log("📄 Report:", outputPath);
}

module.exports = { runDiagnosis };

// run directo
if (require.main === module) {
  runDiagnosis();
}