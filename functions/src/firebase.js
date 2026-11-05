// Klien Identity Toolkit (Firebase Auth) lewat REST, tanpa firebase-admin. Jalan di Cloudflare Workers dan Node.
// Akses admin memakai token service account (JWT RS256). Sandi pengguna hanya dikirim ke Google; tidak pernah dicatat.
import { SignJWT, importPKCS8 } from 'jose';

const IDT = 'https://identitytoolkit.googleapis.com/v1';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

let cfg = null;
let tokenCache = null;

// Dipanggil sekali per request dengan env. projectId, saJson (JSON service account), apiKey (kunci web publik).
// Tidak melempar bila saJson belum diisi: jalur login dan demo tidak membutuhkannya. Admin memeriksanya saat dipakai.
export function configurarFirebase({ projectId, saJson, apiKey }) {
  let sa = null;
  if (saJson) {
    try {
      sa = typeof saJson === 'string' ? JSON.parse(saJson) : saJson;
    } catch {
      sa = null;
    }
  }
  cfg = { projectId, sa, apiKey };
}

async function accessToken() {
  if (!cfg?.sa) throw new Error('FIREBASE_SA_JSON belum diisi');
  const sekarang = Math.floor(Date.now() / 1000);
  if (tokenCache && tokenCache.exp - 60 > sekarang) return tokenCache.token;
  const kunci = await importPKCS8(cfg.sa.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/identitytoolkit' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(cfg.sa.client_email)
    .setSubject(cfg.sa.client_email)
    .setAudience(TOKEN_URL)
    .setIssuedAt(sekarang)
    .setExpirationTime(sekarang + 3600)
    .sign(kunci);
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!res.ok) throw new Error(`token service account gagal: ${res.status}`);
  const body = await res.json();
  tokenCache = { token: body.access_token, exp: sekarang + (body.expires_in || 3600) };
  return tokenCache.token;
}

// Kode galat Identity Toolkit dipetakan ke kode yang dipakai kode lain (mis. auth/email-already-exists).
const PETA_GALAT = { EMAIL_EXISTS: 'auth/email-already-exists', USER_NOT_FOUND: 'auth/user-not-found' };

async function admin(path, body) {
  const res = await fetch(`${IDT}/projects/${cfg.projectId}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await accessToken()}` },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const pesan = json?.error?.message || `HTTP ${res.status}`;
    const err = new Error(pesan);
    err.code = PETA_GALAT[pesan.split(':')[0]] || pesan;
    throw err;
  }
  return json;
}

function klaimDariAtribut(teks) {
  if (!teks) return {};
  try {
    return JSON.parse(teks);
  } catch {
    return {};
  }
}

export function firebaseAuth() {
  if (!cfg) throw new Error('configurarFirebase belum dipanggil');
  return {
    async createUser({ email, password, emailVerified = false }) {
      const json = await admin('/accounts', { email, password, emailVerified });
      return { uid: json.localId };
    },
    async deleteUser(uid) {
      await admin('/accounts:delete', { localId: uid });
    },
    async getUser(uid) {
      const json = await admin('/accounts:lookup', { localId: [uid] });
      const user = json.users?.[0];
      if (!user) {
        const err = new Error('user tidak ditemukan');
        err.code = 'auth/user-not-found';
        throw err;
      }
      return { uid: user.localId, email: user.email, customClaims: klaimDariAtribut(user.customAttributes) };
    },
    async updateUser(uid, { password }) {
      await admin('/accounts:update', { localId: uid, password });
    },
    async setCustomUserClaims(uid, claims) {
      await admin('/accounts:update', { localId: uid, customAttributes: JSON.stringify(claims) });
    },
    async revokeRefreshTokens(uid) {
      // validSince dalam detik: token yang diterbitkan sebelum ini tidak berlaku lagi.
      await admin('/accounts:update', { localId: uid, validSince: String(Math.floor(Date.now() / 1000)) });
    },
    async generatePasswordResetLink(email) {
      const res = await fetch(`${IDT}/accounts:sendOobCode?key=${encodeURIComponent(cfg.apiKey)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestType: 'PASSWORD_RESET', email, returnOobLink: true }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        const err = new Error(json?.error?.message || `HTTP ${res.status}`);
        err.code = PETA_GALAT[json?.error?.message] || json?.error?.message;
        throw err;
      }
      return json.oobLink;
    },
  };
}
