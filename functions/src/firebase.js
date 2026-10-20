// Klien Firebase Admin bersama. Sandi pengguna hanya dipasang lewat sini; tidak pernah dibaca atau dicatat.
import admin from 'firebase-admin';

export function firebaseAuth() {
  if (!admin.apps.length) admin.initializeApp();
  return admin.auth();
}
