const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function loadQuestions() {
  const jsonPath = path.join(__dirname, 'sky_fight_questions.json');
  if (!fs.existsSync(jsonPath)) {
    console.error('Dosya yok:', jsonPath);
    console.error(
      'sky_fight_questions.json dosyasını scripts/ klasörüne koy (Firestore dokümanları q{id} olarak yazılır).',
    );
    process.exit(1);
  }
  const questions = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  if (!Array.isArray(questions)) {
    console.error('sky_fight_questions.json kökte bir dizi [] olmalı.');
    process.exit(1);
  }
  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    const prefix = `Soru ${i + 1}`;
    if (!q || typeof q.id !== 'number') {
      console.error(`${prefix}: "id" sayı olmalı (ör. id: ${i + 1}).`);
      process.exit(1);
    }
    if (!q.question || typeof q.options !== 'object' || !q.correct) {
      console.error(`${prefix}: question, options ve correct zorunlu.`);
      process.exit(1);
    }
  }
  return questions;
}

async function uploadQuestions() {
  const questions = loadQuestions();
  const collectionRef = db.collection('sky_fight_challenges');
  const batch = db.batch();

  questions.forEach((q) => {
    const docRef = collectionRef.doc(`q${q.id}`);
    batch.set(docRef, {
      type: q.type ?? 'terminology',
      question: q.question,
      options: q.options,
      correct: q.correct,
      difficulty: q.difficulty ?? 'easy',
    });
  });

  await batch.commit();
  console.log(`✅ ${questions.length} soru sky_fight_challenges koleksiyonuna yazıldı.`);
  process.exit(0);
}

uploadQuestions().catch((err) => {
  console.error('Hata:', err);
  process.exit(1);
});
