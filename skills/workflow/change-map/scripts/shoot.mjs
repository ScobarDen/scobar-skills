#!/usr/bin/env node
import { createServer } from 'node:http';
import { access, mkdir, readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { dirname, extname, join, resolve, sep } from 'node:path';

// shortcut: pinned so base and head shots always come from the same browser build; bump together with `playwright install`.
const PLAYWRIGHT_VERSION = '1.62.0';
const PLAYWRIGHT_HOME = join(tmpdir(), `change-map-playwright-${PLAYWRIGHT_VERSION}`);
const CONTENT_TYPES = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.webp': 'image/webp', '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf',
};

if (!process.argv[2]) {
  console.error('Usage: node shoot.mjs <map-dir>   (reads <map-dir>/shots.json)');
  process.exit(2);
}
const root = resolve(process.argv[2]);
const shots = JSON.parse(await readFile(join(root, 'shots.json'), 'utf8'));

// npm is a .cmd on Windows, which Node only spawns through cmd.exe and its quoting rules; npm's own script runs under node directly.
function runNpm(args) {
  const [command, ...prefix] = process.platform === 'win32'
    ? [process.execPath, join(dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npm-cli.js')]
    : ['npm'];
  return new Promise(done => spawn(command, [...prefix, ...args], { stdio: 'inherit' })
    .on('close', done)
    .on('error', () => done(1)));
}

async function loadChromium() {
  const require = createRequire(join(PLAYWRIGHT_HOME, 'package.json'));
  try {
    return require('playwright').chromium;
  } catch {
    const status = await runNpm(['install', '--prefix', PLAYWRIGHT_HOME, '--no-save', '--no-audit', '--no-fund', `playwright@${PLAYWRIGHT_VERSION}`]);
    if (status !== 0) throw new Error(`npm could not install playwright@${PLAYWRIGHT_VERSION} into ${PLAYWRIGHT_HOME}`);
    return require('playwright').chromium;
  }
}

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

const chromium = await loadChromium();
let browser;
try {
  browser = await chromium.launch();
} catch (error) {
  console.error(`${error.message}\nFirst run on this machine? npx playwright@${PLAYWRIGHT_VERSION} install chromium`);
  server.close();
  process.exit(1);
}
const page = await browser.newPage();

let failed = 0;
for (const shot of shots) {
  const out = resolve(root, shot.out);
  const target = (() => { try { return fileOf(shot.page); } catch { return null; } })();
  if (!insideRoot(out) || !target || !insideRoot(target)) {
    failed++;
    console.error(`OUTSIDE MAP DIR ${shot.page} -> ${shot.out}`);
    continue;
  }
  if (!(await access(target).then(() => true, () => false))) {
    failed++;
    console.error(`MISSING ${shot.page}`);
    continue;
  }
  try {
    await mkdir(dirname(out), { recursive: true });
    const [width, height] = (shot.viewport ?? '1280,800').split(',').map(Number);
    await page.setViewportSize({ width, height });
    await page.goto(`${origin}/${shot.page}`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(shot.waitMs ?? 300);
    if (shot.selector) await page.locator(shot.selector).first().screenshot({ path: out, timeout: 5000 });
    else await page.screenshot({ path: out, fullPage: true });
    console.log(`shot ${shot.out}`);
  } catch (error) {
    failed++;
    console.error(`FAILED ${shot.page}: ${error.message.split('\n')[0]}`);
  }
}
await browser.close();
server.close();
console.log(`${shots.length - failed}/${shots.length} shots taken`);
process.exit(failed ? 1 : 0);
