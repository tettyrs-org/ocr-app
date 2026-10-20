// Undangan pegawai, sisi publik (auth-firebase.md bagian 8, api-spec.md bagian 16).
// Token dibawa di body. Sandi dipasang ke Firebase di sini, lalu tidak disimpan di mana pun.
import { firebaseAuth } from './firebase.js';

const API_PREFIX = '/api/v1';

function json(body, status) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}

function errorResponse(code, message, status, field) {
  return json({ error: { code, message, ...(field ? { field } : {}) } }, status);
}

// Kebijakan sandi: 8 sampai 128 karakter, memuat huruf dan angka. Diperiksa juga di form.
export function passwordProblem(p) {
  if (typeof p !== 'string' || p.length < 8 || p.length > 128) return 'Sandi harus 8 sampai 128 karakter.';
  if (!/[A-Za-z]/.test(p) || !/\d/.test(p)) return 'Sandi harus memuat huruf dan angka.';
  return null;
}

// Panggilan publik ke API (tanpa token pengguna; token undangan ada di body).
export async function publicApi(env, path, body) {
  return fetch(`${env.API_BASE}${API_PREFIX}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

async function passthrough(res) {
  const text = await res.text();
  return new Response(text, { status: res.status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}

async function readBody(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

// POST /bff/undangan/cek: memeriksa token tanpa mengubah apa pun.
export async function handleInvitationCheck(request, env) {
  const body = await readBody(request);
  const token = typeof body?.token === 'string' ? body.token : '';
  if (!token) return errorResponse('INVITATION_INVALID', 'Tautan undangan tidak valid.', 410);
  return passthrough(await publicApi(env, '/invitations/check', { token }));
}

// POST /bff/undangan/selesai: menyimpan profil dan sandi. Urutan: API mengunci undangan dan mengisi profil,
// lalu sandi dipasang di Firebase. Bila pemasangan gagal, API melepas undangan agar bisa dipakai lagi.
export async function handleInvitationRedeem(request, env) {
  const body = await readBody(request);
  const token = typeof body?.token === 'string' ? body.token : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  if (!token) return errorResponse('INVITATION_INVALID', 'Tautan undangan tidak valid.', 410);
  const problem = passwordProblem(password);
  if (problem) return errorResponse('WEAK_PASSWORD', problem, 400, 'password');

  const res = await publicApi(env, '/invitations/redeem', {
    token,
    full_name: body?.full_name ?? '',
    nip: body?.nip ?? '',
  });
  if (!res.ok) return passthrough(res);
  const data = (await res.json())?.data;

  try {
    await firebaseAuth().updateUser(data.uid, { password });
  } catch (err) {
    console.error('pemasangan sandi gagal, kode', err?.code);
    await publicApi(env, '/invitations/release', { token }).catch(() => {});
    return errorResponse('INTERNAL_ERROR', 'Sandi belum tersimpan. Coba lagi.', 500);
  }
  return json({ data: { email: data.email } }, 200);
}
