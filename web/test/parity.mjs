// parity test: the browser core must produce byte-identical output to patch.py.
//   node web/test/parity.mjs [--input original/RoomLogic.lua]
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(import.meta.url);
const Core = require(path.join(root, 'web/app/nova43-core.js'));
const argv = process.argv.slice(2);
const ii = argv.indexOf('--input');
const input = path.resolve(ii >= 0 ? argv[ii + 1] : path.join(root, 'original/RoomLogic.lua'));
if (!fs.existsSync(input)) { console.error('FAIL: input missing ' + input); process.exit(1); }

let failed = 0;
const ok = (c, m) => { console.log((c ? '  ok   ' : '  FAIL ') + m); if (!c) failed++; };
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');

const tmp = fs.mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), 'nova43-parity-'));
try {
  const run = (args) => spawnSync('python3', args, { cwd: root, encoding: 'utf8' });
  const gen = run(['tools/gen_web_data.py', path.join(tmp, 'data.js')]);
  if (gen.status !== 0) throw new Error('gen_web_data.py failed: ' + gen.stderr);
  const ctx = { globalThis: null };
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(path.join(tmp, 'data.js'), 'utf8'), ctx);
  const data = ctx.Nova43Data;
  ok(!!data && !!data.block && Object.keys(data.knownVanilla).length > 0, 'data file defines Nova43Data');

  const pyOut = path.join(tmp, 'py.lua');
  const py = run(['patch.py', 'patch', input, '--out', pyOut]);
  ok(py.status === 0, 'patch.py patch exits 0' + (py.status ? ': ' + py.stdout + py.stderr : ''));
  const pyBytes = fs.readFileSync(pyOut);

  const bytes = new Uint8Array(fs.readFileSync(input));
  const r = await Core.patch(bytes, data, async (b) => sha(b));
  ok(r.reason === 'ok', 'node core reason ok (got ' + r.reason + ')');
  ok(r.output && Buffer.compare(Buffer.from(r.output), pyBytes) === 0, 'node output is byte-identical to patch.py output');
  ok(r.outputSha256 === sha(pyBytes), 'output sha256 ' + r.outputSha256);
  console.log('  note: expected for this patch version 60608a7922268ee145d76743d125f2b00227d4d55e2d7603c9e3b4044e6bd402, ' +
    (r.outputSha256 === '60608a7922268ee145d76743d125f2b00227d4d55e2d7603c9e3b4044e6bd402' ? 'matches' : 'differs'));
  ok(r.passed === 4 && r.failed === 0, 'core reports 4 checks passed');

  const again = await Core.patch(r.output, data, async (b) => sha(b));
  ok(again.reason === 'already_patched', 'patching the output again gives already_patched');

  const junk = await Core.patch(new Uint8Array(crypto.randomBytes(5000)), data, async (b) => sha(b));
  ok(junk.reason === 'not_hades2', 'junk bytes give not_hades2');

  const mod = new Uint8Array(bytes);
  mod[mod.length - 1] ^= 0x01;
  const unk = await Core.patch(mod, data, async (b) => sha(b));
  ok(unk.reason === 'unknown_build', 'modified original gives unknown_build');

  const f = await Core.verify(r.output, data, async (b) => sha(b));
  ok(f.length === 0, 'verify() of the output has 0 failures');
  const bad = await Core.verify(r.output.subarray(0, r.output.length - 3), data, async (b) => sha(b));
  ok(bad.length > 0, 'verify() flags a truncated output (' + bad.length + ' failures)');
} catch (e) { console.log('  FAIL ' + (e.stack || e.message)); failed++; }
finally { fs.rmSync(tmp, { recursive: true, force: true }); }
console.log(failed ? 'PARITY FAILED' : 'PARITY OK');
process.exit(failed ? 1 : 0);
