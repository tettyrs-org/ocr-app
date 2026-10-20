// BFF untuk aplikasi admin (ocr-admin). Terpisah dari BFF aplikasi utama: origin, cookie, dan endpoint berbeda.
// Hanya pengguna ber-role ADMIN yang diterima. Kontrak: documents/tech/admin-bff.md
import { randomToken } from './crypto.js';
import { createHash } from 'node:crypto';
import { firebaseAuth } from './firebase.js';
import { sendMail } from './mail.js';
import { SESSION_COOKIE, clearCookie } from './cookies.js';
import { now, verifyIdToken, rolesFrom, sessionFrom, sessionCookie, newSession, ALLOWED_ROLES } from './auth.js';

const PREFIX = '/admin/api';
const ALLOW_HEADERS = 'Content-Type, X-CSRF-Token';
const ALLOW_METHODS = 'GET, POST, PATCH, OPTIONS';

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  if (origin !== env.ADMIN_APP_ORIGIN) return {};
  return {
    'Access-Control-Allow-Origin': env.ADMIN_APP_ORIGIN,
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

function requireAdmin(roles) {
  return roles.includes('ADMIN');
}


// Membaca dan memeriksa sesi admin. Mengembalikan sesi atau Response error.
async function adminSession(request, env) {
  const session = await sessionFrom(request, env.COOKIE_KEY);
  if (!session) return { error: errorResponse('UNAUTHENTICATED', 'Sesi tidak ada atau sudah habis', 401, corsHeaders(request, env)) };
  if (!requireAdmin(session.roles)) return { error: errorResponse('FORBIDDEN', 'Hanya admin yang boleh mengakses', 403, corsHeaders(request, env)) };
  return { session };
}

function checkCsrf(request, session) {
  return request.headers.get('X-CSRF-Token') === session.csrf;
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function validRoles(input) {
  if (!Array.isArray(input) || input.length === 0) return null;
  const roles = input.map((r) => String(r).trim().toUpperCase());
  if (roles.some((r) => !ALLOWED_ROLES.includes(r))) return null;
  return [...new Set(roles)];
}

// Meneruskan request ke API (Java) dengan ID token admin. API menerapkan role-nya sendiri.
async function callApi(env, idToken, method, path, body) {
  const res = await fetch(`${env.API_BASE}/api/v1/admin${path}`, {
    method,
    headers: { Authorization: `Bearer ${idToken}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return res;
}

async function handleSession(request, env) {
  const match = (request.headers.get('Authorization') ?? '').match(/^Bearer\s+(.+)$/);
  if (!match) return errorResponse('UNAUTHENTICATED', 'ID token wajib dikirim', 401, corsHeaders(request, env));

  let payload;
  try {
    payload = await verifyIdToken(match[1], env.FIREBASE_PROJECT_ID);
  } catch {
    return errorResponse('UNAUTHENTICATED', 'ID token tidak valid', 401, corsHeaders(request, env));
  }

  const roles = rolesFrom(payload);
  if (!requireAdmin(roles)) return errorResponse('FORBIDDEN', 'Hanya admin yang boleh masuk', 403, corsHeaders(request, env));

  const session = newSession({ idToken: match[1], payload, roles });
  const headers = { ...corsHeaders(request, env), 'Set-Cookie': await sessionCookie(session, env.COOKIE_KEY) };
  return json({ data: { sub: session.sub, roles: session.roles, csrfToken: session.csrf } }, 200, headers);
}

async function handleMe(request, env) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  const headers = { ...corsHeaders(request, env), 'Set-Cookie': await sessionCookie({ ...session, last: now() }, env.COOKIE_KEY) };
  return json({ data: { sub: session.sub, roles: session.roles, csrfToken: session.csrf } }, 200, headers);
}

async function handleLogout(request, env) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  if (!checkCsrf(request, session)) return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));
  const headers = new Headers({ ...corsHeaders(request, env), 'Cache-Control': 'no-store' });
  headers.append('Set-Cookie', clearCookie(SESSION_COOKIE));
  return new Response(null, { status: 204, headers });
}

async function handleListUsers(request, env) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  const res = await callApi(env, session.at, 'GET', '/users');
  const body = await res.text();
  const headers = { ...corsHeaders(request, env), 'Cache-Control': 'no-store', 'Content-Type': 'application/json' };
  return new Response(body, { status: res.status, headers });
}

// Undangan (auth-firebase.md bagian 8): token acak dibuat di sini, hanya hash-nya yang disimpan API.
// Tautan dengan token dikirim ke pegawai lewat email. Token tidak dicatat di log.
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function sha256Hex(text) {
  return createHash('sha256').update(text).digest('hex');
}

function inviteHtml(link) {
  return `<p>Anda diundang untuk mengaktifkan akun OCR Dokumen.</p>
<p><a href="${link}">Buka formulir aktivasi</a></p>
<p>Isi nama lengkap, NIP, dan sandi baru Anda. Formulir ini hanya bisa dipakai sekali dan berlaku 7 hari.</p>
<p>Jika Anda tidak merasa diundang, abaikan email ini.</p>`;
}

// Membuat undangan untuk akun yang belum lengkap profilnya, lalu mengirim emailnya.
// Mengembalikan 'sent', 'mail_failed' (undangan tersimpan tetapi email gagal), atau melempar error bila penyimpanan gagal. Akun tidak dibatalkan bila email gagal (admin bisa kirim ulang).
async function issueInvitation(env, idToken, uid, email) {
  const token = randomToken(32);
  const expiresAt = new Date(Date.now() + INVITE_TTL_MS).toISOString();
  const res = await callApi(env, idToken, 'POST', `/users/${encodeURIComponent(uid)}/invitations`, {
    token_hash: sha256Hex(token),
    expires_at: expiresAt,
  });
  if (!res.ok) throw new Error(`API undangan ${res.status}`);
  const link = `${env.APP_ORIGIN}/undangan#${token}`;
  const sent = await sendMail(env, { to: email, subject: 'Aktivasi akun OCR Dokumen', html: inviteHtml(link) });
  return sent ? 'sent' : 'mail_failed';
}

// Reset sandi oleh admin (auth-firebase.md bagian 8). Backend membuat kode reset lewat Admin SDK, lalu
// mengirim email berisi tautan ke halaman /reset aplikasi (tidak memakai action URL Firebase).
// Admin tidak bisa mengubah alamat email dan tidak pernah melihat sandi pegawai.
function resetHtml(link) {
  return `<p>Anda meminta atur ulang sandi akun OCR Dokumen.</p>
<p><a href="${link}">Atur ulang sandi</a></p>
<p>Tautan ini hanya bisa dipakai sekali. Jika Anda tidak meminta, abaikan email ini.</p>`;
}

async function sendPasswordReset(env, email) {
  const link = await firebaseAuth().generatePasswordResetLink(email);
  const oobCode = new URL(link).searchParams.get('oobCode');
  if (!oobCode) throw new Error('kode reset tidak dibuat');
  const resetLink = `${env.APP_ORIGIN}/reset?oobCode=${encodeURIComponent(oobCode)}`;
  return sendMail(env, { to: email, subject: 'Atur ulang sandi akun OCR Dokumen', html: resetHtml(resetLink) });
}

// Membuat akun: Firebase Auth + claim roles, baris di ocr_users lewat API (profile_completed = false),
// lalu undangan. Jika langkah API gagal, akun Firebase yang baru dibuat dihapus lagi (tidak ada akun yatim).
async function handleCreateUser(request, env) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  if (!checkCsrf(request, session)) return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));

  const input = await readJson(request);
  const email = typeof input?.email === 'string' ? input.email.trim().toLowerCase() : '';
  const roles = validRoles(input?.roles);
  if (!email.includes('@')) return errorResponse('VALIDATION_ERROR', 'Email tidak valid', 400, corsHeaders(request, env));
  if (!roles) return errorResponse('VALIDATION_ERROR', `Role harus salah satu dari: ${ALLOWED_ROLES.join(', ')}`, 400, corsHeaders(request, env));

  const auth = firebaseAuth();
  const unusedPassword = randomToken(24);
  let user;
  try {
    user = await auth.createUser({ email, password: unusedPassword, emailVerified: false });
  } catch (err) {
    const code = err?.code === 'auth/email-already-exists' ? 'CONFLICT' : 'INTERNAL_ERROR';
    const status = code === 'CONFLICT' ? 409 : 500;
    return errorResponse(code, code === 'CONFLICT' ? 'Email sudah terdaftar' : 'Gagal membuat akun', status, corsHeaders(request, env));
  }

  try {
    await auth.setCustomUserClaims(user.uid, { roles });
    const res = await callApi(env, session.at, 'POST', '/users', { uid: user.uid, email, roles });
    if (!res.ok) throw new Error(`API ${res.status}`);
  } catch (err) {
    await auth.deleteUser(user.uid).catch(() => {});
    console.error('pembuatan akun dibatalkan:', err?.message);
    return errorResponse('INTERNAL_ERROR', 'Akun tidak dibuat karena penyimpanan gagal. Coba lagi.', 502, corsHeaders(request, env));
  }

  // Undangan gagal tidak membatalkan akun: admin bisa mengirim ulang lewat POST /users/{uid}/invite.
  const invitation = await issueInvitation(env, session.at, user.uid, email).catch((err) => { console.error('undangan gagal:', err?.message); return 'failed'; });
  return json(
    { data: { uid: user.uid, email, roles, invitation } },
    201,
    corsHeaders(request, env),
  );
}

// Kirim ulang undangan untuk akun yang profilnya belum lengkap (admin-bff.md bagian 4).
async function handleResendInvite(request, env, uid) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  if (!checkCsrf(request, session)) return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));

  const res = await callApi(env, session.at, 'GET', '/users');
  if (!res.ok) return errorResponse('INTERNAL_ERROR', 'Gagal membaca data pengguna', 502, corsHeaders(request, env));
  const users = (await res.json())?.data ?? [];
  const target = users.find((u) => u.uid === uid);
  if (!target) return errorResponse('NOT_FOUND', 'Pengguna tidak ditemukan', 404, corsHeaders(request, env));
  if (target.profile_completed) {
    return errorResponse('PROFILE_ALREADY_COMPLETE', 'Profil pengguna ini sudah lengkap', 409, corsHeaders(request, env));
  }
  const invitation = await issueInvitation(env, session.at, uid, target.email).catch((err) => { console.error('undangan gagal:', err?.message); return 'failed'; });
  return json({ data: { uid, invitation } }, 200, corsHeaders(request, env));
}

// Reset sandi oleh admin (auth-firebase.md bagian 8). Email dikirim Firebase ke alamat akun yang tersimpan.
async function handlePasswordReset(request, env, uid) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  if (!checkCsrf(request, session)) return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));

  const res = await callApi(env, session.at, 'GET', '/users');
  if (!res.ok) return errorResponse('INTERNAL_ERROR', 'Gagal membaca data pengguna', 502, corsHeaders(request, env));
  const user = ((await res.json())?.data ?? []).find((u) => u.uid === uid);
  if (!user) return errorResponse('NOT_FOUND', 'Pengguna tidak ditemukan', 404, corsHeaders(request, env));
  const sent = await sendPasswordReset(env, user.email).catch((err) => { console.error('reset sandi gagal:', err?.code || err?.message); return false; });
  return json({ data: { uid, reset: sent ? 'sent' : 'failed' } }, sent ? 200 : 502, corsHeaders(request, env));
}

// Pencarian master pegawai untuk admin (api-spec.md bagian 12). Hanya membaca.
async function handleListEmployees(request, env) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  const q = new URL(request.url).searchParams.get('q') ?? '';
  const res = await callApi(env, session.at, 'GET', `/employees?q=${encodeURIComponent(q)}`);
  const body = await res.text();
  const headers = { ...corsHeaders(request, env), 'Cache-Control': 'no-store', 'Content-Type': 'application/json' };
  return new Response(body, { status: res.status, headers });
}

// Mengubah role: claim Firebase dan baris ocr_users. Jika API gagal, claim dikembalikan ke semula.
async function handleUpdateRoles(request, env, uid) {
  const { session, error } = await adminSession(request, env);
  if (error) return error;
  if (!checkCsrf(request, session)) return errorResponse('FORBIDDEN', 'CSRF token tidak valid', 403, corsHeaders(request, env));

  const input = await readJson(request);
  const roles = validRoles(input?.roles);
  if (!roles) return errorResponse('VALIDATION_ERROR', `Role harus salah satu dari: ${ALLOWED_ROLES.join(', ')}`, 400, corsHeaders(request, env));

  const auth = firebaseAuth();
  let before;
  try {
    before = await auth.getUser(uid);
  } catch {
    return errorResponse('NOT_FOUND', 'Akun tidak ditemukan', 404, corsHeaders(request, env));
  }
  const previousRoles = before.customClaims?.roles ?? [];

  try {
    await auth.setCustomUserClaims(uid, { roles });
    const res = await callApi(env, session.at, 'PUT', `/users/${encodeURIComponent(uid)}/roles`, { roles });
    if (!res.ok) throw new Error(`API ${res.status}`);
  } catch (err) {
    await auth.setCustomUserClaims(uid, { roles: previousRoles }).catch(() => {});
    console.error('perubahan role dibatalkan:', err?.message);
    return errorResponse('INTERNAL_ERROR', 'Role tidak diubah karena penyimpanan gagal. Coba lagi.', 502, corsHeaders(request, env));
  }

  return json({ data: { uid, roles } }, 200, corsHeaders(request, env));
}

export async function handleAdmin(request, env) {
  const url = new URL(request.url);
  const path = url.pathname;
  const origin = request.headers.get('Origin');

  if (request.method === 'OPTIONS') {
    if (origin !== env.ADMIN_APP_ORIGIN) return new Response(null, { status: 403 });
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }
  if (origin && origin !== env.ADMIN_APP_ORIGIN) {
    return errorResponse('FORBIDDEN', 'Origin tidak diizinkan', 403);
  }

  try {
    if (path === `${PREFIX}/session` && request.method === 'POST') return handleSession(request, env);
    if (path === `${PREFIX}/me` && request.method === 'GET') return handleMe(request, env);
    if (path === `${PREFIX}/logout` && request.method === 'POST') return handleLogout(request, env);
    if (path === `${PREFIX}/users` && request.method === 'GET') return handleListUsers(request, env);
    if (path === `${PREFIX}/users` && request.method === 'POST') return handleCreateUser(request, env);
    if (path === `${PREFIX}/employees` && request.method === 'GET') return handleListEmployees(request, env);
    const resetMatch = path.match(new RegExp(`^${PREFIX}/users/([^/]+)/password-reset$`));
    if (resetMatch && request.method === 'POST') return handlePasswordReset(request, env, decodeURIComponent(resetMatch[1]));
    const inviteMatch = path.match(new RegExp(`^${PREFIX}/users/([^/]+)/invite$`));
    if (inviteMatch && request.method === 'POST') return handleResendInvite(request, env, decodeURIComponent(inviteMatch[1]));
    const roleMatch = path.match(new RegExp(`^${PREFIX}/users/([^/]+)/roles$`));
    if (roleMatch && request.method === 'PATCH') return handleUpdateRoles(request, env, decodeURIComponent(roleMatch[1]));
  } catch {
    return errorResponse('INTERNAL_ERROR', 'Terjadi kesalahan di server', 500, corsHeaders(request, env));
  }
  return errorResponse('NOT_FOUND', 'Endpoint tidak ditemukan', 404);
}
