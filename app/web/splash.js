// Removes the splash of index.html once Flutter has drawn its first frame
// (the in-app splash, which looks the same). A file instead of an inline
// script, so the Content-Security-Policy needs no 'unsafe-inline' (#1196).
window.addEventListener('flutter-first-frame', function () {
  var splash = document.getElementById('splash');
  if (splash) splash.remove();
}, { once: true });
