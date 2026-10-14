// Optional Windows fallback for librsvg. All rendering is file-only, with no Godot/audio process.
const sharp = require('sharp');
const fs = require('fs');
const [target, width, height] = process.argv.slice(2);
sharp(fs.readFileSync(0)).resize(Number(width), Number(height)).png().toFile(target)
  .catch(error => { console.error(error.message); process.exitCode = 1; });
