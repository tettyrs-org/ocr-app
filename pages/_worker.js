// Entry Cloudflare Pages: /bff/* ditangani BFF (kode yang sama dengan Cloud Functions), sisanya aset statis Flutter.
// Satu origin dengan app, jadi cookie sesi tetap berlaku seperti sebelumnya.
import handler from '../functions/src/index.js';
import { configurarFirebase } from '../functions/src/firebase.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/bff/')) {
      configurarFirebase({ projectId: env.OCR_PROJECT_ID, saJson: env.FIREBASE_SA_JSON, apiKey: env.WEB_API_KEY });
      return handler.fetch(request, {
        APP_ORIGIN: env.APP_ORIGIN,
        APP_ORIGIN_ALT: env.APP_ORIGIN_ALT,
        FIREBASE_PROJECT_ID: env.OCR_PROJECT_ID,
        COOKIE_KEY: env.COOKIE_KEY,
        API_BASE: env.API_BASE,
        DEMO_OCR_BASE: env.DEMO_OCR_BASE,
        DEMO_OCR_TOKEN: env.DEMO_OCR_TOKEN,
        MAIL_FROM: env.MAIL_FROM,
        RESEND_API_KEY: env.RESEND_API_KEY,
        WEB_API_KEY: env.WEB_API_KEY,
      });
    }
    return env.ASSETS.fetch(request);
  },
};
