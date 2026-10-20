// Autentikasi bersama: verifikasi ID token Firebase, role, dan sesi cookie.
// Dipakai oleh BFF aplikasi (index.js) dan BFF admin (admin.js).
// Kontrak: documents/tech/auth-firebase.md
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { randomToken, seal, unseal } from './crypto.js';
import { SESSION_COOKIE, MAX_COOKIE_BYTES, readCookie, setCookie } from './cookies.js';

export const IDLE_SECONDS = 30 * 60;
export const ABSOLUTE_SECONDS = 8 * 60 * 60;
export const ALLOWED_ROLES = ['USER', 'ADMIN', 'VIEWER'];

const FIREBASE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
);

export function now() {
  return Math.floor(Date.now() / 1000);
}

// Memverifikasi ID token: tanda tangan, issuer, audience, dan masa berlaku.
export async function verifyIdToken(idToken, projectId) {
  const { payload } = await jwtVerify(idToken, FIREBASE_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  return payload;
}

export function rolesFrom(payload) {
  const roles = Array.isArray(payload.roles) ? payload.roles : [];
  return roles.filter((r) => ALLOWED_ROLES.includes(r));
}

// Sesi valid bila belum idle, belum melewati batas mutlak, dan ID token belum kedaluwarsa.
// Tidak ada refresh di sini: klien memanggil ulang endpoint session dengan ID token baru.
export async function sessionFrom(request, cookieKey) {
  const raw = readCookie(request.headers.get('Cookie'), SESSION_COOKIE);
  if (!raw) return null;
  const session = await unseal(raw, cookieKey);
  if (!session) return null;
  const t = now();
  if (t - session.iat > ABSOLUTE_SECONDS || t - session.last > IDLE_SECONDS) return null;
  if (t >= session.exp) return null;
  return session;
}

export async function sessionCookie(session, cookieKey) {
  const sealed = await seal(session, cookieKey);
  if (sealed.length > MAX_COOKIE_BYTES) throw new Error('sesi terlalu besar');
  return setCookie(SESSION_COOKIE, sealed, IDLE_SECONDS);
}

export function newSession({ idToken, payload, roles }) {
  const t = now();
  return {
    at: idToken,
    exp: payload.exp,
    iat: t,
    last: t,
    sub: payload.sub,
    roles,
    csrf: randomToken(24),
  };
}
