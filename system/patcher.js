const fs = require("fs");

function applyPatch(filePath, operations) {
  let content = fs.readFileSync(filePath, "utf-8");

  for (const op of operations) {
    if (op.type === "insert_after") {
      if (content.includes(op.target)) {
        content = content.replace(
          op.target,
          op.target + "\n" + op.content
        );
      }
    }

    if (op.type === "insert_before") {
      if (content.includes(op.target)) {
        content = content.replace(
          op.target,
          op.content + "\n" + op.target
        );
      }
    }

    if (op.type === "replace") {
      if (content.includes(op.target)) {
        content = content.replace(op.target, op.content);
      }
    }
  }

  fs.writeFileSync(filePath, content);

  console.log(`✏️ Patch aplicado: ${filePath}`);
}

module.exports = { applyPatch };