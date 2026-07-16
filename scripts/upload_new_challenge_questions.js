/**
 * sky_fight_challenges koleksiyonuna yeni soruları yükler (varsayılan: q242..q400).
 *
 * Önkoşul: kökte service-account.json
 *
 *   node scripts/upload_new_challenge_questions.js
 *   node scripts/upload_new_challenge_questions.js --from=242 --to=400
 *   node scripts/upload_new_challenge_questions.js --dry-run
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const m = a.match(/^--([^=]+)(?:=(.*))?$/);
    return m ? [m[1], m[2] ?? true] : [a, true];
  }),
);

const fromId = Number(args.from ?? 242);
const toId = Number(args.to ?? 400);
const dryRun = args['dry-run'] === true || args['dry-run'] === 'true';

try {
  admin.initializeApp({
    credential: admin.credential.cert(require('../service-account.json')),
  });
} catch (e) {
  console.error('service-account.json gerekli:', e.message);
  process.exit(1);
}

const db = admin.firestore();
const COL = 'sky_fight_challenges';
const BATCH_LIMIT = 400;

function loadQuestions() {
  const jsonPath = path.join(__dirname, 'sky_fight_questions.json');
  const questions = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  if (!Array.isArray(questions)) {
    throw new Error('sky_fight_questions.json kökte bir dizi [] olmalı.');
  }
  return questions.filter((q) => q.id >= fromId && q.id <= toId);
}

async function upload() {
  const questions = loadQuestions();
  console.log(
    `Yüklenecek: ${questions.length} soru (id ${fromId}..${toId})` +
      (dryRun ? ' [DRY-RUN]' : ''),
  );
  if (questions.length === 0) {
    console.error('Bu aralıkta soru yok.');
    process.exit(1);
  }

  for (let i = 0; i < questions.length; i++) {
    const q = questions[i];
    if (!q || typeof q.id !== 'number' || !q.question || !q.options || !q.correct) {
      console.error(`Geçersiz soru index=${i} id=${q?.id}`);
      process.exit(1);
    }
    if (!q.options[q.correct]) {
      console.error(`correct şıkkı yok: q${q.id} correct=${q.correct}`);
      process.exit(1);
    }
  }

  if (dryRun) {
    console.log('Örnek ilk:', JSON.stringify(questions[0], null, 2));
    console.log('Örnek son:', JSON.stringify(questions[questions.length - 1], null, 2));
    process.exit(0);
  }

  const collectionRef = db.collection(COL);
  for (let start = 0; start < questions.length; start += BATCH_LIMIT) {
    const chunk = questions.slice(start, start + BATCH_LIMIT);
    const batch = db.batch();
    for (const q of chunk) {
      batch.set(collectionRef.doc(`q${q.id}`), {
        type: q.type ?? 'terminology',
        question: q.question,
        options: q.options,
        correct: q.correct,
        difficulty: q.difficulty ?? 'easy',
      });
    }
    await batch.commit();
    console.log(
      `✓ Yazıldı: q${chunk[0].id}..q${chunk[chunk.length - 1].id} (${chunk.length})`,
    );
  }

  console.log(`✅ ${questions.length} soru ${COL} koleksiyonuna yazıldı.`);
  process.exit(0);
}

upload().catch((err) => {
  console.error('Hata:', err);
  process.exit(1);
});
