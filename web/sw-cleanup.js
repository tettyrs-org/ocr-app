// Membersihkan service worker dan cache lama dari build sebelumnya, supaya pengguna tidak tertahan di bundle lama.
// Hanya berjalan sekali per tab (flag sessionStorage), lalu halaman dimuat ulang bila ada service worker yang
// sebelumnya mengendalikan halaman.
(function () {
  if (!('serviceWorker' in navigator)) return;
  var flag = 'ocrSwCleaned';
  navigator.serviceWorker.getRegistrations().then(function (regs) {
    if (regs.length === 0) return null;
    var controlled = !!navigator.serviceWorker.controller;
    return Promise.all(regs.map(function (r) { return r.unregister(); }))
      .then(function () { return caches.keys(); })
      .then(function (keys) { return Promise.all(keys.map(function (k) { return caches.delete(k); })); })
      .then(function () {
        try {
          if (controlled && !sessionStorage.getItem(flag)) {
            sessionStorage.setItem(flag, '1');
            location.reload();
          }
        } catch (e) {
          // sessionStorage tidak tersedia (mode privat tertentu): tidak reload, halaman tetap berjalan.
        }
      });
  }).catch(function () {});
})();
