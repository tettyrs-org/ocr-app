// Firebase Hosting hanya meneruskan cookie bernama __session ke Cloud Functions.
// Cookie lain disaring di tepi, jadi nama ini wajib dipakai (lihat auth-firebase.md bagian 9).
export const SESSION_COOKIE = '__session';
export const MAX_COOKIE_BYTES = 3072;

export function readCookie(header, name) {
  if (!header) return null;
  for (const part of header.split(';')) {
    const [k, ...rest] = part.trim().split('=');
    if (k === name) return rest.join('=');
  }
  return null;
}

export function setCookie(name, value, maxAgeSeconds) {
  return `${name}=${value}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAgeSeconds}`;
}

export function clearCookie(name) {
  return `${name}=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0`;
}
