const fs = require("fs");

function applyChange(filePath, newContent) {
  if (!fs.existsSync(filePath)) {
    console.log("❌ Archivo no existe:", filePath);
    return;
  }

  fs.writeFileSync(filePath, newContent);

  console.log(`✏️ Archivo modificado: ${filePath}`);
}

module.exports = { applyChange };