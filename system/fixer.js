const axios = require("axios");
const { callOllamaJSON } = require("./llm");

async function fixCode(badOutput) {
  const prompt = `
Eres un experto en Godot 4 y GDScript.

Se te da un JSON que puede estar mal formado o contener código GDScript incorrecto.
Tu trabajo es devolver un JSON corregido y válido.

REGLAS DE GDSCRIPT:
- Usar 'func' no 'def' ni 'function'
- Todo script debe tener 'extends NombreClase'
- Usar '@export var' no 'export var'
- Usar '@onready var' no 'onready var'
- Usar 'await' no 'yield()'
- Usar '.instantiate()' no '.instance()'
- Usar 'signal.emit()' no 'emit_signal()'
- No usar Vector3 ni Node3D (proyecto 2D)
- No usar '//' para comentarios — usar '#'
- Indentación con tabs

FORMATO DE RESPUESTA OBLIGATORIO — solo este JSON, nada más:

{
  "files": [
    {
      "path": "scripts/archivo.gd",
      "action": "create",
      "content": "extends Node\\n\\nfunc _ready() -> void:\\n\\tpass"
    }
  ]
}

INPUT A CORREGIR:
${badOutput}
`.trim();

  return callOllamaJSON(prompt, "qwen2.5-coder:7b");
}

module.exports = { fixCode };
