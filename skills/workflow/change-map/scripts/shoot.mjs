#!/usr/bin/env node
import { createServer } from 'node:http';
import { access, mkdir, readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { dirname, extname, join, resolve, sep } from 'node:path';

// shortcut: pinned so base and head shots always come from the same browser build; bump together with `playwright install`.
const PLAYWRIGHT = 'playwright@1.62.0';
const CONTENT_TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf',
};
// npx is a .cmd on Windows, which Node only spawns through cmd.exe and its quoting rules; npm's own npx script runs under node directly.
const NPX = process.platform === 'win32'
  ? [process.execPath, join(dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npx-cli.js')]
  : ['npx'];

if (!process.argv[2]) {
  console.error('Usage: node shoot.mjs <map-dir>   (reads <map-dir>/shots.json)');
  process.exit(2);
}
const root = resolve(process.argv[2]);
const shots = JSON.parse(await readFile(join(root, 'shots.json'), 'utf8'));

const insideRoot = path => path === root || path.startsWith(root + sep);
const fileOf = url => resolve(root, '.' + decodeURIComponent(new URL(url, 'http://x/').pathname));

const server = createServer(async (req, res) => {
  try {
    const path = fileOf(req.url);
    if (!insideRoot(path)) return res.writeHead(403).end();
    const body = await readFile(path);
    res.writeHead(200, { 'content-type': CONTENT_TYPES[extname(path)] ?? 'application/octet-stream' }).end(body);
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise(ok => server.listen(0, '127.0.0.1', ok));
const origin = `http://127.0.0.1:${server.address().port}`;

let failed = 0;
for (const shot of shots) {
  const out = resolve(root, shot.out);
  const page = (() => { try { return fileOf(shot.page); } catch { return null; } })();
  if (!insideRoot(out) || !page || !insideRoot(page)) {
    failed++;
    console.error(`OUTSIDE MAP DIR ${shot.page} -> ${shot.out}`);
    continue;
  }
  if (!(await access(page).then(() => true, () => false))) {
    failed++;
    console.error(`MISSING ${shot.page}`);
    continue;
  }
  await mkdir(dirname(out), { recursive: true });
  const args = ['-y', PLAYWRIGHT, 'screenshot', '--viewport-size', shot.viewport ?? '1280,800',
    '--wait-for-timeout', String(shot.waitMs ?? 300), '--full-page', `${origin}/${shot.page}`, out];
  // Async on purpose: a sync spawn would block this process's own server and hang the browser.
  const status = await new Promise(done => spawn(NPX[0], [...NPX.slice(1), ...args], { stdio: 'inherit' })
    .on('close', done)
    .on('error', () => done(1)));
  if (status !== 0) {
    failed++;
    console.error(`FAILED ${shot.page}`);
  }
}
server.close();
console.log(`${shots.length - failed}/${shots.length} shots taken`);
process.exit(failed ? 1 : 0);
