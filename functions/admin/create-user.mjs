// Membuat akun pengguna oleh admin: Firebase Authentication + custom claim roles + baris di ocr_users.
// Kontrak: documents/tech/auth-firebase.md bagian 8.
//
// Pemakaian (dari folder app/functions):
//   node admin/create-user.mjs --email user@example.com --roles USER
//   node admin/create-user.mjs --email admin@example.com --roles USER,ADMIN
//
// Prasyarat:
//   - GOOGLE_APPLICATION_CREDENTIALS: path ke kunci service account admin (JANGAN disimpan di repo)
//   - DATABASE_URL: koneksi PostgreSQL, mis. postgres://ocr_db_dev:...@localhost:5432/ocr_results
import { randomBytes } from 'node:crypto';
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

const roles = values.roles.split(',').map((r) => r.trim().toUpperCase()).filter(Boolean);
const invalid = roles.filter((r) => !ALLOWED_ROLES.includes(r));
if (roles.length === 0 || invalid.length > 0) {
  fail(`role tidak valid: ${invalid.join(', ') || '(kosong)'}. Pilihan: ${ALLOWED_ROLES.join(', ')}`);
}
if (!process.env.DATABASE_URL) fail('DATABASE_URL belum diatur');

admin.initializeApp({ credential: admin.credential.applicationDefault() });
const auth = admin.auth();
const db = new pg.Client({ connectionString: process.env.DATABASE_URL });

// Password sementara: acak, ditampilkan sekali, dan wajib diganti pengguna.
const tempPassword = randomBytes(12).toString('base64url');

const user = await auth.createUser({ email: values.email, password: tempPassword, emailVerified: false });
let inserted = false;
try {
  await auth.setCustomUserClaims(user.uid, { roles });
  await db.connect();
  await db.query(
    'INSERT INTO ocr_users (uid, email, roles, must_change_password) VALUES ($1, $2, $3, TRUE)',
    [user.uid, values.email, roles],
  );
  inserted = true;
} catch (err) {
  // Hindari akun yatim: jika database atau claim gagal, hapus user Firebase yang baru dibuat.
  await auth.deleteUser(user.uid).catch(() => {});
  fail(`penulisan gagal, akun dibatalkan: ${err.message}`);
} finally {
  await db.end().catch(() => {});
}

if (inserted) {
  console.log(`Akun dibuat untuk ${values.email}`);
  console.log(`uid   : ${user.uid}`);
  console.log(`roles : ${roles.join(', ')}`);
  console.log(`sandi sementara (tampil sekali, sampaikan ke pengguna): ${tempPassword}`);
}
