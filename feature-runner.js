const path = require("path");
const fs   = require("fs");

const { buildIndex, loadIndex } = require("./system/scanner");
const { createPlan }            = require("./system/planner");
const { runStep }               = require("./system/task_runner");

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN — editar aquí antes de cada sesión
// ═══════════════════════════════════════════════════════════════════════════
const CONFIG = {
  // Ruta absoluta al proyecto Godot
  // Si el agente Node.js está dentro de la carpeta del juego, usar __dirname + "/.."
  // Si está fuera, poner la ruta completa: "C:/Users/tu/PirateWorld"
  PROJECT_DIR: path.resolve(__dirname),

  // Feature a implementar
  FEATURE: `en scripts/main.gd reemplazar la función _exit_ship_interior completa con esta implementación exacta:
func _exit_ship_interior() -> void:
	if is_instance_valid(current_ship_interior):
		var ship_cam: Camera2D = current_ship_interior.get_node_or_null("Camera2D")
		if ship_cam:
			ship_cam.enabled = false
		current_ship_interior.visible = false
		current_ship_interior.exit_ship()
		current_ship_interior = null
	if is_instance_valid(gps_map):
		gps_map.visible = true
	current_view = View.GPS`,
DRY_RUN: true,
MAX_STEPS: 1,

  // Si true, solo muestra el plan sin ejecutar ningún paso
  DRY_RUN: false,

  // Re-escanear el proyecto antes de cada run (recomendado: true)
  // Poner false solo si el proyecto no cambió y quieres ahorrar tiempo
  FORCE_RESCAN: true,

  // Máximo de pasos a ejecutar (seguridad — el planner tiene límite propio)
  MAX_STEPS: 5,

  // Si un paso falla, continuar con el siguiente o abortar todo
  CONTINUE_ON_STEP_ERROR: true,
};
// ═══════════════════════════════════════════════════════════════════════════

function printHeader(label) {
  const line = "─".repeat(50);
  console.log(`\n${line}`);
  console.log(` ${label}`);
  console.log(`${line}`);
}

function printIndexStats(indexData) {
  if (!indexData) return;
  const { index, depGraph } = indexData;
  const gd   = index.filter(e => e.type !== "scene").length;
  const tscn = index.filter(e => e.type === "scene").length;
  const deps = Object.values(depGraph).filter(n => n.deps.length > 0).length;
  console.log(`   Scripts .gd   : ${gd}`);
  console.log(`   Escenas .tscn : ${tscn}`);
  console.log(`   Nodos con deps: ${deps}`);
}

// ── Main ──────────────────────────────────────────────────────────────────
(async () => {
  try {
    printHeader("PirateWorld AI Agent");
    console.log(` Feature  : ${CONFIG.FEATURE}`);
    console.log(` Proyecto : ${CONFIG.PROJECT_DIR}`);
    console.log(` Dry-run  : ${CONFIG.DRY_RUN}`);

    // 1. Scan ──────────────────────────────────────────────────────────────
    printHeader("1 / Escaneando proyecto");

    let indexData;

    if (CONFIG.FORCE_RESCAN) {
      indexData = buildIndex(CONFIG.PROJECT_DIR);
    } else {
      indexData = loadIndex();
      if (!indexData) {
        console.log("⚠️  No hay index previo — escaneando de todas formas");
        indexData = buildIndex(CONFIG.PROJECT_DIR);
      } else {
        console.log("✓ Index existente cargado (FORCE_RESCAN=false)");
      }
    }

    printIndexStats(indexData);

    // 2. Plan ──────────────────────────────────────────────────────────────
    printHeader("2 / Generando plan");

    let plan;
    try {
      plan = await createPlan(CONFIG.FEATURE);
    } catch (err) {
      console.error("❌ Planner falló:", err.message);
      process.exit(1);
    }

    if (!plan || !Array.isArray(plan.steps) || plan.steps.length === 0) {
      console.error("❌ Plan inválido o vacío:", plan);
      process.exit(1);
    }

    const steps = plan.steps.slice(0, CONFIG.MAX_STEPS);

    console.log(`\n📋 Pasos (${steps.length}):`);
    steps.forEach((s, i) => console.log(`   ${i + 1}. ${s}`));

    if (CONFIG.DRY_RUN) {
      console.log("\n🔍 DRY_RUN activo — no se ejecuta ningún paso");
      process.exit(0);
    }

    // 3. Ejecución ─────────────────────────────────────────────────────────
    printHeader("3 / Ejecutando pasos");

    const results = [];

    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      console.log(`\n[${i + 1}/${steps.length}] ${step}`);

      const t0 = Date.now();
      let status = "ok";

      try {
        await runStep(step);
      } catch (err) {
        status = "error";
        console.error(`❌ Paso ${i + 1} falló: ${err.message}`);

        if (!CONFIG.CONTINUE_ON_STEP_ERROR) {
          console.error("CONTINUE_ON_STEP_ERROR=false — abortando");
          results.push({ step, status, ms: Date.now() - t0 });
          break;
        }
      }

      results.push({ step, status, ms: Date.now() - t0 });
    }

    // 4. Resumen ───────────────────────────────────────────────────────────
    printHeader("Resumen");

    const ok    = results.filter(r => r.status === "ok").length;
    const error = results.filter(r => r.status === "error").length;

    results.forEach((r, i) => {
      const icon = r.status === "ok" ? "✅" : "❌";
      console.log(`  ${icon} [${i + 1}] ${r.step}  (${r.ms}ms)`);
    });

    console.log(`\n  Completados: ${ok}/${results.length}  |  Errores: ${error}`);

    if (error === 0) {
      console.log("\n🎉 Feature implementada sin errores");
    } else {
      console.log("\n⚠️  Feature completada con errores — revisar logs");
    }

    // Guardar resumen de sesión
    const sessionLog = {
      feature: CONFIG.FEATURE,
      date:    new Date().toISOString(),
      steps:   results,
    };
    fs.mkdirSync("system/logs", { recursive: true });
    const logFile = `system/logs/session_${Date.now()}.json`;
    fs.writeFileSync(logFile, JSON.stringify(sessionLog, null, 2));
    console.log(`\n📄 Log guardado: ${logFile}`);

  } catch (err) {
    console.error("\n❌ Error crítico:", err);
    process.exit(1);
  }
})();