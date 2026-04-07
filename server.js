'use strict';

require('dotenv').config();

const Fastify   = require('fastify');
const cors      = require('@fastify/cors');
const rateLimit = require('@fastify/rate-limit');

// ── Config ────────────────────────────────────────────────────────────────────
const PORT          = process.env.PORT          || 3000;
const GROQ_API_KEY  = process.env.GROQ_API_KEY  || '';
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '*').split(',').map(s => s.trim());

const GROQ_BASE_URL  = 'https://api.groq.com/openai/v1';
const GROQ_MODEL     = 'llama-3.3-70b-versatile';
const GROQ_TIMEOUT_MS = 30_000;
const MAX_TOKENS     = 800;
const TEMPERATURE    = 0.4;
const MAX_INPUT_LEN  = 800;

// Sistem promptu — konu dışı soruları reddeder
const SYSTEM_PROMPT =
  'Sen SkyTest uygulamasının Havacılık İngilizcesi sınav koçususun. ' +
  'YALNIZCA aşağıdaki konularda yardım edersin: ' +
  'havacılık İngilizcesi, SHGM/EASA sınav soruları, İngilizce gramer (edat, modal, passive voice vb.), ' +
  'teknik havacılık terimleri, ATA chapter konuları, uçak bakım prosedürleri ve ilgili kelime bilgisi. ' +
  '\n\n' +
  'KESİNLİKLE YAPMA: Havacılık İngilizcesi veya havacılık tekniğiyle ilgisi olmayan hiçbir soruya yanıt verme. ' +
  'Güncel olaylar, siyaset, eğlence, yazılım, yemek tarifleri veya konu dışı her türlü istek için şunu söyle: ' +
  '"Bu konuda yardımcı olamam. Ben yalnızca Havacılık İngilizcesi ve SHGM/EASA sınav konuları için eğitildim." ' +
  '\n\n' +
  'YANIT TARZI: Türkçe açıkla. Kısa ve net tut. Gerektiğinde İngilizce örnek cümle ekle. ' +
  'Emin olmadığın konularda bunu açıkça belirt, asla yanlış bilgi uydurma.';

// ── Fastify ───────────────────────────────────────────────────────────────────
const app = Fastify({ logger: true });

// CORS
app.register(cors, {
  origin: ALLOWED_ORIGINS.includes('*') ? true : ALLOWED_ORIGINS,
  methods: ['GET', 'POST'],
});

// Rate-limit: IP başına dakikada 5 istek
app.register(rateLimit, {
  max:      5,
  timeWindow: '1 minute',
  errorResponseBuilder: () => ({
    statusCode: 429,
    error: 'Too Many Requests',
    message: 'Çok fazla istek gönderildi. Lütfen 1 dakika bekle.',
  }),
});

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', async () => ({
  status: 'ok',
  model:  GROQ_MODEL,
  time:   new Date().toISOString(),
}));

// ── POST /ask-ai ──────────────────────────────────────────────────────────────
app.post('/ask-ai', {
  schema: {
    body: {
      type: 'object',
      required: ['question'],
      properties: {
        question: { type: 'string', minLength: 1, maxLength: MAX_INPUT_LEN },
        context:  { type: 'string', enum: ['sinav', 'konular', 'kelime'] },
        language: { type: 'string' },
        level:    { type: 'string', enum: ['kisa', 'detayli'] },
      },
    },
  },
}, async (request, reply) => {
  if (!GROQ_API_KEY) {
    return reply.status(500).send({ error: 'Sunucu yapılandırma hatası: API key eksik.' });
  }

  const { question, level = 'kisa' } = request.body;

  const levelNote = level === 'detayli'
    ? ' Detaylı ve kapsamlı açıkla.'
    : ' Kısa ve öz tut, en fazla 3-4 cümle.';

  const payload = {
    model:       GROQ_MODEL,
    temperature: TEMPERATURE,
    max_tokens:  MAX_TOKENS,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT + levelNote },
      { role: 'user',   content: question },
    ],
  };

  // Node 18 yerleşik fetch (node-fetch fallback)
  const fetchFn = globalThis.fetch ?? (await import('node-fetch')).default;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GROQ_TIMEOUT_MS);

  try {
    const res = await fetchFn(`${GROQ_BASE_URL}/chat/completions`, {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${GROQ_API_KEY}`,
      },
      body:   JSON.stringify(payload),
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (res.status === 401) {
      return reply.status(401).send({ error: 'Geçersiz API key.' });
    }
    if (res.status === 429) {
      return reply.status(429).send({ error: 'Çok fazla istek gönderildi. Lütfen biraz bekle.' });
    }
    if (!res.ok) {
      return reply.status(502).send({ error: `Groq hatası: ${res.status}` });
    }

    const data    = await res.json();
    const content = data?.choices?.[0]?.message?.content?.trim() ?? '';

    return reply.send({ answer: content || 'Cevap alınamadı.' });

  } catch (err) {
    clearTimeout(timer);
    if (err.name === 'AbortError') {
      return reply.status(504).send({ error: 'İstek zaman aşımına uğradı. Tekrar dene.' });
    }
    app.log.error(err);
    return reply.status(500).send({ error: 'Sunucu hatası. Tekrar dene.' });
  }
});

// ── Başlat ────────────────────────────────────────────────────────────────────
app.listen({ port: Number(PORT), host: '0.0.0.0' }, (err) => {
  if (err) {
    app.log.error(err);
    process.exit(1);
  }
});
