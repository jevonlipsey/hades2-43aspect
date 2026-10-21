/* DEV ONLY - fake Hades43 runtime that implements the real contract with delays.
 * Loaded by main.js only when the URL has ?mock. Always overrides any existing Hades43.
 *
 * Choose the outcome with a query param:   ?mock=ok | already_patched | not_hades2 | unknown_build | verify_failed | error | loadfail
 * Otherwise (plain ?mock) it is picked from the chosen file name (case-insensitive):
 *   "patched" -> already_patched, "nothades" -> not_hades2, "unknown" -> unknown_build, "bad" or "fail" -> verify_failed,
 *   "error" -> error, anything else -> ok.
 * Extra knobs:  ?loadms=3000 (runtime load time)  ?patchms=4000 (patch time)  ?version=1-mock
 */
(function () {
  'use strict';
  var q = new URLSearchParams(location.search);
  var forced = q.get('mock');
  var LOAD_MS = +(q.get('loadms') || 2500);
  var PATCH_MS = +(q.get('patchms') || 3000);
  var VERSION = q.get('version') || 'v1-mock';
  var TOTAL = 1048576;
  var loadP = null;

  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  function hex(buf) {
    return Array.prototype.map.call(new Uint8Array(buf), function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
  }
  function sha256(bytes) {
    if (globalThis.crypto && crypto.subtle) return crypto.subtle.digest('SHA-256', bytes).then(hex);
    var s = ''; for (var i = 0; i < 64; i++) s += ((bytes[i % bytes.length] || 0) + i * 7 & 15).toString(16);
    return Promise.resolve(s);
  }

  function pick(bytes, name) {
    if (forced === 'ok') return 'ok';
    if (forced) return forced;
    var n = (name || '').toLowerCase();
    if (n.indexOf('patched') >= 0) return 'already_patched';
    if (n.indexOf('nothades') >= 0) return 'not_hades2';
    if (n.indexOf('unknown') >= 0) return 'unknown_build';
    if (n.indexOf('bad') >= 0 || n.indexOf('fail') >= 0) return 'verify_failed';
    if (n.indexOf('error') >= 0) return 'error';
    return 'ok';
  }

  var Hades43 = {
    version: undefined,   // real runtime may leave this unset; version arrives with patch()

    load: function (onProgress) {
      if (loadP) return loadP;
      loadP = (async function () {
        if (forced === 'loadfail') {
          if (onProgress) onProgress({ loaded: 0, total: TOTAL, label: 'Downloading runtime' });
          await sleep(800);
          throw new Error('mock: runtime load failed (simulated)');
        }
        var steps = 25;
        for (var i = 0; i <= steps; i++) {
          if (onProgress) {
            if (i < 3) onProgress({ label: 'Starting' });                         // label-only call
            else onProgress({ loaded: Math.round(TOTAL * i / steps), total: TOTAL, label: i === steps ? 'Initializing' : 'Downloading' });
          }
          await sleep(LOAD_MS / steps);
        }
      })();
      return loadP;
    },

    patch: async function (bytes) {
      if (!(bytes instanceof Uint8Array)) throw new TypeError('mock: patch() expects a Uint8Array');
      var name = (globalThis.__mockFileName || '');
      // main.js hands us only bytes, so fall back to the picked file name in the <input>.
      try { var inp = document.getElementById('file'); if (inp && inp.files && inp.files[0]) name = inp.files[0].name; } catch (e) { /* ignore */ }
      var reason = pick(bytes, name);
      await sleep(PATCH_MS);
      var inSha = await sha256(bytes);
      var base = { ok: false, reason: reason, output: null, log: '', passed: 0, failed: 0, skipped: 0, failures: [], inputSha256: inSha, outputSha256: null, version: VERSION };
      var log = ['[mock] patcher ' + VERSION, '[mock] input ' + bytes.length + ' bytes', '[mock] sha256 ' + inSha];

      if (reason === 'ok') {
        var out = new Uint8Array(bytes.length + 16);
        out.set(bytes); out.set([0x4e, 0x34, 0x33, 0x2d, 0x6d, 0x6f, 0x63, 0x6b], bytes.length);
        base.ok = true; base.output = out; base.outputSha256 = await sha256(out);
        base.passed = 4;
        for (var i = 0; i < 12; i++) log.push('[mock] patched method #' + i);
        log.push('[mock] verify: 4 passed, 0 failed');
      } else if (reason === 'already_patched') {
        log.push('[mock] nova43 begin marker found: already patched');
      } else if (reason === 'not_hades2') {
        log.push('[mock] Import "RunData.lua" not found: not Hades II');
      } else if (reason === 'unknown_build') {
        log.push('[mock] sha256 is not a known vanilla RoomLogic.lua');
      } else if (reason === 'verify_failed') {
        base.passed = 3; base.failed = 1;
        base.failures = ['appended block differs from patch/nova43.lua'];
        log.push('[mock] verify: 3 passed, 1 failed');
        base.failures.forEach(function (f) { log.push('FAIL ' + f); });
      } else {
        base.reason = 'error';
        log.push('[mock] System.NullReferenceException: Object reference not set to an instance of an object.');
        log.push('   at Hades43.Patcher.Run(Byte[] input)');
      }
      base.log = log.join('\n');
      return base;
    }
  };

  globalThis.Hades43 = Hades43;
})();
