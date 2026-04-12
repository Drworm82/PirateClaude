const fs = require("fs");
const path = require("path");

function executeTask(taskJson) {
  const data = JSON.parse(taskJson);

  data.files.forEach(file => {
    const fullPath = path.join(process.cwd(), file.path);

    fs.mkdirSync(path.dirname(fullPath), { recursive: true });

    fs.writeFileSync(fullPath, file.content);

    console.log(`✅ Archivo creado: ${file.path}`);
  });
}

module.exports = { executeTask };