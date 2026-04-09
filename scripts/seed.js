#!/usr/bin/env node

const { initFirebaseAdmin } = require('./firebaseAdmin');
const { generateSeedData, COLLECTIONS } = require('./seedData');

async function deleteCollection(db, collectionName, batchSize = 200) {
  while (true) {
    const snapshot = await db.collection(collectionName).limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function clearCollections(db) {
  for (const collection of COLLECTIONS) {
    await deleteCollection(db, collection);
  }
}

async function writeCollection(db, collectionName, docs) {
  const chunks = [];
  const perBatch = 400;
  for (let i = 0; i < docs.length; i += perBatch) {
    chunks.push(docs.slice(i, i + perBatch));
  }

  for (const chunk of chunks) {
    const batch = db.batch();
    chunk.forEach((doc) => {
      batch.set(db.collection(collectionName).doc(doc.id), doc);
    });
    await batch.commit();
  }
}

async function main() {
  const shouldClear = process.argv.includes('--clear');
  const db = initFirebaseAdmin();

  if (shouldClear) {
    console.log('Clearing approved seed collections before reseeding...');
    await clearCollections(db);
  } else {
    console.log('Running seed without clearing existing data.');
  }

  const payload = generateSeedData();
  const counts = {};

  for (const collectionName of COLLECTIONS) {
    const docs = payload[collectionName] || [];
    await writeCollection(db, collectionName, docs);
    counts[collectionName] = docs.length;
  }

  const summary = {
    totalCollections: COLLECTIONS.length,
    totalDocuments: Object.values(counts).reduce((sum, n) => sum + n, 0),
    counts,
  };

  console.log('Seeding completed successfully.');
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((error) => {
  console.error('Seeding failed:', error.message);
  process.exitCode = 1;
});
