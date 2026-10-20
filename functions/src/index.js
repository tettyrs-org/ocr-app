// BFF untuk aplikasi OCR (web dan mobile). Kontrak: documents/tech/web-bff.md dan auth-firebase.md.
import { SESSION_COOKIE, clearCookie } from './cookies.js';
import { handleInvitationCheck, handleInvitationRedeem } from './invitation.js';
import {
  now,
  verifyIdToken,
  rolesFrom,
  sessionFrom,
  sessionCookie,
  newSession,
} from './auth.js';

const ALLOW_HEADERS = 'Content-Type, X-CSRF-Token, Idempotency-Key, traceparent';
const ALLOW_METHODS = 'GET, POST, PUT, PATCH, DELETE, OPTIONS';

// Dua alamat aplikasi pengguna: domain utama dan domain situs default project (dipakai action URL reset sandi).
function isAppOrigin(origin, env) {
  return !!origin && (origin === env.APP_ORIGIN || origin === env.APP_ORIGIN_ALT);
}

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  if (!isAppOrigin(origin, env)) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Allow-Headers': ALLOW_HEADERS,
    'Access-Control-Allow-Methods': ALLOW_METHODS,
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
}

function json(body, status, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra },
  });
}

function errorResponse(code, message, status, extra = {}) {
  return json({ error: { code, message, details: null } }, status, extra);
}

async function handleSession(request, env) {
  const auth = request.headers.get('Authorization') ?? '';
  const match = auth.match(/^Bearer\s+(.+)$/);
  if (!match) return errorResponse('UNAUTHENTICATED', 'ID token wajib dikirim', 401, corsHeaders(request, env));

  let payload;
  try {
    payload = await verifyIdToken(match[1], env.FIREBASE_PROJECT_ID);
  } catch {
    return errorResponse('UNAUTHENTICATED', 'ID token tidak valid', 401, corsHeaders(request, env));
  }

  const roles = rolesFrom(payload);
  if (roles.length === 0) {
    return errorResponse('FORBIDDEN', 'Akun belum memiliki role', 403, corsHeaders(request, env));
  }

  const session = newSession({ idToken: match[1], payload, roles });
  const headers = { ...corsHeaders(request, env), 'Set-Cookie': await sessionCookie(session, env.COOKIE_KEY) };
  return json({ sub: session.sub, roles: session.roles, csrfToken: session.csrf }, 200, headers);
}

async function handleMe(request, env) {
  const session = await sessionFrom(request, env.COOKIE_KEY);
  if (!session) return errorResponse('UNAUTHENTICATED', 'Sesi tidak ada atau sudah habis', 401, corsHeaders(request, env));
  const headers = { ...corsHeaders(request, env), 'Set-Cookie': await sessionCookie({ ...session, last: now() }, env.COOKIE_KEY) };
  return json({ sub: session.sub, roles: session.roles, csrfToken: session.csrf }, 200, headers);
}

// Pemanggil bisa berupa browser (cookie __session) atau mobile (Bearer ID token per request).
// Browser tidak mengirim Bearer otomatis, jadi jalur Bearer tidak membuka celah CSRF.
async function callerFrom(request, env) {
  const session = await sessionFrom(request, env.COOKIE_KEY);
  if (session) return { session, viaCookie: true };

  const match = (request.headers.get('Authorization') ?? '').match(/^Bearer\s+(.+)$/);
  if (!match) return null;
  try {
    const payload = await verifyIdToken(match[1], env.FIREBASE_PROJECT_ID);
    const roles = rolesFrom(payload);
    if (roles.length === 0) return null;
    return { session: { at: match[1], sub: payload.sub, roles }, viaCookie: false };
  } catch (err) {
    console.error('verifikasi Bearer gagal:', err?.code, err?.message);
    return null;
  }
}

async function handleApi(request, env) {
  const caller = await callerFrom(request, env);
  if (!caller) return errorResponse('UNAUTHENTICATED', 'Sesi tidak ada atau sudah habis', 401, corsHeaders(request, env));
  const { session, viaCookie } = caller;

  if (viaCookie && request.method !== 'GET' && request.headers.get('X-CSRF-Token') !== session.csrf) {
    return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));
  }

  const url = new URL(request.url);
  // /bff/api/v1/x diteruskan ke API_BASE/api/v1/x (API melayani di bawah /api)
  const target = env.API_BASE + url.pathname.replace(/^\/bff\/api/, '/api') + url.search;
  const headers = new Headers();
  headers.set('Authorization', `Bearer ${session.at}`);
  for (const h of ['Content-Type', 'Idempotency-Key', 'traceparent']) {
    const v = request.headers.get(h);
    if (v) headers.set(h, v);
  }
  const hasBody = request.method !== 'GET' && request.method !== 'HEAD';
  const upstream = await fetch(target, {
    method: request.method,
    headers,
    body: hasBody ? request.body : undefined,
    // Node membutuhkan duplex untuk body berupa stream (unggahan multipart).
    ...(hasBody ? { duplex: 'half' } : {}),
  });

  const out = new Headers(upstream.headers);
  out.delete('Set-Cookie');
  for (const [k, v] of Object.entries(corsHeaders(request, env))) out.set(k, v);
  out.set('Cache-Control', 'no-store');
  if (viaCookie) out.append('Set-Cookie', await sessionCookie({ ...session, last: now() }, env.COOKIE_KEY));
  return new Response(upstream.body, { status: upstream.status, headers: out });
}

async function handleLogout(request, env) {
  const session = await sessionFrom(request, env.COOKIE_KEY);
  if (session && request.headers.get('X-CSRF-Token') !== session.csrf) {
    return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));
  }
  const headers = new Headers({ ...corsHeaders(request, env), 'Cache-Control': 'no-store' });
  headers.append('Set-Cookie', clearCookie(SESSION_COOKIE));
  return new Response(null, { status: 204, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin');

    if (request.method === 'OPTIONS') {
      if (!isAppOrigin(origin, env)) return new Response(null, { status: 403 });
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    if (origin && !isAppOrigin(origin, env)) {
      return errorResponse('FORBIDDEN', 'Origin tidak diizinkan', 403);
    }

    try {
      if (url.pathname === '/bff/session' && request.method === 'POST') return handleSession(request, env);
      if (url.pathname === '/bff/me' && request.method === 'GET') return handleMe(request, env);
      if (url.pathname === '/bff/logout' && request.method === 'POST') return handleLogout(request, env);
      if (url.pathname.startsWith('/bff/api/')) return handleApi(request, env);
      if (url.pathname === '/bff/undangan/cek' && request.method === 'POST') return handleInvitationCheck(request, env);
      if (url.pathname === '/bff/undangan/selesai' && request.method === 'POST') return handleInvitationRedeem(request, env);
    } catch {
      return errorResponse('INTERNAL_ERROR', 'Terjadi kesalahan di server', 500, corsHeaders(request, env));
    }
    return errorResponse('NOT_FOUND', 'Endpoint tidak ditemukan', 404);
  },
};
