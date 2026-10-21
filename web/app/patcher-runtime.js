/* Hades II 4:3 patcher - browser runtime. Classic script; defines globalThis.Hades43:
 *   Hades43.load(onProgress) -> Promise<void>     idempotent; onProgress({loaded,total,label})
 *   Hades43.patch(Uint8Array) -> Promise<{ok, reason, output, log, passed, failed, skipped,
 *                                         failures, inputSha256, outputSha256, version}>
 * Pure JavaScript: nova43-core.js does the work, nova43-data.js carries the Lua block and the known
 * vanilla hashes, and SHA-256 comes from crypto.subtle. Nothing to download, so load() is instant.
 */
(function () {
  'use strict';

  var loadP = null;

  function hex(buf) {
    return Array.prototype.map.call(new Uint8Array(buf), function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
  }

  function sha256(bytes) {
    return crypto.subtle.digest('SHA-256', bytes).then(hex);
  }

  function ready() {
    if (!globalThis.Nova43Core || !globalThis.Nova43Data) {
      throw new Error('nova43-core.js or nova43-data.js did not load.');
    }
    if (!(globalThis.crypto && crypto.subtle)) throw new Error('crypto.subtle is unavailable (needs a secure https page).');
  }

  var Hades43 = {
    mode: 'js',
    version: undefined,

    load: function (onProgress) {
      if (loadP) return loadP;
      loadP = Promise.resolve().then(function () {
        ready();
        Hades43.version = 'v' + Nova43Data.version;
        if (onProgress) onProgress({ label: 'Ready' });
      });
      return loadP;
    },

    patch: async function (bytes) {
      if (!(bytes instanceof Uint8Array)) throw new TypeError('patch() expects a Uint8Array');
      ready();
      var version = 'v' + Nova43Data.version;
      var r = await Nova43Core.patch(bytes, Nova43Data, sha256);
      var log = ['Hades II 4:3 patcher ' + version, 'input ' + bytes.length + ' bytes', 'sha256 ' + r.inputSha256];
      if (r.reason === 'ok') {
        log.push('appended ' + (r.output.length - bytes.length) + ' bytes (nova43 block)');
        log.push('verify: ' + r.passed + ' passed, 0 failed');
        log.push('output ' + r.output.length + ' bytes, sha256 ' + r.outputSha256);
      } else if (r.reason === 'verify_failed') {
        log.push('verify: ' + r.passed + ' passed, ' + r.failed + ' failed');
        r.failures.forEach(function (f) { log.push('FAIL ' + f); });
      } else {
        log.push('result: ' + r.reason);
      }
      return {
        ok: r.reason === 'ok', reason: r.reason, output: r.output, log: log.join('\n'),
        passed: r.passed, failed: r.failed, skipped: 0, failures: r.failures,
        inputSha256: r.inputSha256, outputSha256: r.outputSha256, version: version
      };
    }
  };

  globalThis.Hades43 = Hades43;
})();
