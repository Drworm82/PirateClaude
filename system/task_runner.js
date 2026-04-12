const fs = require("fs");
const { queryArchitect }  = require("./llm");
const { enhanceCode }     = require("./enhancer");
const { fixCode }         = require("./fixer");
const { isValid }         = require("./validator");
const { executeTask }     = require("../execute-task");
const { learn }           = require("./learner");
const { applySmartPatch, rollbackPatch } = require("./smart_patcher");
const { thinkLikeSenior } = require("./senior_thinker");
const { reviewCode }      = require("./code_reviewer");
const { buildContext, buildDepSummary } = require("./context_builder");

// ─────────────────────────────────────────────────────────────
// 🔥 NUEVO: Soporte JSON estructurado
// ─────────────────────────────────────────────────────────────
function normalizeInput(step) {
  try {
    const parsed = JSON.parse(step);

    console.log("🧩 JSON task detectado");

    return {
      raw: step,
      structured: parsed,
      text: `
TASK TYPE: ${parsed.type}
TARGET: ${parsed.target}
ACTION: ${parsed.action}
SYSTEM: ${parsed.system || ""}

CONSTRAINTS:
${(parsed.constraints || []).join("\n")}
`.trim()
    };

  } catch {
    return {
      raw: step,
      structured: null,
      text: step
    };
  }
}

// ── Construir el contexto enriquecido para el LLM ─────────────────────────
function buildEnrichedStep(step) {
  const semanticContext = buildContext(step, {
    maxFiles:  15,
    verbose:   false,
    withDeps:  true,
  });

  const depSummary = buildDepSummary();

  return `
TASK:
${step}

PROJECT CONTEXT (semantic selection):
${semanticContext}

DEPENDENCY GRAPH:
${depSummary}
`.trim();
}

// ── Ejecutar un paso del plan ──────────────────────────────────────────────
async function runStep(step) {

  // 🔥 NUEVO: normalizar input
  const input = normalizeInput(step);

  console.log(`\n🧠 Analizando paso:\n${input.text}\n`);

  // 🔥 usar texto normalizado
  const enrichedStep = buildEnrichedStep(input.text);

  // 2. Senior Thinker con contexto semántico real
  const decision = await thinkLikeSenior(enrichedStep);
  if (!decision) {
    console.log("⚠️ Senior Thinker no pudo analizar el paso");
    return;
  }

  console.log("🧠 Decisión:");
  console.log(`  action: ${decision.action} | risk: ${decision.risk}`);
  console.log(`  target: ${(decision.target_files || []).join(", ")}`);
  console.log(`  reason: ${decision.reason}`);

  if (decision.action === "skip") {
    console.log("⏭️ Paso omitido por Senior Thinker");
    return;
  }

  console.log(`\n🚀 Generando código...\n`);

  // 3. Generación → mejora → corrección
  let raw      = await queryArchitect(enrichedStep);
  let enhanced = await enhanceCode(raw);
  let fixed    = await fixCode(enhanced);

  let attempts = 0;
  while (!isValid(fixed) && attempts < 3) {
    console.log(`🔄 Fix attempt ${attempts + 1}...`);
    fixed = await fixCode(fixed);
    attempts++;
  }

  if (!isValid(fixed)) {
    console.log("❌ Código inválido tras 3 intentos — abortando paso");
    learn(input.text, raw, fixed, "invalid_after_retries");
    return;
  }

  // 4. Code review
  console.log("🧠 Revisando código...\n");
  const review = await reviewCode(fixed);
  console.log(`📋 Review: ${review.approved ? "✅ aprobado" : "❌ rechazado"}`);
  if (review.comments) console.log(`   ${review.comments}`);

  if (!review.approved) {
    console.log("⚠️ Corrigiendo tras review...\n");
    fixed = await fixCode(fixed);
    const secondReview = await reviewCode(fixed);
    if (!secondReview.approved) {
      console.log("❌ Código rechazado en segunda revisión — abortando");
      learn(input.text, raw, fixed, "rejected_by_reviewer");
      return;
    }
  }

  // 5. Parsear y ejecutar archivos
  let data;
  try {
    data = JSON.parse(fixed);
  } catch (e) {
    console.log("❌ JSON inválido en output final:", e.message);
    learn(input.text, raw, fixed, "json_parse_error");
    return;
  }

  if (!Array.isArray(data.files) || data.files.length === 0) {
    console.log("⚠️ El output no contiene archivos — nada que escribir");
    return;
  }

  for (const file of data.files) {
    const filePath = file.path;

    if (!filePath || typeof filePath !== "string") {
      console.log("⚠️ Archivo sin path válido, ignorando");
      continue;
    }

    const fileExists = fs.existsSync(filePath);
    const isCreate   = (file.action === 'create');

    if (fileExists && !isCreate) {
      console.log(`
🔧 Modificando: ${filePath}`);
      try {
        const result = applySmartPatch(filePath, input.text, file.content);
        console.log(`✅ Patch OK — modo: ${result.mode}, riesgo: ${result.impact.risk}`);
      } catch (err) {
        console.error(`❌ Patch fallido en ${filePath}: ${err.message}`);
        learn(input.text, raw, fixed, `patch_failed:${filePath}:${err.message}`);
        try { rollbackPatch(filePath); console.log(`↩️  Rollback: ${filePath}`); } catch {}
      }
    } else {
      if (fileExists && isCreate) {
        console.log(`
📄 Sobrescribiendo (action=create): ${filePath}`);
      } else {
        console.log(`
📄 Creando: ${filePath}`);
      }
      try {
        executeTask(JSON.stringify({ files: [file] }));
        console.log(`✅ Archivo escrito: ${filePath}`);
      } catch (err) {
        console.error(`❌ Error escribiendo ${filePath}: ${err.message}`);
        learn(input.text, raw, fixed, `create_failed:${filePath}:${err.message}`);
      }
    }
  }

  learn(input.text, raw, fixed, "success");
  console.log("\n✅ Paso completado");
}

module.exports = { runStep };