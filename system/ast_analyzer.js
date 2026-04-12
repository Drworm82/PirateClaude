const fs = require("fs");

function analyzeStructure(filePath) {
  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.split("\n");

  const functions = [];

  let currentFunc = null;

  lines.forEach((line, index) => {
    const trimmed = line.trim();

    if (trimmed.startsWith("func ")) {
      if (currentFunc) functions.push(currentFunc);

      currentFunc = {
        name: trimmed,
        start: index,
        indent: line.indexOf("f"),
        body: []
      };
    } else if (currentFunc) {
      const currentIndent = line.search(/\S|$/);

      if (currentIndent > currentFunc.indent || trimmed === "") {
        currentFunc.body.push({ line, index });
      } else {
        functions.push(currentFunc);
        currentFunc = null;
      }
    }
  });

  if (currentFunc) functions.push(currentFunc);

  return {
    content,
    lines,
    functions
  };
}

module.exports = { analyzeStructure };