const { extractFunctions } = require("./code_analyzer");

function selectBestTarget(filePath, instruction) {
  const functions = extractFunctions(filePath);

  if (functions.length === 0) {
    return null;
  }

  // 🔥 lógica básica inteligente
  if (instruction.includes("movimiento") || instruction.includes("player")) {
    const physics = functions.find(f => f.includes("_physics_process"));
    if (physics) return physics;
  }

  if (instruction.includes("input")) {
    const input = functions.find(f => f.includes("_input"));
    if (input) return input;
  }

  // fallback
  return functions[0];
}

module.exports = { selectBestTarget };