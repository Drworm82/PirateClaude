const axios = require("axios");
const fs = require("fs");

// ── Llamada base a Ollama — texto libre ───────────────────────────────────
async function callOllama(prompt, model = "qwen2.5-coder:7b") {
  const response = await axios.post("http://localhost:11434/api/generate", {
    model,
    prompt,
    stream: false
  });
  return response.data.response;
}

// ── Llamada a Ollama con formato JSON forzado ─────────────────────────────
async function callOllamaJSON(prompt, model = "qwen2.5-coder:7b") {
  const response = await axios.post("http://localhost:11434/api/generate", {
    model,
    prompt,
    stream: false,
    format: "json"
  });
  return response.data.response;
}

// ── Prompt libre ──────────────────────────────────────────────────────────
async function runLLM(prompt, model = "qwen2.5-coder:7b") {
  return callOllama(prompt, model);
}

// ── Extraer el path .gd mencionado en la tarea ────────────────────────────
function extractTargetFile(task) {
  const match = task.match(/scripts\/[\w/]+\.gd|scenes\/[\w/]+\.gd/i);
  return match ? match[0] : null;
}

// ── Leer el contenido actual del archivo objetivo (si existe) ─────────────
function readTargetFile(filePath) {
  if (!filePath) return "";
  try {
    const content = fs.readFileSync(filePath, "utf-8");
    // Limitar a 2000 chars para no ahogar el prompt
    const trimmed = content.length > 2000 ? content.slice(0, 2000) + "\n... (truncated)" : content;
    return `CURRENT CONTENT OF ${filePath}:\n${trimmed}`;
  } catch {
    return `NOTE: ${filePath} does not exist yet — create it from scratch.`;
  }
}

// ── Architect — genera código GDScript estructurado en JSON ───────────────
async function queryArchitect(task) {
  const targetFile  = extractTargetFile(task);
  const fileContext = readTargetFile(targetFile);

  const prompt = [
    "You are a GDScript code generator for Godot 4.",
    "You always respond with a JSON object containing a files array.",
    "",
    "EXAMPLE 1:",
    'Task: "Create scripts/ship.gd with @export var ship_tier: int = 0"',
    'Response: {"files":[{"path":"scripts/ship.gd","action":"create","content":"extends Node2D\\n\\n@export var ship_tier: int = 0\\n\\nfunc _ready() -> void:\\n\\tpass\\n"}]}',
    "",
    "EXAMPLE 2:",
    'Task: "Add func travel_to(island_id: String) to scripts/ship.gd"',
    'Response: {"files":[{"path":"scripts/ship.gd","action":"modify","content":"extends Node2D\\n\\n@export var ship_tier: int = 0\\n\\nfunc _ready() -> void:\\n\\tpass\\n\\nfunc travel_to(island_id: String) -> void:\\n\\tpass\\n"}]}',
    "",
    "RULES:",
    "- path must be the exact .gd file mentioned in the task",
    "- content must be valid GDScript 4 as a JSON string",
    "- First line of content must be: extends SomeClass",
    "- Use @export var (never export var)",
    "- Use func (never def or function)",
    "- Every script must have at least one func",
    "",
    fileContext,
    "",
    "TASK: " + task,
    "Response:",
  ].join("\n");

  console.log("📝 PROMPT LENGTH:", prompt.length, "chars");

  return callOllamaJSON(prompt, "qwen2.5-coder:7b");
}

module.exports = { queryArchitect, runLLM, callOllama, callOllamaJSON };