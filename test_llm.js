const axios = require("axios");

async function test() {
  const prompt = [
    "You are a GDScript code generator for Godot 4.",
    "You always respond with a JSON object containing a files array.",
    "",
    'EXAMPLE:',
    'Task: "Create scripts/ship.gd with @export var ship_tier: int = 0"',
    'Response: {"files":[{"path":"scripts/ship.gd","action":"create","content":"extends Node2D\\n\\n@export var ship_tier: int = 0\\n\\nfunc _ready() -> void:\\n\\tpass\\n"}]}',
    "",
    'TASK: Create scripts/ship.gd with @export var ship_tier: int = 0',
    "",
    "Response:",
  ].join("\n");

  const response = await axios.post("http://localhost:11434/api/generate", {
    model: "qwen2.5-coder:7b",
    prompt,
    stream: false,
    format: "json"
  });

  console.log("OUTPUT:\n", response.data.response);
}

test().catch(console.error);