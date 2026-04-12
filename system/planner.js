const axios = require("axios");

async function createPlan(feature) {
  const prompt = `You are a technical planner for an AI code agent working on a Godot 4 game project called PirateWorld.

Your job is to split a feature into small, executable steps for the AI agent.
Each step must describe a FILE OPERATION — not instructions for a human.

Feature: ${feature}

Rules:
- Steps must describe what FILE to create or modify and WHAT CODE to add
- Never say "open Godot", "navigate to", "click", or any human UI action
- Each step must be actionable by a code-writing AI agent
- Maximum 5 steps
- Respond ONLY with JSON, no markdown, no explanation

Respond with exactly this format:
{"steps":["step one","step two"]}

Examples of GOOD steps:
- "Create scripts/ship.gd with an @export var ship_tier: int = 0"
- "Add function travel_to(island_id: String) to scripts/ship.gd"
- "Modify scripts/player.gd to add a reference to the current ship node"

Examples of BAD steps (never do this):
- "Open the Godot game engine"
- "Navigate to the File menu"
- "Right-click on the project folder"

JSON:`;

  const response = await axios.post("http://localhost:11434/api/generate", {
    model: "deepseek-coder:6.7b",
    prompt,
    stream: false,
    format: "json"   // ← fuerza JSON válido
  });

  const text = response.data.response;

  try {
    const parsed = JSON.parse(text);

    let steps = parsed.steps;

    if (steps && !Array.isArray(steps)) {
      steps = Object.values(steps);
    }

    if (!steps) {
      const arrays = Object.values(parsed).filter(v => Array.isArray(v));
      steps = arrays.length > 0 ? arrays[0] : Object.values(parsed);
    }

    steps = steps
      .map(step => {
        if (typeof step === "string") return step;
        if (typeof step === "object" && step !== null) {
          const val = Object.values(step).find(v => typeof v === "string");
          return val || JSON.stringify(step);
        }
        return String(step);
      })
      .filter(s => s.length > 0)
      // Filtrar pasos que suenen a instrucciones humanas
      .filter(s => {
        const lower = s.toLowerCase();
        const humanKeywords = ["open godot", "navigate to", "right-click", "click on", "go to", "file menu", "game engine"];
        return !humanKeywords.some(kw => lower.includes(kw));
      })
      .slice(0, 5);

    if (steps.length === 0) throw new Error("No se encontraron pasos válidos");

    return { steps };

  } catch (err) {
    console.log("⚠️ Error parseando plan:");
    console.log("   Raw:", text.slice(0, 300));
    console.log("   Error:", err.message);
    throw new Error("Planner devolvió formato inválido");
  }
}

module.exports = { createPlan };