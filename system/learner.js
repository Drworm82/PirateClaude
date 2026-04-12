const fs = require("fs");

function learn(task, badOutput, fixedOutput) {
  const path = "system/memory.json";

  let memory = [];

  if (fs.existsSync(path)) {
    memory = JSON.parse(fs.readFileSync(path, "utf-8"));
  }

  memory.push({
    task,
    bad: badOutput,
    fixed: fixedOutput,
    timestamp: new Date().toISOString()
  });

  fs.writeFileSync(path, JSON.stringify(memory, null, 2));

  console.log("🧠 Aprendizaje guardado");
}

module.exports = { learn };