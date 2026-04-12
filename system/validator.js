// validator.js — Validador de GDScript para Godot 4

const FORBIDDEN_PATTERNS = [
  { pattern: /\bdef\s+\w+/,           msg: "usar 'func' no 'def' (Python)" },
  { pattern: /\bfunction\s+\w+/,      msg: "usar 'func' no 'function' (JS)" },
  { pattern: /\/\/\s/,                msg: "usar '#' para comentarios, no '//'" },
  { pattern: /\.instance\(\)/,        msg: "usar .instantiate() no .instance() (Godot 3)" },
  { pattern: /\bemit_signal\s*\(/,    msg: "usar signal.emit() no emit_signal() (Godot 3)" },
  { pattern: /\bconnect\s*\(\s*"/,    msg: "usar signal.connect(callable) no connect(string) (Godot 3)" },
  { pattern: /\byield\s*\(/,          msg: "usar 'await' no 'yield()' (Godot 3)" },
  { pattern: /^export\s+var/m,        msg: "usar '@export var' no 'export var' (Godot 3)" },
  { pattern: /^onready\s+var/m,       msg: "usar '@onready var' no 'onready var' (Godot 3)" },
  { pattern: /\bsetget\b/,            msg: "usar get/set properties no 'setget' (Godot 3)" },
  { pattern: /\.empty\(\)/,           msg: "usar .is_empty() no .empty() (Godot 3)" },
  { pattern: /Rect2\.ZERO/,           msg: "Rect2.ZERO no existe — usar Rect2()" },
  { pattern: /Rect2i\.ZERO/,          msg: "Rect2i.ZERO no existe — usar Rect2i()" },
  { pattern: /Color\.TRANSPARENT/,    msg: "Color.TRANSPARENT no existe — usar Color(0,0,0,0)" },
  { pattern: /Transform\.IDENTITY/,   msg: "usar Transform2D.IDENTITY no Transform.IDENTITY" },
  { pattern: /\bVector3\b/,           msg: "proyecto 2D — no usar Vector3" },
  { pattern: /\bNode3D\b/,            msg: "proyecto 2D — no usar Node3D" },
  { pattern: /\bMeshInstance3D\b/,    msg: "proyecto 2D — no usar MeshInstance3D" },
  { pattern: /\bSupabaseClient\.rpc\s*\(/, msg: "usar supabase_rpc() no rpc() — reservado en Godot 4" },
  { pattern: /\bGameManager\.new\(\)/, msg: "GameManager es autoload — no instanciar con new()" },
  { pattern: /\bGameState\.new\(\)/,   msg: "GameState es autoload — no instanciar con new()" },
  { pattern: /\bVoyageManager\.new\(\)/, msg: "VoyageManager es autoload — no instanciar con new()" },
  { pattern: /move_and_slide\s*\(\s*velocity\s*,/, msg: "move_and_slide() en Godot 4 no recibe argumentos" },
];

// ── Determinar si un script es "completo" o un "fragmento/patch" ──────────
// Un fragmento es código que solo agrega variables, constantes, señales,
// sin necesitar extends ni func propios (se insertará en un script existente)
function isFragment(code) {
  const lines = code.split("\n")
    .map(l => l.trim())
    .filter(l => l.length > 0 && !l.startsWith("#"));

  // Si tiene extends → es script completo
  if (/\bextends\b/.test(code)) return false;

  // Si tiene func → es script completo
  if (/\bfunc\b/.test(code)) return false;

  // Solo tiene variables, constantes, señales, anotaciones → es fragmento
  const fragmentOnly = lines.every(l =>
    l.startsWith("@export") ||
    l.startsWith("@onready") ||
    l.startsWith("var ") ||
    l.startsWith("const ") ||
    l.startsWith("signal ") ||
    l.startsWith("enum ") ||
    l.startsWith("#") ||
    l === ""
  );

  return fragmentOnly;
}

function validateGDScript(code, filePath = "") {
  const errors = [];
  const warnings = [];

  // Si es fragmento, saltamos las reglas de "script completo"
  const fragment = isFragment(code);

  if (!fragment) {
    if (!/\bextends\b/.test(code)) {
      errors.push(`[${filePath}] REQUERIDO: todo script GDScript debe tener 'extends'`);
    }
    if (!/\bfunc\b/.test(code)) {
      errors.push(`[${filePath}] REQUERIDO: todo script debe tener al menos una función`);
    }
  }

  // Prohibidos siempre aplican
  for (const rule of FORBIDDEN_PATTERNS) {
    if (rule.pattern.test(code)) {
      const lines = code.split("\n");
      const lineNum = lines.findIndex(l => rule.pattern.test(l));
      const location = lineNum >= 0 ? `:${lineNum + 1}` : "";
      errors.push(`[${filePath}${location}] PROHIBIDO: ${rule.msg}`);
    }
  }

  if (/\bprint\s*\(/.test(code) && !filePath.includes("debug")) {
    warnings.push(`[${filePath}] WARNING: usar GameState.debug_log() en vez de print()`);
  }

  return { valid: errors.length === 0, errors, warnings };
}

function isValid(jsonString) {
  let data;
  try {
    data = typeof jsonString === "string" ? JSON.parse(jsonString) : jsonString;
  } catch {
    return false;
  }

  if (!data || !Array.isArray(data.files) || data.files.length === 0) {
    return false;
  }

  for (const file of data.files) {
    if (!file.path || typeof file.path !== "string") return false;
    if (!file.content || typeof file.content !== "string") return false;

    if (file.path.endsWith(".gd")) {
      const result = validateGDScript(file.content, file.path);
      if (!result.valid) {
        console.log(`❌ Validación GDScript fallida en ${file.path}:`);
        result.errors.forEach(e => console.log("   ", e));
        return false;
      }
      if (result.warnings.length > 0) {
        result.warnings.forEach(w => console.log("⚠️ ", w));
      }
    }
  }

  return true;
}

function validateWithReport(jsonString) {
  let data;
  try {
    data = typeof jsonString === "string" ? JSON.parse(jsonString) : jsonString;
  } catch (e) {
    return { valid: false, errors: [`JSON inválido: ${e.message}`], warnings: [] };
  }

  if (!data || !Array.isArray(data.files)) {
    return { valid: false, errors: ["Output sin array 'files'"], warnings: [] };
  }

  const allErrors = [];
  const allWarnings = [];

  for (const file of data.files) {
    if (!file.path) { allErrors.push("Archivo sin 'path'"); continue; }
    if (!file.content) { allErrors.push(`${file.path}: sin 'content'`); continue; }
    if (file.path.endsWith(".gd")) {
      const result = validateGDScript(file.content, file.path);
      allErrors.push(...result.errors);
      allWarnings.push(...result.warnings);
    }
  }

  return {
    valid:    allErrors.length === 0,
    errors:   allErrors,
    warnings: allWarnings,
    files:    data.files.length,
  };
}

module.exports = { isValid, validateWithReport, validateGDScript };
