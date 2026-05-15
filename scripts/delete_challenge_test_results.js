/**
 * Firestore challenge_results içinden test / istenmeyen kayıtları listeler veya siler.
 *
 * Önkoşul: Proje kökünde service-account.json (gitignore'da; Firebase Console →
 * Project settings → Service accounts → Generate new private key).
 *
 * Kullanım:
 *   node delete_challenge_test_results.js list weekly_2026-W20
 *   node delete_challenge_test_results.js list weekly_2026-W20
 *   node delete_challenge_test_results.js list weekly_2026-W20 deneme   (pilotName/userId parça)
 *   node delete_challenge_test_results.js delete weekly_2026-W20 --exact-pilot "TestNick"
 *   node delete_challenge_test_results.js delete weekly_2026-W20 --contains Admin --dry-run
 *   node delete_challenge_test_results.js delete weekly_2026-W20 --contains Admin --confirm
 *   node delete_challenge_test_results.js delete-doc "weekly_2026-W20__USER_UID_HERE" --confirm
 *
 * Haftalık challenge ID formatı uygulamayla aynı: weekly_<yıl>-W<hafta> (ör. weekly_2026-W19).
 */

const admin = require('firebase-admin');

try {
  // eslint-disable-next-line import/no-unresolved
  const serviceAccount = require('../service-account.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} catch (e) {
  console.error(
    'service-account.json bulunamadı veya hatalı. Proje köküne koyduğundan emin ol.',
  );
  console.error(e.message);
  process.exit(1);
}

const db = admin.firestore();
const COLLECTION = 'challenge_results';

function parseArgs() {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  const rest = argv.slice(1);
  const flags = new Set();
  const pos = [];
  for (const a of rest) {
    if (a.startsWith('--')) flags.add(a);
    else pos.push(a);
  }
  return { cmd, pos, flags };
}

async function fetchByChallenge(challengeId) {
  const snap = await db
    .collection(COLLECTION)
    .where('challengeId', '==', challengeId)
    .limit(500)
    .get();
  return snap.docs.map((d) => ({ ref: d.ref, id: d.id, ...d.data() }));
}

async function cmdList(challengeId, flags, pos) {
  const rows = await fetchByChallenge(challengeId);
  const containEq = [...flags]
    .find((f) => f.startsWith('--contains='))
    ?.slice('--contains='.length);
  const contain = containEq || pos[1] || null;

  let filtered = rows;
  if (contain) {
    const q = String(contain).toLowerCase();
    filtered = rows.filter(
      (r) =>
        String(r.pilotName || '')
          .toLowerCase()
          .includes(q) ||
        String(r.userId || '')
          .toLowerCase()
          .includes(q),
    );
  }

  filtered.sort((a, b) => (b.score || 0) - (a.score || 0));

  console.log(
    `\n${COLLECTION} — challengeId=${challengeId} — ${filtered.length}/${rows.length} satır\n`,
  );
  for (const r of filtered) {
    const pn = r.pilotName ?? '(yok)';
    const uid = r.userId ?? '';
    const sc = r.score ?? 0;
    console.log(`  doc: ${r.id}`);
    console.log(`       pilotName: ${pn}  userId: ${uid}  score: ${sc}\n`);
  }

  if (rows.length >= 500) {
    console.warn(
      'Uyarı: Bu challenge için en az 500 kayıt olabilir; sorgu limiti 500. Eksik görünüyorsa Console’dan veya birden fazla filtreyle kontrol et.',
    );
  }
}

async function cmdDelete(challengeId, flags) {
  const dry = flags.has('--dry-run');
  const confirm = flags.has('--confirm');

  const exactFlag = [...flags].find((f) => f.startsWith('--exact-pilot='));
  const containFlag = [...flags].find((f) => f.startsWith('--contains='));
  const exact = exactFlag ? exactFlag.slice('--exact-pilot='.length) : '';
  const contains = containFlag ? containFlag.slice('--contains='.length) : '';

  if (!exact && !contains) {
    console.error(
      'Silme için --exact-pilot=İsim veya --contains=parça kullan (ör. --contains=test).',
    );
    process.exit(1);
  }

  const rows = await fetchByChallenge(challengeId);
  let toDelete = rows;
  if (exact) {
    toDelete = rows.filter((r) => String(r.pilotName || '') === exact);
  } else {
    const q = contains.toLowerCase();
    toDelete = rows.filter((r) =>
      String(r.pilotName || '')
        .toLowerCase()
        .includes(q),
    );
  }

  console.log(`Silinecek kayıt: ${toDelete.length}`);
  for (const r of toDelete) {
    console.log(`  - ${r.id} | pilotName: ${r.pilotName}`);
  }

  if (dry) {
    console.log('\n(dry-run: hiçbir şey silinmedi)');
    return;
  }

  if (!confirm) {
    console.log(
      '\nGerçekten silmek için komuta --confirm ekle (yanlışlıkla silmeyi önlemek için).',
    );
    process.exit(1);
  }

  let batch = db.batch();
  let n = 0;
  for (const r of toDelete) {
    batch.delete(r.ref);
    n++;
    if (n % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (n % 450 !== 0) await batch.commit();
  console.log(`\n✅ ${toDelete.length} doküman silindi.`);
}

async function cmdDeleteDoc(docId, flags) {
  const dry = flags.has('--dry-run');
  const confirm = flags.has('--confirm');
  const ref = db.collection(COLLECTION).doc(docId);
  const snap = await ref.get();
  if (!snap.exists) {
    console.error('Doküman yok:', docId);
    process.exit(1);
  }
  const d = snap.data();
  console.log('Silinecek:', docId, d);

  if (dry) {
    console.log('(dry-run)');
    return;
  }
  if (!confirm) {
    console.log('\nSilmek için --confirm ekle.');
    process.exit(1);
  }
  await ref.delete();
  console.log('✅ Silindi.');
}

async function main() {
  const { cmd, pos, flags } = parseArgs();

  if (!cmd || cmd === '--help' || cmd === '-h') {
    console.log(`
Komutlar:
  list <weekly_YYYY-Www> [filtre_metni]
  delete <weekly_YYYY-Www> --exact-pilot=Ad [--dry-run] [--confirm]
  delete <weekly_YYYY-Www> --contains=parça [--dry-run] [--confirm]
  delete-doc <docId> [--dry-run] [--confirm]
`);
    process.exit(0);
  }

  if (cmd === 'list') {
    const challengeId = pos[0];
    if (!challengeId) {
      console.error('Örnek: node delete_challenge_test_results.js list weekly_2026-W20');
      process.exit(1);
    }
    await cmdList(challengeId, flags, pos);
    process.exit(0);
  }

  if (cmd === 'delete') {
    const challengeId = pos[0];
    if (!challengeId) {
      console.error('Örnek: ... delete weekly_2026-W20 --contains=test --confirm');
      process.exit(1);
    }
    await cmdDelete(challengeId, flags);
    process.exit(0);
  }

  if (cmd === 'delete-doc') {
    const docId = pos[0];
    if (!docId) {
      console.error('Örnek: ... delete-doc "weekly_2026-W20__abc123" --confirm');
      process.exit(1);
    }
    await cmdDeleteDoc(docId, flags);
    process.exit(0);
  }

  console.error('Bilinmeyen komut:', cmd);
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
