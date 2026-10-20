(function () {
  var channel = new BroadcastChannel('oidc_flutter_web/redirect');
  channel.postMessage(window.location.toString());
  channel.close();
  window.close();
})();
