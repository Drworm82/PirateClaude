const { analyzeStructure } = require("./ast_analyzer");

function scoreFunction(func, instruction) {
  let score = 0;

  if (instruction.includes("movimiento") && func.name.includes("_physics_process")) score += 5;
  if (instruction.includes("input") && func.name.includes("_input")) score += 5;
  if (instruction.includes("ready") && func.name.includes("_ready")) score += 3;

  if (instruction.includes("player") && func.name.toLowerCase().includes("process")) score += 2;

  return score;
}

function selectBlock(filePath, instruction) {
  const { functions } = analyzeStructure(filePath);

  if (functions.length === 0) return null;

  let best = functions[0];
  let bestScore = 0;

  for (const func of functions) {
    const score = scoreFunction(func, instruction);

    if (score > bestScore) {
      best = func;
      bestScore = score;
    }
  }

  return best;
}

module.exports = { selectBlock };