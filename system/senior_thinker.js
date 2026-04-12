const axios = require("axios");
const fs = require("fs");

async function thinkLikeSenior(step, projectContext) {
  const prompt = `
Actúa como desarrollador senior en Godot 4.

TAREA:
${step}

CONTEXTO DEL PROYECTO:
${projectContext || ""}

RESPONDE EXCLUSIVAMENTE con este JSON. Sin texto antes ni después:

{
  "risk": "low",
  "action": "create",
  "reason": "explicación corta",
  "target_files": ["ruta/archivo.gd"],
  "notes": "qué cuidar"
}

Valores válidos:
- risk: "low" | "medium" | "high"
- action: "create" | "modify" | "skip"

REGLAS:
- Evitar romper código existente
- Reutilizar scripts si ya existen
- No duplicar lógica
`.trim();

  const response = await axios.post("http://localhost:11434/api/generate", {
    model: "qwen2.5-coder:7b",
    prompt,
    stream: false,
    format: "json"    // ← garantiza JSON válido, elimina texto libre
  });

  const text = response.data.response;

  try {
    return JSON.parse(text);
  } catch (err) {
    console.log("⚠️ Senior Thinker — JSON inválido tras format:json:");
    console.log(text);
    return null;
  }
}

module.exports = { thinkLikeSenior };
