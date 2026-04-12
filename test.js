const { buildIndex } = require("./system/scanner");

const { queryArchitect } = require("./system/llm");
const { enhanceCode } = require("./system/enhancer");
const { fixCode } = require("./system/fixer");
const { isValid } = require("./system/validator");
const { executeTask } = require("./execute-task");
const { learn } = require("./system/learner");

(async () => {
  try {
    const TASK = "crear movimiento de jugador en Godot";

    console.log("📦 Escaneando proyecto...\n");
    buildIndex();

    console.log("🧠 Arquitecto...\n");
    let raw = await queryArchitect(TASK);

    console.log("⚙️ Mejorando...\n");
    let enhanced = await enhanceCode(raw);

    console.log("🛠️ Corrigiendo...\n");
    let fixed = await fixCode(enhanced);

    console.log("🔍 Validando...\n");

    let attempts = 0;
    const MAX_ATTEMPTS = 3;

    while (!isValid(fixed) && attempts < MAX_ATTEMPTS) {
      console.log(`❌ Intento ${attempts + 1} fallido — reintentando...\n`);

      fixed = await fixCode(fixed);
      attempts++;
    }

    if (!isValid(fixed)) {
      console.log("🚨 No se pudo generar código válido");
      return;
    }

    console.log("⚙️ Ejecutando...\n");
    executeTask(fixed);

    console.log("\n🧠 Guardando aprendizaje...\n");
    learn(TASK, raw, fixed);

    console.log("✅ Proceso completo\n");

  } catch (err) {
    console.error("❌ Error crítico:", err);
  }
})();