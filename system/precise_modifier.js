const axios = require("axios");
const fs = require("fs");

const { selectBestTarget } = require("./smart_selector");

async function generatePatch(filePath, instruction) {
  const content = fs.readFileSync(filePath, "utf-8");

  const target = selectBestTarget(filePath, instruction);

  const prompt = `
Eres un experto en Godot 4.

Debes modificar el siguiente archivo de forma precisa.

ARCHIVO:
${content}

FUNCIÓN OBJETIVO SUGERIDA:
${target || "ninguna"}

INSTRUCCIÓN:
${instruction}

FORMATO:

{
  "operations": [
    {
      "type": "insert_after",
      "target": "func ...",
      "content": "codigo"
    }
  ]
}

REGLAS:
- usar la función sugerida si es relevante
- si no, elegir la mejor función existente
- NO inventar funciones nuevas si no es necesario
- NO devolver archivo completo
- SOLO JSON
`;

  const response = await axios.post("http://localhost:11434/api/generate", {
    model: "deepseek-coder:6.7b",
    prompt,
    stream: false
  });

  const text = response.data.response;

  try {
    const jsonStart = text.indexOf("{");
    const jsonEnd = text.lastIndexOf("}");
    const clean = text.slice(jsonStart, jsonEnd + 1);

    return JSON.parse(clean);
  } catch {
    console.log("❌ Error generando patch:");
    console.log(text);
    throw new Error("Patch inválido");
  }
}

module.exports = { generatePatch };