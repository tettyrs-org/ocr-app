// Penanda mode demo saja (bukan data dokumen). Dipakai agar refresh tetap di mode demo.
// Hanya sessionStorage: hilang saat tab ditutup, dan tidak menyimpan isi berkas atau hasil OCR.
window.demoFlag = {
  get: function () {
    try { return sessionStorage.getItem('ocr_demo') === '1'; } catch (e) { return false; }
  },
  set: function (aktif) {
    try {
      if (aktif) sessionStorage.setItem('ocr_demo', '1');
      else sessionStorage.removeItem('ocr_demo');
    } catch (e) { /* sessionStorage tidak tersedia: demo tidak dipulihkan saat refresh */ }
  },
};
