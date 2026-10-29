import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildCatalogue } from './inventory.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const workspace = path.resolve(root, '../..');
const port = Number(process.env.IOS_COURSE_PORT || 4173);
const mime = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.md': 'text/plain; charset=utf-8', '.swift': 'text/plain; charset=utf-8' };
const escape = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
// Expose only repository files deliberately linked by the course, not the entire checkout.
const sourcePaths = new Set();
const manifest = JSON.parse(await fs.readFile(path.join(root, 'content/manifest.json'), 'utf8'));
for (const unit of manifest.units) {
  try {
    const content = JSON.parse(await fs.readFile(path.join(root, 'content', unit.file), 'utf8'));
    for (const lesson of content.lessons) for (const anchor of lesson.repo) sourcePaths.add(anchor.path);
  } catch { /* An unbuilt/incomplete unit exposes no source files. */ }
}
const courseFiles = new Set(['index.html', 'styles.css', 'app.js', 'state.js', 'interview-state.js', 'interview.js', 'data.js', 'README.md']);
for (const source of (await buildCatalogue(workspace)).sources) sourcePaths.add(source.path);
export async function handleRequest(req, res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end('Read-only server'); return; }
  try {
    const url = new URL(req.url, 'http://127.0.0.1');
    if (url.pathname === '/source') {
      const relative = url.searchParams.get('path') || '';
      if (!sourcePaths.has(relative) || !/^(ios-client|android-client)\//.test(relative) || relative.split('/').some(part => part.startsWith('.') && part !== '.github')) throw new Error('Invalid source path');
      const requested = path.resolve(workspace, relative);
      const real = await fs.realpath(requested);
      if (!real.startsWith(path.join(workspace, 'ios-client') + path.sep) && !real.startsWith(path.join(workspace, 'android-client') + path.sep)) throw new Error('Path outside clients');
      const stats = await fs.stat(real); if (!stats.isFile() || stats.size > 2_000_000) throw new Error('Source unavailable');
      const line = Math.floor(Math.max(1, Math.min(100000, Number(url.searchParams.get('line')) || 1)));
      const text = await fs.readFile(real, 'utf8');
      res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'");
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      const body = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(relative)} · Source reference</title><style>body{margin:0;background:#f8f7f3;color:#203d39;font:13px/1.8 ui-monospace,monospace}header{position:sticky;top:0;background:#fffefa;border-bottom:1px solid #ddd;padding:15px 25px;overflow-wrap:anywhere}a{color:#28564b}ol{padding-left:75px;margin:25px 0}li{white-space:pre-wrap;padding-left:15px;scroll-margin-top:80px}li::marker{color:#8a948b}li:target{background:#e5eedf;outline:1px solid #bacaba}.selected{background:#f0eadf}code{font:inherit}</style></head><body><header><a href="/">← Course reader</a><br>${escape(relative)} · verified source anchor ${line}</header><ol>${text.split('\n').map((value, index) => `<li id="L${index + 1}" ${index + 1 === line ? 'class="selected"' : ''}><code>${escape(value) || ' '}</code></li>`).join('')}</ol></body></html>`;
      res.end(req.method === 'HEAD' ? '' : body); return;
    }
    const relative = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
    if (!courseFiles.has(relative.slice(1))) throw new Error('Not a course asset');
    const target = path.resolve(root, '.' + relative);
    const real = await fs.realpath(target);
    if (!real.startsWith(root + path.sep) || relative.split('/').some(part => part.startsWith('.'))) throw new Error('Invalid course path');
    const extension = path.extname(real); if (!mime[extension]) throw new Error('Unsupported file');
    const content = await fs.readFile(real);
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'");
    res.writeHead(200, { 'Content-Type': mime[extension] }); res.end(req.method === 'HEAD' ? '' : content);
  } catch { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('File not available in this local course.'); }
}
// Importing the handler for tests never opens a port.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = http.createServer(handleRequest);
  server.on('error', error => { console.error(`Could not start course: ${error.message}`); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`Across the Stack is ready at http://127.0.0.1:${port}\nLocal only. Press Ctrl+C to stop.`));
}
