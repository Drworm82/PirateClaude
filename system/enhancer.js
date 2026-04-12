const axios = require("axios");
const { callOllamaJSON } = require("./llm");

async function enhanceCode(input) {
  const prompt = `
Eres un experto en Godot 4 y GDScript.

Mejora el siguiente JSON con código GDScript para que sea más correcto y limpio.

REGLAS:
- Mantener el formato JSON exacto con la clave "files"
- Corregir errores de sintaxis GDScript
- Mantener compatibilidad con Godot 4
- No agregar archivos que no estaban en el input
- No cambiar los paths de archivos

FORMATO DE RESPUESTA — solo este JSON, nada más:

{
  "files": [
    {
      "path": "scripts/archivo.gd",
      "action": "create",
      "content": "CODIGO MEJORADO"
    }
  ]
}

INPUT:
${input}
`.trim();

  return callOllamaJSON(prompt, "qwen2.5-coder:7b");
}

module.exports = { enhanceCode };
