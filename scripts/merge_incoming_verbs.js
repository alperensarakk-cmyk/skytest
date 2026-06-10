/**
 * Eksik fiilleri user_sozluk_ai.json'a ekler (mevcut anahtarları değiştirmez).
 * Kullanım: node scripts/merge_incoming_verbs.js scripts/incoming_verbs_sozluk.json
 */
const fs = require('fs');
const path = require('path');

const incomingPath = process.argv[2];
if (!incomingPath) {
  console.error('Kullanım: node scripts/merge_incoming_verbs.js <incoming.json>');
  process.exit(1);
}

const dictPath = path.join(__dirname, '../assets/user_sozluk_ai.json');
const existing = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
const incoming = JSON.parse(fs.readFileSync(incomingPath, 'utf8'));

const byLower = new Map();
for (const k of Object.keys(existing)) {
  byLower.set(k.toLowerCase(), k);
}

const added = [];
const skipped = [];

for (const [key, value] of Object.entries(incoming)) {
  const lk = key.toLowerCase();
  if (byLower.has(lk)) {
    skipped.push(key);
    continue;
  }
  existing[key] = value;
  byLower.set(lk, key);
  added.push(key);
}

const sorted = Object.fromEntries(
  Object.keys(existing)
    .sort((a, b) => a.localeCompare(b, 'en'))
    .map((k) => [k, existing[k]]),
);

fs.writeFileSync(dictPath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');

console.log('Mevcut:', Object.keys(existing).length - added.length);
console.log('Gelen:', Object.keys(incoming).length);
console.log('Eklenen:', added.length);
console.log('Zaten vardı (atlandı):', skipped.length);
if (added.length) {
  console.log('\nEklenen kelimeler:');
  console.log(added.join(', '));
}
