const axios = require("axios");
const fs = require("fs");

async function modifyFile(filePath, instruction) {
  const content = fs.readFileSync(filePath, "utf-8");

  const prompt = `
Eres un experto en Godot 4.

Tu tarea es MODIFICAR el siguiente archivo.

ARCHIVO ORIGINAL:
${content}

INSTRUCCIÓN:
${instruction}

RESPUESTA OBLIGATORIA:

{
  "content": "ARCHIVO COMPLETO MODIFICADO"
}

REGLAS:
- Mantener TODO lo existente
- Solo agregar/modificar lo necesario
- NO borrar código existente
- NO romper sintaxis
- Código funcional en Godot 4
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
    console.log("❌ Error parseando modificación:");
    console.log(text);
    throw new Error("Modifier inválido");
  }
}

module.exports = { modifyFile };