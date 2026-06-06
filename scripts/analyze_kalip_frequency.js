/**
 * sorular.json ↔ kaliplar.json frekans analizi
 *
 * Eşleştirme:
 * 1) Tam ifade (anchor + edat): "in accordance with", "prior to" …
 * 2) Boşluk + tek edat şıkkı: responsible _______ → for
 * 3) Doğru şıkta tam ifade
 */
const fs = require('fs');
const path = require('path');

const sorular = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../assets/sorular.json'), 'utf8'),
);
const kaliplar = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../assets/kaliplar.json'), 'utf8'),
);

function norm(s) {
  return (s || '').toLowerCase().replace(/\s+/g, ' ').trim();
}

function anchorFromIpucu(ipucu) {
  const m = ipucu.match(/^(.+?)\s*_{2,}/);
  return m ? norm(m[1]) : norm(ipucu);
}

function tamIfade(kalip) {
  return `${anchorFromIpucu(kalip.ipucu_kalip)} ${norm(kalip.tamamlayici)}`;
}

/** Fiil çekimi / pasif formlar — aynı kalıp kartına bağlanır */
const PHRASE_ALIASES = {
  'depend on': ['depends on', 'depending on'],
  'depends on': ['depend on', 'depending on'],
  'depending on': ['depends on', 'depend on'],
  'replace with': ['replaced with'],
  'replaced with': ['replace with'],
  'inspect for': ['inspected for'],
  'inspected for': ['inspect for'],
  'refer to': ['referred to'],
  'referred to': ['refer to'],
  'results in': ['resulting in', 'result in'],
  'resulting in': ['results in', 'result in'],
  'result in': ['results in', 'resulting in'],
  'prevent from': [
    'prevents from',
    'prevented from',
    'prevents the outside pressure from',
  ],
  'protect from': [
    'protects from',
    'protected from',
    'protect the fuselage from',
    'protects the fuselage from',
  ],
};

function ifadelerForKalip(kalip) {
  const base = tamIfade(kalip);
  const set = new Set([base]);
  for (const a of PHRASE_ALIASES[base] || []) set.add(a);
  return [...set];
}

function soruTumMetin(soru) {
  const parts = [
    soru.soru_metni,
    soru.paragraf,
    soru.neden_dogru,
    soru.tip,
    soru.yanlislar,
    ...Object.values(soru.secenekler || {}),
  ];
  return norm(parts.join(' '));
}

function blankRegexFromIpucu(ipucu) {
  const anchor = anchorFromIpucu(ipucu);
  const escaped = anchor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`${escaped}\\s*(_{2,}|…+)`, 'i');
}

function soruMetinleri(s) {
  return [s.soru_metni, s.paragraf].filter(Boolean).join(' ');
}

function dogruSecenek(s) {
  return norm(s.secenekler?.[s.dogru_cevap] || '');
}

function soruBlankEdatUyuyor(soru, kalip) {
  const text = soruMetinleri(soru);
  if (!text) return false;
  if (!blankRegexFromIpucu(kalip.ipucu_kalip).test(text)) return false;
  return dogruSecenek(soru) === norm(kalip.tamamlayici);
}

function soruKalibeUyuyor(soru, kalip) {
  const text = soruTumMetin(soru);
  const dogru = dogruSecenek(soru);
  const soruNorm = norm(soru.soru_metni || '');

  for (const phrase of ifadelerForKalip(kalip)) {
    if (text.includes(phrase)) return true;
    if (dogru === phrase || dogru.includes(phrase)) return true;
    if (soruNorm.includes(phrase)) return true;
  }
  if (soruBlankEdatUyuyor(soru, kalip)) return true;
  return false;
}

// Tekrarlayan kalıpları birleştir (aynı anchor|edat)
const kalipGruplari = new Map();
for (const k of kaliplar) {
  const key = tamIfade(k);
  if (!kalipGruplari.has(key)) {
    kalipGruplari.set(key, { temsil: k, tum_idler: [] });
  }
  kalipGruplari.get(key).tum_idler.push(k.id);
}

const kalipFrekans = [];
for (const [, grup] of kalipGruplari) {
  const k = grup.temsil;
  const eslesen = sorular.filter((s) => soruKalibeUyuyor(s, k));
  kalipFrekans.push({
    kalip_id: k.id,
    kalip_idleri: grup.tum_idler,
    ipucu_kalip: k.ipucu_kalip,
    tamamlayici: k.tamamlayici,
    tam_ifade: tamIfade(k),
    kategori: k.kategori,
    soru_sayisi: eslesen.length,
    soru_idleri: eslesen.map((s) => s.id),
  });
}
kalipFrekans.sort((a, b) => b.soru_sayisi - a.soru_sayisi);

// JSON'da olmayan: sorularda geçen edat kalıpları
const bilinenIfadeler = new Set();
for (const k of kaliplar) {
  for (const p of ifadelerForKalip(k)) bilinenIfadeler.add(p);
}

const EDAT_PHRASES = [
  /\b(in accordance with)\b/gi,
  /\b(prior to)\b/gi,
  /\b(due to)\b/gi,
  /\b(as well as)\b/gi,
  /\b(as soon as)\b/gi,
  /\b(responsible for)\b/gi,
  /\b(equipped with)\b/gi,
  /\b(provided with)\b/gi,
  /\b(prevent(?:ed|s|ing)?\s+\w+(?:\s+\w+){0,4}\s+from)\b/gi,
  /\b(protect(?:ed|s|ing)?\s+\w+(?:\s+\w+){0,4}\s+from)\b/gi,
  /\b(consists of)\b/gi,
  /\b(composed of)\b/gi,
  /\b(comply with)\b/gi,
  /\b(depend(?:s|ed|ing)? on)\b/gi,
  /\b(subject to)\b/gi,
  /\b(associated with)\b/gi,
  /\b(refer(?:s|red|ring)? to)\b/gi,
  /\b(regardless of)\b/gi,
  /\b(capable of)\b/gi,
  /\b(result(?:s|ed|ing)? in)\b/gi,
  /\b(exposed to)\b/gi,
  /\b(instead of)\b/gi,
  /\b(replace(?:d|s|ment)?\s+with)\b/gi,
  /\b(inspect(?:ed|ion)?\s+for)\b/gi,
  /\b(approved by)\b/gi,
  /\b(rely on)\b/gi,
  /\b(susceptible to)\b/gi,
  /\b(according to)\b/gi,
  /\b(based on)\b/gi,
  /\b(aware of)\b/gi,
  /\b(familiar with)\b/gi,
];

const bilinmeyenMap = new Map();

for (const soru of sorular) {
  const text = soruTumMetin(soru);
  for (const re of EDAT_PHRASES) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(text)) !== null) {
      const phrase = norm(m[1]);
      if (bilinenIfadeler.has(phrase)) continue;
      if (!bilinmeyenMap.has(phrase)) {
        const parts = phrase.split(' ');
        const edat = parts.pop();
        const anchor = parts.join(' ');
        bilinmeyenMap.set(phrase, {
          tam_ifade: phrase,
          ipucu_kalip: `${anchor} _______`,
          tamamlayici: edat.toUpperCase(),
          soru_sayisi: 0,
          soru_idleri: [],
          ornek_soru: (soru.soru_metni || '').slice(0, 140),
        });
      }
      const e = bilinmeyenMap.get(phrase);
      if (!e.soru_idleri.includes(soru.id)) {
        e.soru_sayisi++;
        e.soru_idleri.push(soru.id);
      }
    }
  }
}

const bilinmeyen = [...bilinmeyenMap.values()].sort(
  (a, b) => b.soru_sayisi - a.soru_sayisi,
);

const sifir = kalipFrekans.filter((k) => k.soru_sayisi === 0).length;
const toplamEslesme = kalipFrekans.reduce((a, k) => a + k.soru_sayisi, 0);

console.log('=== KALIP FREKANS ÖZET ===');
console.log(`Benzersiz kalıp ifadesi: ${kalipFrekans.length} (kaynak: ${kaliplar.length})`);
console.log(`Soruda geçen: ${kalipFrekans.filter((k) => k.soru_sayisi > 0).length}`);
console.log(`Soruda hiç çıkmayan: ${sifir}`);
console.log(`Toplam eşleşme (soru×kalıp): ${toplamEslesme}`);
console.log(`JSON'da olmayan ifade: ${bilinmeyen.length}`);

console.log('\n--- EN ÇOK ÇIKAN 30 ---');
kalipFrekans.slice(0, 30).forEach((k, i) => {
  console.log(
    `${i + 1}. [${k.soru_sayisi}x] ${k.tam_ifade} (id:${k.kalip_id})`,
  );
});

console.log("\n--- JSON'DA OLMAYAN (≥2 soru) ---");
bilinmeyen
  .filter((b) => b.soru_sayisi >= 2)
  .forEach((b, i) => {
    console.log(`${i + 1}. [${b.soru_sayisi}x] ${b.tam_ifade}`);
  });

const sikKaliplar = kalipFrekans
  .filter((k) => k.soru_sayisi > 0)
  .map((k) => {
    const orig = kaliplar.find((x) => x.id === k.kalip_id);
    return {
      ...orig,
      soru_sayisi: k.soru_sayisi,
      tam_ifade: k.tam_ifade,
      soru_idleri: k.soru_idleri,
    };
  });

const sikBilinmeyen = bilinmeyen
  .filter((b) => b.soru_sayisi >= 2)
  .map((b, i) => ({
    id: -(i + 1),
    kategori: 'Soruda_Sik',
    ipucu_kalip: b.ipucu_kalip,
    tamamlayici: b.tamamlayici,
    turkce_anlami: 'Soru bankasında sık geçen kalıp',
    ornek_cumle: b.ornek_soru,
    taktik: `"${b.tam_ifade}" ifadesi ${b.soru_sayisi} soruda geçiyor.`,
    soru_sayisi: b.soru_sayisi,
    tam_ifade: b.tam_ifade,
    soru_idleri: b.soru_idleri,
    json_disi: true,
  }));

const out = {
  generated_at: new Date().toISOString(),
  ozet: {
    benzersiz_kalip: kalipFrekans.length,
    eslesen_kalip: kalipFrekans.filter((k) => k.soru_sayisi > 0).length,
    sifir_kalip: sifir,
    json_disi_sik: sikBilinmeyen.length,
  },
  sik_kaliplar: sikKaliplar,
  json_disi_kaliplar: sikBilinmeyen,
};

const outPath = path.join(__dirname, '../assets/kaliplar_sik.json');
fs.writeFileSync(outPath, JSON.stringify(out, null, 2), 'utf8');
console.log(`\nYazıldı: ${outPath}`);
