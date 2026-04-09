const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
require('dotenv').config();

function resolveServiceAccountPath() {
  const explicitPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!explicitPath) {
    throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_PATH (or GOOGLE_APPLICATION_CREDENTIALS) in environment.');
  }

  const resolved = path.isAbsolute(explicitPath)
    ? explicitPath
    : path.resolve(process.cwd(), explicitPath);

  if (!fs.existsSync(resolved)) {
    throw new Error(`Service account file not found at: ${resolved}`);
  }

  return resolved;
}

function initFirebaseAdmin() {
  if (admin.apps.length) {
    return admin.firestore();
  }

  const serviceAccountPath = resolveServiceAccountPath();
  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
  });

  return admin.firestore();
}

module.exports = { initFirebaseAdmin };
