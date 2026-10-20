// Pengiriman email undangan. Penyedia: Resend (HTTP API). Penyedia bisa diganti di satu tempat ini.
// Alamat email dan isi pesan tidak dicatat di log. Hanya status pengiriman.

export async function sendMail(env, { to, subject, html }) {
  if (!env.RESEND_API_KEY || !env.MAIL_FROM) {
    console.error('email belum dikonfigurasi (RESEND_API_KEY / MAIL_FROM)');
    return false;
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: env.MAIL_FROM, to: [to], subject, html }),
  });
  if (!res.ok) console.error('pengiriman email gagal, status', res.status);
  return res.ok;
}
