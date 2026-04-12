const fs = require("fs");

function extractFunctions(filePath) {
  const content = fs.readFileSync(filePath, "utf-8");

  const lines = content.split("\n");

  const functions = [];

  for (let line of lines) {
    const trimmed = line.trim();

    if (trimmed.startsWith("func ")) {
      functions.push(trimmed);
    }
  }

  return functions;
}

module.exports = { extractFunctions };