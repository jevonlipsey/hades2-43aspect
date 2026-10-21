/* Hades II 4:3 patcher - core logic. UMD: defines globalThis.Nova43Core in a browser (classic script)
 * and module.exports under Node. Pure functions over Uint8Array; the SHA-256 function is injected:
 *   sha256fn(Uint8Array) -> hex string | Promise<hex string>
 * Mirrors patch.py (begin marker once, end marker at EOF, strip gives a known vanilla file,
 * appended block equals the shipped block).
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Nova43Core = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  function b64(s) {
    if (typeof Buffer !== 'undefined') return new Uint8Array(Buffer.from(s, 'base64'));
    var bin = atob(s), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function indexOf(hay, needle, from) {
    var n = needle.length, last = hay.length - n;
    outer: for (var i = from || 0; i <= last; i++) {
      for (var j = 0; j < n; j++) if (hay[i + j] !== needle[j]) continue outer;
      return i;
    }
    return -1;
  }

  function count(hay, needle) {
    var c = 0, i = -1;
    while ((i = indexOf(hay, needle, i + 1)) >= 0) c++;
    return c;
  }

  function endsWith(hay, tail) {
    if (hay.length < tail.length) return false;
    for (var i = 0; i < tail.length; i++) if (hay[hay.length - tail.length + i] !== tail[i]) return false;
    return true;
  }

  function equal(a, b) {
    if (a.length !== b.length) return false;
    for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }

  function concat(a, b) {
    var out = new Uint8Array(a.length + b.length);
    out.set(a, 0); out.set(b, a.length);
    return out;
  }

  function ascii(s) {
    var out = new Uint8Array(s.length);
    for (var i = 0; i < s.length; i++) out[i] = s.charCodeAt(i) & 0xff;
    return out;
  }

  var MARKER = ascii('Import "RunData.lua"');

  function prep(data) {
    return { block: b64(data.block), begin: b64(data.begin), end: b64(data.end) };
  }

  function isPatched(bytes, data) { return indexOf(bytes, prep(data).begin) >= 0; }

  // Patched file -> original bytes, or null if the block is malformed.
  function strip(bytes, data) {
    var p = prep(data);
    var i = indexOf(bytes, p.begin);
    if (i < 0 || count(bytes, p.begin) !== 1 || !endsWith(bytes, p.end)) return null;
    return bytes.subarray(0, i);
  }

  function buildOutput(bytes, data) { return concat(bytes, prep(data).block); }

  // Returns the list of failures (empty when the output is good). Same 4 checks as patch.py verify().
  async function verify(out, data, sha256fn) {
    var p = prep(data), failures = [];
    if (count(out, p.begin) !== 1) failures.push('begin marker must appear exactly once');
    if (!endsWith(out, p.end)) failures.push('end marker must close the file');
    var orig = strip(out, data);
    if (orig === null || !Object.prototype.hasOwnProperty.call(data.knownVanilla, await sha256fn(orig))) {
      failures.push('stripping the block does not give a known vanilla RoomLogic.lua');
    } else if (!equal(out, concat(orig, p.block))) {
      failures.push('appended block differs from patch/nova43.lua');
    }
    return failures;
  }

  async function patch(bytes, data, sha256fn) {
    var res = { reason: 'error', output: null, passed: 0, failed: 0, failures: [], inputSha256: '', outputSha256: null };
    var p = prep(data);
    if (indexOf(bytes, p.begin) >= 0) { res.reason = 'already_patched'; res.inputSha256 = await sha256fn(bytes); return res; }
    if (indexOf(bytes, MARKER) < 0) { res.reason = 'not_hades2'; res.inputSha256 = await sha256fn(bytes); return res; }
    res.inputSha256 = await sha256fn(bytes);
    if (!Object.prototype.hasOwnProperty.call(data.knownVanilla, res.inputSha256)) { res.reason = 'unknown_build'; return res; }
    var out = buildOutput(bytes, data);
    var failures = await verify(out, data, sha256fn);
    res.failures = failures;
    res.failed = failures.length;
    res.passed = 4 - failures.length;   // 4 checks in verify(); a failed check can short-circuit the 4th, count it as failed
    if (res.passed < 0) res.passed = 0;
    if (failures.length) { res.reason = 'verify_failed'; return res; }
    res.reason = 'ok';
    res.output = out;
    res.outputSha256 = await sha256fn(out);
    return res;
  }

  return { isPatched: isPatched, strip: strip, buildOutput: buildOutput, verify: verify, patch: patch };
});
