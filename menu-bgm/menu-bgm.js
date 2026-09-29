/* BattleZone menu-only BGM (isolated add-on, revision 1).
 * Does not replace any game, scoring, timer, input, audio or native bridge function.
 * A separate HTMLAudioElement is never connected to the replay recording mix.
 */
(function () {
  'use strict';
  if (window.BZMenuBgmInstalled) return;
  var setup = document.getElementById('setup');
  var range = document.getElementById('range');
  var modal = document.getElementById('modal');
  var header = setup && setup.querySelector('.setupHeader');
  if (!setup || !range || !modal || !header) return;
  Object.defineProperty(window, 'BZMenuBgmInstalled', { value: true });

  var key = 'battlezone_menu_bgm_enabled_v1';
  var enabled = true;
  try { enabled = localStorage.getItem(key) !== 'off'; } catch (_) {}
  var foreground = !document.hidden;
  var pagePresent = true;
  var leaving = false;
  var pending = null;
  var loadError = false;
  var audio = document.createElement('audio');
  audio.id = 'bzMenuBgmAudio';
  audio.hidden = true;
  audio.preload = 'none';
  audio.loop = true;
  audio.volume = 0.22;
  audio.setAttribute('playsinline', '');
  audio.src = new URL('mode-selection-bgm.wav', document.currentScript.src).href;
  document.body.appendChild(audio);

  var button = document.createElement('button');
  button.id = 'setupBgmToggle';
  button.type = 'button';
  button.style.cssText = 'flex:0 0 auto;white-space:nowrap;font-size:27px;padding:10px 16px;min-width:180px';
  // Place after the brand, leaving the existing buttons and their handlers intact.
  header.insertBefore(button, header.querySelector('button'));

  function visible(el) {
    if (!el || el.hidden || !el.isConnected) return false;
    var style = getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden' && el.getClientRects().length > 0;
  }
  function allowed() {
    return enabled && pagePresent && foreground && !document.hidden && !leaving &&
      visible(setup) && !visible(range) && !visible(modal);
  }
  function paint() {
    button.textContent = '\uBC30\uACBD\uC74C ' + (enabled ? 'ON' : 'OFF');
    button.classList.toggle('selected', enabled);
    button.setAttribute('aria-pressed', String(enabled));
    button.setAttribute('aria-label', enabled ? '\uBC30\uACBD\uC74C \uB044\uAE30' : '\uBC30\uACBD\uC74C \uCF1C\uAE30');
    button.title = loadError ? '\uC74C\uC6D0 \uD30C\uC77C\uC744 \uD655\uC778\uD558\uC138\uC694.' : '';
  }
  function stop() {
    try { audio.pause(); } catch (_) {}
    try { if (audio.currentTime !== 0) audio.currentTime = 0; } catch (_) {}
    pending = null;
  }
  function start() {
    if (!allowed() || loadError || !audio.paused || pending) return;
    try {
      var attempt = audio.play();
      if (attempt && typeof attempt.then === 'function') {
        pending = attempt;
        attempt.then(function () {
          if (pending === attempt) pending = null;
          if (!allowed()) stop();
        }).catch(function () {
          if (pending === attempt) pending = null;
          // Retry a blocked autoplay on the next menu gesture, never block a game button.
        });
      }
    } catch (_) {}
  }
  function refresh() {
    leaving = false;
    if (allowed()) start(); else stop();
  }
  button.addEventListener('click', function () {
    enabled = !enabled;
    loadError = false;
    try { localStorage.setItem(key, enabled ? 'on' : 'off'); } catch (_) {}
    if (audio.error && enabled) { try { audio.load(); } catch (_) {} }
    paint();
    refresh();
  });

  // Stop before the original handler enters the shooting/START screen.
  document.addEventListener('click', function (event) {
    var node = event.target instanceof Element ? event.target : null;
    var target = node && node.closest('button');
    if (target && (target.id === 'enterRange' || target.id === 'startGameButton')) {
      leaving = true;
      stop();
      // A microtask can run between capture and target listeners; use a new task.
      setTimeout(refresh, 0);
      return;
    }
    if (target !== button && allowed()) start();
  }, true);
  document.addEventListener('pointerdown', function (event) {
    var node = event.target instanceof Element ? event.target : null;
    var target = node && node.closest('button');
    if (target === button || (target && (target.id === 'enterRange' || target.id === 'startGameButton'))) return;
    if (allowed()) start();
  }, true);
  document.addEventListener('keydown', function (event) {
    if ((event.key === 'Enter' || event.key === ' ') && event.target !== button && allowed()) start();
  }, true);

  var observer = new MutationObserver(refresh);
  [setup, range, modal].forEach(function (el) {
    observer.observe(el, { attributes: true, attributeFilter: ['hidden', 'style', 'class'] });
  });
  audio.addEventListener('play', function () { if (!allowed()) stop(); });
  audio.addEventListener('playing', function () { if (!allowed()) stop(); });
  audio.addEventListener('error', function () { loadError = true; stop(); paint(); });
  document.addEventListener('visibilitychange', function () {
    foreground = !document.hidden;
    if (foreground) refresh(); else stop();
  });
  window.addEventListener('blur', function () { foreground = false; stop(); });
  window.addEventListener('focus', function () { foreground = true; refresh(); });
  window.addEventListener('pagehide', function () { pagePresent = false; stop(); });
  window.addEventListener('pageshow', function () { pagePresent = true; foreground = !document.hidden; refresh(); });
  paint();
  refresh();
})();
