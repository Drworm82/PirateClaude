const fs   = require("fs");
const path = require("path");
const { analyzeStructure } = require("./ast_analyzer");
const { selectBlock }      = require("./block_selector");
const { loadIndex }        = require("./scanner");

// ── Modos de patch soportados ─────────────────────────────────────────────
const PATCH_MODE = {
  INSERT_IN_FUNC:  "insert_in_func",   // insertar código dentro de una función existente
  REPLACE_FUNC:    "replace_func",     // reemplazar el cuerpo de una función completa
  APPEND_FUNC:     "append_func",      // agregar una función nueva al final de la clase
  REPLACE_VAR:     "replace_var",      // reemplazar el valor de una variable de estado
  PREPEND_SIGNAL:  "prepend_signal",   // agregar signal en la zona de signals
  SAFE_APPEND:     "safe_append",      // adjuntar al final (solo si no rompe estructura)
};

// ── Detectar modo correcto dado el newCode y el archivo ──────────────────
function detectPatchMode(content, newCode, instruction) {
  const instrLower = instruction.toLowerCase();
  const newCodeTrimmed = newCode.trim();

  // ¿El nuevo código es una función completa?
  const isNewFunc  = /^func\s+\w+/.test(newCodeTrimmed);
  // ¿El nuevo código es una signal?
  const isSignal   = /^signal\s+\w+/.test(newCodeTrimmed);
  // ¿El nuevo código es una variable?
  const isVar      = /^(?:@export\s+)?var\s+\w+/.test(newCodeTrimmed);
  // ¿La instrucción habla de modificar/reemplazar algo?
  const isReplace  = /reemplaz|replace|modif|actualiz|cambiar/.test(instrLower);
  // ¿La instrucción habla de insertar dentro de?
  const isInsert   = /dentro|inside|en la función|in func|agregar dentro|insertar/.test(instrLower);

  if (isSignal)                    return PATCH_MODE.PREPEND_SIGNAL;
  if (isNewFunc && !isReplace)     return PATCH_MODE.APPEND_FUNC;
  if (isNewFunc && isReplace)      return PATCH_MODE.REPLACE_FUNC;
  if (isVar && isReplace)          return PATCH_MODE.REPLACE_VAR;
  if (isInsert)                    return PATCH_MODE.INSERT_IN_FUNC;

  // Default seguro: agregar función nueva si el código empieza con func,
  // si no — safe append con validación
  return isNewFunc ? PATCH_MODE.APPEND_FUNC : PATCH_MODE.SAFE_APPEND;
}

// ── Validar que el resultado no rompa estructura básica de GDScript ────────
function validateResult(original, patched, filePath) {
  const errors = [];

  // Contar indentación de tabs vs spaces — no mezclar
  const hasTabIndent   = /^\t/m.test(patched);
  const hasSpaceIndent = /^    /m.test(patched);   // 4 spaces
  if (hasTabIndent && hasSpaceIndent) {
    errors.push("INDENTATION_MIX: mezcla de tabs y spaces detectada");
  }

  // Verificar que las funciones del original siguen presentes
  const originalFuncs = [...original.matchAll(/^func\s+(\w+)/gm)].map(m => m[1]);
  const patchedFuncs  = [...patched.matchAll( /^func\s+(\w+)/gm)].map(m => m[1]);
  const missing = originalFuncs.filter(f => !patchedFuncs.includes(f));
  if (missing.length) {
    errors.push(`MISSING_FUNCS: funciones desaparecidas: ${missing.join(", ")}`);
  }

  // Verificar que class_name y extends siguen al inicio
  const origClass  = original.match(/^class_name\s+\w+/m)?.[0];
  const patchClass = patched.match( /^class_name\s+\w+/m)?.[0];
  if (origClass && origClass !== patchClass) {
    errors.push(`CLASS_NAME_CHANGED: ${origClass} → ${patchClass}`);
  }

  // No debe haber líneas con solo whitespace antes de func (problema común de append ciego)
  const blankBeforeFunc = /\n\s+\nfunc /m.test(patched);
  if (blankBeforeFunc) {
    errors.push("BLANK_INDENT_BEFORE_FUNC: línea indentada en blanco antes de func");
  }

  return errors;
}

// ── Analizar impacto en el grafo de dependencias ──────────────────────────
function analyzeImpact(filePath) {
  const data = loadIndex();
  if (!data) return { dependents: [], risk: "unknown" };

  const { depGraph } = data;
  const relPath = filePath.replace(/\\/g, "/");

  const dependents = [];
  for (const [file, node] of Object.entries(depGraph)) {
    if (node.deps.includes(relPath) || node.deps.some(d => d.endsWith(path.basename(filePath)))) {
      dependents.push(file);
    }
  }

  const risk = dependents.length === 0 ? "low"
    : dependents.length <= 2           ? "medium"
    : "high";

  return { dependents, risk };
}

// ── Normalizar indentación del código nuevo ───────────────────────────────
function normalizeIndent(code, baseIndent) {
  const lines = code.split("\n");
  // Detectar indentación del primer token del código nuevo
  const firstNonEmpty = lines.find(l => l.trim().length > 0) || "";
  const existingIndent = firstNonEmpty.match(/^(\s+)/)?.[1] || "";

  // Si el código ya tiene la indentación correcta, no tocar
  if (existingIndent === baseIndent) return code;

  // Reindent
  return lines.map(line => {
    if (line.trim() === "") return "";
    return baseIndent + line.replace(/^\s+/, "");
  }).join("\n");
}

// ── MODO: append_func ─────────────────────────────────────────────────────
function patchAppendFunc(content, newCode) {
  // Determinar indentación dominante del archivo
  const useTabs = /^\tfunc /m.test(content) || /^\tvar /m.test(content);
  const indent  = useTabs ? "\t" : "";

  const normalized = newCode.trim()
    .split("\n")
    .map((line, i) => {
      if (i === 0) return line.trimStart();     // primera línea: la firma func
      if (line.trim() === "") return "";
      return (useTabs ? "\t" : "    ") + line.trimStart();
    })
    .join("\n");

  return content.trimEnd() + "\n\n" + indent + normalized + "\n";
}

// ── MODO: insert_in_func ──────────────────────────────────────────────────
function patchInsertInFunc(content, instruction, newCode) {
  const analysis = analyzeStructure
    ? (() => { try { return analyzeStructure(null, content); } catch { return null; } })()
    : null;

  const block = selectBlock ? (() => {
    try { return selectBlock(null, instruction, content); } catch { return null; }
  })() : null;

  if (!block) {
    console.log("⚠️ selectBlock no encontró objetivo — usando append_func como fallback seguro");
    return patchAppendFunc(content, newCode);
  }

  const lines = content.split("\n");
  const insertIndex = block.start + (block.body ? block.body.length : 1) + 1;
  const indent = "\t".repeat(Math.floor((block.indent || 0) / 4) + 1);
  const formatted = normalizeIndent(newCode, indent);

  lines.splice(insertIndex, 0, formatted);
  return lines.join("\n");
}

// ── MODO: replace_func ────────────────────────────────────────────────────
function patchReplaceFunc(content, newCode) {
  const funcNameMatch = newCode.match(/^func\s+(\w+)/);
  if (!funcNameMatch) return patchAppendFunc(content, newCode);

  const funcName = funcNameMatch[1];
  const lines    = content.split("\n");

  let startLine = -1;
  let endLine   = -1;

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].match(new RegExp(`^func\\s+${funcName}\\s*\\(`))) {
      startLine = i;
      continue;
    }
    if (startLine !== -1 && i > startLine) {
      // La función termina en la siguiente línea que no está indentada
      // (es decir, empieza con func/var/signal/class_name/@/# en col 0)
      if (lines[i].match(/^(?:func|var|signal|@|class_name|const|enum|#)/) && lines[i].trim() !== "") {
        endLine = i - 1;
        break;
      }
    }
  }

  if (startLine === -1) {
    console.log(`⚠️ Función ${funcName} no encontrada — usando append_func`);
    return patchAppendFunc(content, newCode);
  }

  if (endLine === -1) endLine = lines.length - 1;

  const before = lines.slice(0, startLine);
  const after  = lines.slice(endLine + 1);
  const newLines = newCode.trim().split("\n");

  return [...before, ...newLines, "", ...after].join("\n");
}

// ── MODO: replace_var ─────────────────────────────────────────────────────
function patchReplaceVar(content, newCode) {
  const varMatch = newCode.match(/^(?:@export\s+)?var\s+(\w+)/);
  if (!varMatch) return content + "\n" + newCode;

  const varName = varMatch[1];
  const re = new RegExp(`^(?:@export\\s+)?var\\s+${varName}\\b.+`, "m");
  if (re.test(content)) {
    return content.replace(re, newCode.trim());
  }
  return content + "\n" + newCode.trim() + "\n";
}

// ── MODO: prepend_signal ──────────────────────────────────────────────────
function patchPrependSignal(content, newCode) {
  const lines = content.split("\n");

  // Buscar la última signal existente
  let lastSignalIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^signal\s+\w+/.test(lines[i])) lastSignalIdx = i;
  }

  if (lastSignalIdx !== -1) {
    lines.splice(lastSignalIdx + 1, 0, newCode.trim());
    return lines.join("\n");
  }

  // Si no hay signals, insertar después de extends/class_name
  let insertAfter = 0;
  for (let i = 0; i < Math.min(lines.length, 10); i++) {
    if (/^(?:extends|class_name)/.test(lines[i])) insertAfter = i;
  }
  lines.splice(insertAfter + 1, 0, "", newCode.trim());
  return lines.join("\n");
}

// ── MODO: safe_append ────────────────────────────────────────────────────
function patchSafeAppend(content, newCode) {
  const firstLine = newCode.trim().split("\n")[0];

  // Script completo (empieza con extends) → reemplazar el archivo entero
  if (/^extends\s/.test(firstLine)) {
    return newCode.trim() + "\n";
  }

  const isTopLevel = /^(?:func|var|signal|const|enum|class_name|@export|#)/.test(firstLine);
  if (!isTopLevel) {
    const err = `SAFE_APPEND_REJECTED: el código no es top-level GDScript.\nPrimera línea: "${firstLine}"`;
    console.error("❌", err);
    throw new Error(err);
  }

  return content.trimEnd() + "\n\n" + newCode.trim() + "\n";
}

// ── Entry point principal ─────────────────────────────────────────────────
function applySmartPatch(filePath, instruction, newCode) {
  // 1. Leer archivo original
  if (!fs.existsSync(filePath)) {
    throw new Error(`PATCH_ERROR: archivo no existe: ${filePath}`);
  }

  const original = fs.readFileSync(filePath, "utf-8");

  // 2. Analizar impacto antes de tocar
  const impact = analyzeImpact(filePath);
  console.log(`📊 Impacto de ${path.basename(filePath)}: riesgo=${impact.risk}, dependientes=${impact.dependents.length}`);
  if (impact.risk === "high") {
    console.log(`⚠️  Archivos que dependen de este: ${impact.dependents.map(d => path.basename(d)).join(", ")}`);
  }

  // 3. Detectar modo de patch
  const mode = detectPatchMode(original, newCode, instruction);
  console.log(`🔧 Modo de patch: ${mode}`);

  // 4. Aplicar patch según modo
  let patched;
  switch (mode) {
    case PATCH_MODE.APPEND_FUNC:
      patched = patchAppendFunc(original, newCode);
      break;
    case PATCH_MODE.REPLACE_FUNC:
      patched = patchReplaceFunc(original, newCode);
      break;
    case PATCH_MODE.INSERT_IN_FUNC:
      patched = patchInsertInFunc(original, instruction, newCode);
      break;
    case PATCH_MODE.REPLACE_VAR:
      patched = patchReplaceVar(original, newCode);
      break;
    case PATCH_MODE.PREPEND_SIGNAL:
      patched = patchPrependSignal(original, newCode);
      break;
    case PATCH_MODE.SAFE_APPEND:
      patched = patchSafeAppend(original, newCode);
      break;
    default:
      throw new Error(`PATCH_ERROR: modo desconocido: ${mode}`);
  }

  // 5. Validar resultado antes de escribir
  const errors = validateResult(original, patched, filePath);
  if (errors.length > 0) {
    console.error(`❌ Validación fallida para ${filePath}:`);
    errors.forEach(e => console.error("   -", e));
    throw new Error(`PATCH_VALIDATION_FAILED:\n${errors.join("\n")}`);
  }

  // 6. Backup del original
  const backupPath = filePath + ".bak";
  fs.writeFileSync(backupPath, original);

  // 7. Escribir resultado
  fs.writeFileSync(filePath, patched);
  console.log(`✅ Patch aplicado: ${filePath} (modo: ${mode}, backup: ${backupPath})`);

  if (impact.risk !== "low") {
    console.log(`⚠️  Verificar manualmente los dependientes: ${impact.dependents.join(", ")}`);
  }

  return { mode, impact, backup: backupPath };
}

// ── Rollback desde backup ─────────────────────────────────────────────────
function rollbackPatch(filePath) {
  const backupPath = filePath + ".bak";
  if (!fs.existsSync(backupPath)) {
    throw new Error(`ROLLBACK_ERROR: no hay backup para ${filePath}`);
  }
  fs.copyFileSync(backupPath, filePath);
  fs.unlinkSync(backupPath);
  console.log(`↩️  Rollback aplicado: ${filePath}`);
}

module.exports = { applySmartPatch, rollbackPatch, analyzeImpact, detectPatchMode, validateResult, PATCH_MODE };