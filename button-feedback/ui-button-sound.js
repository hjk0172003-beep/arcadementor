/* BattleZone button confirmation audio (isolated add-on).
 * No game functions, score/audio assets, storage, or drawing code are replaced.
 * This separate audio context is deliberately NOT connected to the replay mix.
 */
(function () {
  'use strict';
  if (window.BZButtonFeedbackInstalled) return;
  Object.defineProperty(window, 'BZButtonFeedbackInstalled', { value: true });

  var context = null;
  var clickBuffer = null;
  var generation = 0;
  var playing = new Set();
  var duration = 0.055;

  function makeClick(ctx) {
    var count = Math.ceil(ctx.sampleRate * duration);
    var result = ctx.createBuffer(1, count, ctx.sampleRate);
    var samples = result.getChannelData(0);
    var seed = 137;
    for (var i = 0; i < count; i++) {
      var t = i / ctx.sampleRate;
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      var noise = (seed / 4294967296) * 2 - 1;
      var attack = Math.min(1, t / 0.0015);
      var release = Math.min(1, (duration - t) / 0.007);
      var wave = 0.53 * Math.sin(2 * Math.PI * 780 * t)
        + 0.23 * Math.sin(2 * Math.PI * 1560 * t)
        + 0.18 * noise * Math.exp(-100 * t);
      samples[i] = 0.26 * wave * attack * Math.max(0, release) * Math.exp(-80 * t);
    }
    return result;
  }

  function playClick() {
    if (document.hidden) return;
    var ticket = generation;
    var requestedAt = performance.now();
    try {
      var Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) return;
      if (!context || context.state === 'closed') {
        context = new Audio({ latencyHint: 'interactive' });
        clickBuffer = makeClick(context);
      }
      var ctx = context;
      function start() {
        if (ticket !== generation || document.hidden || ctx.state !== 'running'
            || performance.now() - requestedAt > 300) return;
        while (playing.size >= 4) {
          var first = playing.values().next().value;
          playing.delete(first);
          try { first.stop(); } catch (_) {}
        }
        var source = ctx.createBufferSource();
        source.buffer = clickBuffer;
        source.connect(ctx.destination);
        playing.add(source);
        source.onended = function () {
          playing.delete(source);
          try { source.disconnect(); } catch (_) {}
        };
        source.start();
      }
      if (ctx.state === 'running') start();
      else ctx.resume().then(start).catch(function () {});
    } catch (_) {
      // An unavailable speaker must never stop a button from working.
    }
  }

  function alreadyHasSound(button) {
    // Preserve the existing start beep, lock tones, and selection previews.
    if (button.id === 'startGameButton') return true;
    var voice = button.getAttribute('data-voice') || button.getAttribute('data-livevoice');
    if (voice && voice !== 'off') return true;
    var sfx = button.getAttribute('data-sfx') || button.getAttribute('data-livesfx');
    if (sfx && sfx !== 'off') return true;
    if (button.id === 'lockButton') {
      try {
        var state = window.BZ && typeof window.BZ.get === 'function' ? window.BZ.get() : null;
        var config = state && state.session ? state.session.config : state && state.settings;
        if (config && config.sfx && config.sfx !== 'off') return true;
      } catch (_) {}
    }
    return false;
  }

  document.addEventListener('click', function (event) {
    // Only real activations: not target hits, programmatic clicks, or drags.
    if (!event.isTrusted || event.defaultPrevented || document.hidden) return;
    var node = event.target instanceof Element ? event.target : null;
    var button = node && node.closest('button');
    if (!button || !button.closest('#stage') || button.matches(':disabled')
        || button.closest('[aria-disabled="true"], [hidden], [inert]')
        || !button.getClientRects().length) return;
    // Extra safety for a locked range, even before its DOM finishes updating.
    if (button.closest('#range') && button.id !== 'lockButton' && button.id !== 'startGameButton') {
      try {
        var state = window.BattleZoneInput && window.BattleZoneInput.status();
        if (state && state.locked) return;
      } catch (_) {}
    }
    if (!alreadyHasSound(button)) playClick();
    // Do not preventDefault/stopPropagation: the original button handler runs.
  }, true);

  function silence() {
    generation++;
    playing.forEach(function (source) { try { source.stop(); } catch (_) {} });
    playing.clear();
    if (context && context.state === 'running') context.suspend().catch(function () {});
  }
  document.addEventListener('visibilitychange', function () { if (document.hidden) silence(); });
  window.addEventListener('pagehide', silence);
})();
