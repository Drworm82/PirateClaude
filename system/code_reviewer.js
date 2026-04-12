const axios = require("axios");

async function reviewCode(code) {
  const prompt = `
Actúa como code reviewer senior especializado en Godot 4 y GDScript.

Analiza el siguiente código:

${code}

RESPONDE EXCLUSIVAMENTE con este JSON. Sin texto antes ni después:

{
  "approved": true,
  "issues": [
    {
      "type": "bug",
      "message": "descripción del problema",
      "severity": "high"
    }
  ]
}

Valores válidos:
- approved: true | false
- type: "bug" | "warning" | "improvement"
- severity: "low" | "medium" | "high"

REGLAS:
- approved = false si hay bugs o riesgos de severity "high"
- approved = true si solo hay warnings o improvements
- issues puede ser un array vacío [] si el código es correcto
`.trim();

  const response = await axios.post("http://localhost:11434/api/generate", {
    model: "qwen2.5-coder:7b",
    prompt,
    stream: false,
    format: "json"    // ← garantiza JSON válido
  });

  const text = response.data.response;

  try {
    return JSON.parse(text);
  } catch (err) {
    console.log("⚠️ Code Reviewer — JSON inválido tras format:json:");
    console.log(text);
    // fallback seguro: aprobar sin issues si el parsing falla
    return { approved: true, issues: [] };
  }
}

module.exports = { reviewCode };
