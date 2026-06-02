/**
 * sky_fight_challenges içinde aynı soru metnine sahip birden fazla q* dokümanı var mı?
 *
 *   node scripts/audit_challenge_duplicate_texts.js
 */
const admin = require('firebase-admin');

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

function norm(t) {
  return String(t || '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

async function main() {
  const snap = await db.collection(COL).get();
  const byText = new Map();
  for (const doc of snap.docs) {
    const q = doc.data().question;
    const key = norm(q);
    if (!byText.has(key)) byText.set(key, []);
    byText.get(key).push(doc.id);
  }
  const dups = [...byText.entries()].filter(([, ids]) => ids.length > 1);
  console.log(`Toplam doküman: ${snap.size}`);
  console.log(`Tekrarlayan soru metni grubu: ${dups.length}`);
  for (const [, ids] of dups.slice(0, 30)) {
    console.log('  ', ids.join(', '));
  }
  if (dups.length > 30) console.log(`  ... +${dups.length - 30} grup daha`);
  process.exit(dups.length ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
