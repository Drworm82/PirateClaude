const fs = require("fs");

function retrieve(task) {
  if (!fs.existsSync("system/memory.json")) return "";

  const memory = JSON.parse(fs.readFileSync("system/memory.json", "utf-8"));

  const relevant = memory.slice(-3);

  return relevant.map(m => `
TAREA ANTERIOR:
${m.task}

CÓDIGO INCORRECTO:
${m.bad}

CÓDIGO CORREGIDO:
${m.fixed}
`).join("\n");
}

module.exports = { retrieve };