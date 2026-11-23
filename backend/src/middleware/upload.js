const multer = require('multer');
const path = require('path');
const fs = require('fs');

function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function createUploader(subFolder) {
  const targetDir = path.join(__dirname, '..', '..', 'uploads', subFolder);
  ensureDir(targetDir);

  const storage = multer.diskStorage({
    destination: (req, file, cb) => {
      ensureDir(targetDir);
      cb(null, targetDir);
    },
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname || '.jpg') || '.jpg';
      const safeName = `${subFolder}-${Date.now()}-${Math.round(Math.random() * 1e6)}${ext}`;
      cb(null, safeName);
    },
  });

  return multer({
    storage,
    limits: { fileSize: 15 * 1024 * 1024 },
  });
}

module.exports = {
  catalogUpload: createUploader('catalog'),
  progressUpload: createUploader('progress'),
  ensureDir,
};
