/**
 * Eski haftalık challengeId (weekly_2026-W20) → yeni format (weekly_2026-05-19).
 * Yayındaki uygulama yeni id ile sorgular; Firestore'da alanı güncellemek yeterli (doc id kalabilir).
 *
 * Önkoşul: service-account.json proje kökünde.
 *
 *   node scripts/migrate_weekly_challenge_ids.js --dry-run
 *   node scripts/migrate_weekly_challenge_ids.js --confirm
 */

const admin = require('firebase-admin');

try {
  const serviceAccount = require('../service-account.json');
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} catch (e) {
  console.error('service-account.json gerekli:', e.message);
  process.exit(1);
}

const db = admin.firestore();
const COLLECTION = 'challenge_results';
const LEGACY_RE = /^weekly_(\d{4})-W(\d{2})$/;

/** Dart ile aynı: ChallengeService._isoWeekNumber */
function isoWeekNumber(date) {
  const startOfYear = new Date(date.getFullYear(), 0, 1);
  const dayOfYear =
    Math.floor((date - startOfYear) / 86400000) + 1;
  const weekday = date.getDay() === 0 ? 7 : date.getDay();
  return Math.floor((dayOfYear - weekday + 10) / 7);
}

function legacyWeeklyChallengeId(date) {
  const y = date.getFullYear();
  const w = isoWeekNumber(date);
  return `weekly_${y}-W${String(w).padStart(2, '0')}`;
}

function mondayOfWeek(date) {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = d.getDay() === 0 ? 7 : d.getDay();
  d.setDate(d.getDate() - (weekday - 1));
  return d;
}

function newWeeklyChallengeId(date) {
  const monday = mondayOfWeek(date);
  const y = monday.getFullYear();
  const m = String(monday.getMonth() + 1).padStart(2, '0');
  const day = String(monday.getDate()).padStart(2, '0');
  return `weekly_${y}-${m}-${day}`;
}

const legacyToNewCache = new Map();

function parseLegacyId(legacyId) {
  const m = legacyId.match(LEGACY_RE);
  if (!m) return null;
  return { year: parseInt(m[1], 10), week: parseInt(m[2], 10), raw: legacyId };
}

/** Yayındaki uygulamanın “bu hafta” / “geçen hafta” id’leri (Türkiye saati yeterli). */
function productionWeekIds(now = new Date()) {
  return {
    current: newWeeklyChallengeId(now),
    previous: newWeeklyChallengeId(
      new Date(mondayOfWeek(now).getTime() - 7 * 86400000),
    ),
  };
}

function mapLegacyToNew(legacyId) {
  if (legacyToNewCache.has(legacyId)) {
    return legacyToNewCache.get(legacyId);
  }
  const m = legacyId.match(LEGACY_RE);
  if (!m) return null;

  const year = parseInt(m[1], 10);
  let sampleDay = null;

  for (let month = 0; month < 12; month++) {
    for (let day = 1; day <= 31; day++) {
      const d = new Date(year, month, day);
      if (d.getMonth() !== month) continue;
      if (legacyWeeklyChallengeId(d) === legacyId) {
        sampleDay = d;
        break;
      }
    }
    if (sampleDay) break;
  }

  if (!sampleDay) {
    legacyToNewCache.set(legacyId, null);
    return null;
  }

  const newId = newWeeklyChallengeId(sampleDay);
  legacyToNewCache.set(legacyId, newId);
  return newId;
}

/**
 * Firestore’daki en güncel 1–2 legacy haftayı, yayındaki uygulamanın beklediği
 * bu hafta / geçen hafta id’lerine bağlar (W21 → 05-19, W20 → 05-12 gibi).
 */
function buildLegacyMapping(distinctLegacyIds, now = new Date()) {
  const { current, previous } = productionWeekIds(now);
  const sorted = distinctLegacyIds
    .map(parseLegacyId)
    .filter(Boolean)
    .sort((a, b) => a.year - b.year || a.week - b.week);

  const map = new Map();
  if (sorted.length === 0) return map;

  if (sorted.length === 1) {
    map.set(sorted[0].raw, current);
    return map;
  }

  map.set(sorted[sorted.length - 1].raw, current);
  map.set(sorted[sorted.length - 2].raw, previous);

  for (let i = 0; i < sorted.length - 2; i++) {
    const id = sorted[i].raw;
    const cal = mapLegacyToNew(id);
    if (cal) map.set(id, cal);
  }

  return map;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const confirm = process.argv.includes('--confirm');

  if (!dryRun && !confirm) {
    console.error('Önce: node scripts/migrate_weekly_challenge_ids.js --dry-run');
    console.error('Sonra: node scripts/migrate_weekly_challenge_ids.js --confirm');
    process.exit(1);
  }

  const snap = await db.collection(COLLECTION).get();
  const toUpdate = [];
  const mappingCounts = new Map();

  const distinctLegacy = [
    ...new Set(
      snap.docs
        .map((d) => d.data().challengeId)
        .filter((id) => id && LEGACY_RE.test(id)),
    ),
  ];
  const legacyMap = buildLegacyMapping(distinctLegacy);
  const { current, previous } = productionWeekIds();

  console.log(`Yayındaki uygulama bu hafta: ${current}`);
  console.log(`Yayındaki uygulama geçen hafta: ${previous}\n`);

  for (const doc of snap.docs) {
    const data = doc.data();
    const oldId = data.challengeId;
    if (!oldId || !LEGACY_RE.test(oldId)) continue;

    const newId = legacyMap.get(oldId) ?? mapLegacyToNew(oldId);
    if (!newId) {
      console.warn(`Eşleşme yok: ${oldId} (doc ${doc.id})`);
      continue;
    }
    if (newId === oldId) continue;

    toUpdate.push({ ref: doc.ref, docId: doc.id, oldId, newId, pilotName: data.pilotName });
    const key = `${oldId} → ${newId}`;
    mappingCounts.set(key, (mappingCounts.get(key) || 0) + 1);
  }

  console.log(`\nToplam doküman: ${snap.size}`);
  console.log(`Güncellenecek (eski W formatı): ${toUpdate.length}\n`);

  console.log('Hafta eşlemeleri:');
  for (const [k, n] of [...mappingCounts.entries()].sort()) {
    console.log(`  ${k}  (${n} kayıt)`);
  }

  if (toUpdate.length === 0) {
    console.log('\nTaşınacak kayıt yok (zaten yeni format veya boş).');
    process.exit(0);
  }

  if (dryRun) {
    console.log('\n--dry-run: örnek kayıtlar (en fazla 15):');
    for (const row of toUpdate.slice(0, 15)) {
      console.log(
        `  ${row.docId}\n    ${row.pilotName ?? '(isimsiz)'}  ${row.oldId} → ${row.newId}`,
      );
    }
    console.log('\nOnaylamak için: node scripts/migrate_weekly_challenge_ids.js --confirm');
    process.exit(0);
  }

  const BATCH = 400;
  let done = 0;
  for (let i = 0; i < toUpdate.length; i += BATCH) {
    const batch = db.batch();
    const chunk = toUpdate.slice(i, i + BATCH);
    for (const row of chunk) {
      batch.update(row.ref, { challengeId: row.newId });
    }
    await batch.commit();
    done += chunk.length;
    console.log(`Güncellendi: ${done}/${toUpdate.length}`);
  }

  console.log('\n✅ challengeId alanları yeni Pazartesi formatına çekildi.');
  console.log('Yayındaki uygulama (yeni id ile sorgulayan) listeyi tekrar göstermeli.');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
