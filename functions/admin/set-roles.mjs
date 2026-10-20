// Mengatur role pengguna yang sudah ada: custom claim di Firebase Auth + baris di ocr_users.
// Kontrak: documents/tech/auth-firebase.md bagian 8. Dijalankan lewat set-roles.ps1 (Docker, jaringan API).
//
// Pemakaian:
//   node admin/set-roles.mjs --email user@example.com --roles USER
//
// Perubahan role berlaku pada ID token berikutnya (paling lama 1 jam) atau saat pengguna login ulang.
import { parseArgs } from 'node:util';
import admin from 'firebase-admin';
import pg from 'pg';

const ALLOWED_ROLES = ['USER', 'ADMIN', 'VIEWER'];

const { values } = parseArgs({
  options: {
    email: { type: 'string' },
    roles: { type: 'string' },
  },
});

function fail(message) {
  console.error(`Gagal: ${message}`);
  process.exit(1);
}

if (!values.email || !values.email.includes('@')) fail('--email wajib diisi dengan email yang valid');
if (!values.roles) fail('--roles wajib diisi, mis. USER atau USER,ADMIN');
if (!process.env.DATABASE_URL) fail('DATABASE_URL belum diatur');

const roles = values.roles.split(',').map((r) => r.trim().toUpperCase()).filter(Boolean);
const invalid = roles.filter((r) => !ALLOWED_ROLES.includes(r));
if (roles.length === 0 || invalid.length > 0) {
  fail(`role tidak valid: ${invalid.join(', ') || '(kosong)'}. Pilihan: ${ALLOWED_ROLES.join(', ')}`);
}

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const auth = admin.auth();
const db = new pg.Client({ connectionString: process.env.DATABASE_URL });

const user = await auth.getUserByEmail(values.email).catch(() => null);
if (!user) fail(`akun Firebase untuk ${values.email} tidak ditemukan`);

try {
  await auth.setCustomUserClaims(user.uid, { roles });
  await db.connect();
  await db.query(
    `INSERT INTO ocr_users (uid, email, roles, must_change_password)
     VALUES ($1, $2, $3, FALSE)
     ON CONFLICT (uid) DO UPDATE SET roles = EXCLUDED.roles, email = EXCLUDED.email`,
    [user.uid, values.email, roles],
  );
} finally {
  await db.end().catch(() => {});
}

console.log(`Role untuk ${values.email} diatur ke: ${roles.join(', ')}`);
console.log(`uid: ${user.uid}`);
