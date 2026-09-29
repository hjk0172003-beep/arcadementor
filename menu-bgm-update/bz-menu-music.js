/* BATTLEZONE_MENU_MUSIC_V2
 * Independent add-on. No game.js, timer, score, shot sound, replay or drawing changes.
 * A separate HTML audio element is never connected to the recording audio graph.
 */
(function () {
  'use strict';
  if (window.BZMenuMusicInstalled) return;
  var script = document.currentScript;
  var setup = document.getElementById('setup');
  var range = document.getElementById('range');
  var modal = document.getElementById('modal');
  var splash = document.getElementById('splash');
  var header = setup && setup.querySelector('.setupHeader');
  if (!script || !setup || !range || !header) return;
  window.BZMenuMusicInstalled = true;

  var key = 'battlezone_menu_bgm_enabled';
  var enabled = true;
  var nativeActive = true;
  var pageActive = true;
  var pending = null;
  try { enabled = localStorage.getItem(key) !== 'off'; } catch (_) {}

  var audio = document.createElement('audio');
  audio.id = 'bzMenuMusicAudio';
  audio.src = new URL('bz-menu-music.wav', script.src).href;
  audio.loop = true;
  audio.preload = 'none';
  audio.volume = 0.25;
  audio.hidden = true;
  audio.muted = true;
  audio.setAttribute('playsinline', '');
  document.body.appendChild(audio);

  var button = document.createElement('button');
  button.id = 'menuBgmToggle';
  button.type = 'button';
  button.style.whiteSpace = 'nowrap';
  button.style.minWidth = '195px';
  var before = document.getElementById('setupRules');
  header.insertBefore(button, before && before.parentNode === header ? before : null);

  function shown(element) {
    return !!element && !element.hidden && element.getClientRects().length > 0 &&
      getComputedStyle(element).display !== 'none';
  }
  function allowed() {
    return enabled && nativeActive && pageActive && !document.hidden &&
      shown(setup) && !shown(range) && !shown(modal) && !shown(splash);
  }
  function paint() {
    button.textContent = enabled ? '\uBC30\uACBD\uC74C ON' : '\uBC30\uACBD\uC74C OFF';
    button.classList.toggle('selected', enabled);
    button.setAttribute('aria-pressed', String(enabled));
    button.setAttribute('aria-label', enabled ? '\uBC30\uACBD\uC74C \uB044\uAE30' : '\uBC30\uACBD\uC74C \uCF1C\uAE30');
  }
  function stop(reset) {
    audio.muted = true;
    audio.pause();
    pending = null;
    if (reset) { try { audio.currentTime = 0; } catch (_) {} }
  }
  function hookLifecycle() {
    var lifecycle = window.BZLifecycle;
    if (!lifecycle || typeof lifecycle.handle !== 'function' || lifecycle.handle.bzMenuMusicHook) return;
    var original = lifecycle.handle;
    var wrapped = function (event) {
      if (event && event.active === false) {
        nativeActive = false;
        stop(false);
      } else if (event && event.active === true) {
        nativeActive = true;
      }
      try { return original.apply(this, arguments); }
      finally { sync(); }
    };
    wrapped.bzMenuMusicHook = true;
    try { lifecycle.handle = wrapped; } catch (_) {}
  }
  function sync() {
    hookLifecycle();
    if (!allowed()) { stop(!shown(setup)); return; }
    audio.muted = false;
    if (!audio.paused || pending) return;
    try {
      var promise = audio.play();
      if (promise && promise.then) {
        pending = promise;
        promise.then(function () {
          if (pending === promise) pending = null;
          if (!allowed()) stop(!shown(setup));
        }, function () {
          if (pending === promise) pending = null;
          // Some browsers require a user gesture. Retry only on that gesture.
        });
      }
    } catch (_) { pending = null; }
  }

  button.addEventListener('click', function () {
    enabled = !enabled;
    try { localStorage.setItem(key, enabled ? 'on' : 'off'); } catch (_) {}
    paint();
    sync();
  });

  var observer = new MutationObserver(sync);
  [setup, range, modal, splash].forEach(function (element) {
    if (element) observer.observe(element, { attributes: true, attributeFilter: ['hidden', 'style', 'class'] });
  });

  // Silence music before the original range-transition handler or START beep.
  document.addEventListener('click', function (event) {
    var target = event.target instanceof Element ? event.target : null;
    var clicked = target && target.closest('button');
    if (clicked && (clicked.id === 'enterRange' || clicked.id === 'startGameButton') && !clicked.disabled) stop(true);
  }, true);

  function retryFromGesture(event) {
    var target = event.target instanceof Element ? event.target : null;
    if (target && target.closest('#enterRange, #startGameButton, #menuBgmToggle')) return;
    if (event.isTrusted && allowed()) sync();
  }
  document.addEventListener('pointerdown', retryFromGesture, true);
  document.addEventListener('keydown', retryFromGesture, true);
  document.addEventListener('touchend', retryFromGesture, { capture: true, passive: true });
  document.addEventListener('click', retryFromGesture, true);
  audio.addEventListener('play', function () { if (!allowed()) stop(!shown(setup)); });
  audio.addEventListener('playing', function () { if (!allowed()) stop(!shown(setup)); });
  document.addEventListener('visibilitychange', sync);
  window.addEventListener('pagehide', function () { pageActive = false; stop(false); });
  window.addEventListener('pageshow', function () { pageActive = true; sync(); });
  paint();
  sync();
})();
