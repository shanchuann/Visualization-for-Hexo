// 死链检查插件
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

const postsDir = path.join(process.cwd(), 'source', '_posts');
const TIMEOUT_MS = 10000;
const CONCURRENCY = 6;

function extractUrls(content) {
  const body = content.replace(/^---[\s\S]*?---\r?\n/, '');
  const matches = body.match(/https?:\/\/[^\s\)\]\>"'`]+/g) || [];
  return [...new Set(matches.map(u => u.replace(/[.,;:!?)]+$/, '')))];
}

function checkUrl(url) {
  return new Promise(resolve => {
    let resolved = false;
    function done(status, ok) {
      if (resolved) return;
      resolved = true;
      resolve({ url, status, ok });
    }
    try {
      const parsed = new URL(url);
      const mod = parsed.protocol === 'https:' ? https : http;
      const req = mod.request({
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: (parsed.pathname || '/') + (parsed.search || ''),
        method: 'HEAD',
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; hexo-link-checker/1.0)', 'Accept': '*/*' },
        timeout: TIMEOUT_MS,
      }, res => done(res.statusCode, res.statusCode < 400));
      req.on('error', () => done(0, false));
      req.on('timeout', () => { req.destroy(); done(0, false); });
      req.end();
    } catch {
      done(0, false);
    }
  });
}

async function main() {
  if (!fs.existsSync(postsDir)) {
    console.log('source/_posts 目录不存在');
    process.exit(1);
  }

  const files = fs.readdirSync(postsDir).filter(f => f.endsWith('.md'));
  const urlMap = new Map();

  files.forEach(file => {
    const content = fs.readFileSync(path.join(postsDir, file), 'utf8');
    extractUrls(content).forEach(url => {
      if (!urlMap.has(url)) urlMap.set(url, []);
      urlMap.get(url).push(file);
    });
  });

  const urls = [...urlMap.keys()];
  console.log('死链检查');
  console.log('');
  console.log(`共扫描 ${files.length} 篇文章，发现 ${urls.length} 个唯一链接`);
  console.log(`并发：${CONCURRENCY}，超时：${TIMEOUT_MS / 1000}s`);
  console.log('');

  const deadLinks = [];

  for (let i = 0; i < urls.length; i += CONCURRENCY) {
    const batch = urls.slice(i, i + CONCURRENCY);
    const results = await Promise.all(batch.map(checkUrl));
    results.forEach(r => { if (!r.ok) deadLinks.push(r); });
    const done = Math.min(i + CONCURRENCY, urls.length);
    process.stdout.write(`\r检测进度：${done} / ${urls.length}  `);
  }
  console.log('');
  console.log('');

  if (deadLinks.length === 0) {
    console.log('所有链接均可访问，没有死链。');
  } else {
    console.log(`发现 ${deadLinks.length} 个死链：`);
    console.log('');
    deadLinks.forEach(({ url, status }) => {
      const label = status === 0 ? '超时/错误' : `HTTP ${status}`;
      console.log(`  [${label}] ${url}`);
      const inFiles = urlMap.get(url) || [];
      inFiles.forEach(f => console.log(`    来源：${f}`));
    });
  }

  console.log('');
  console.log(`有效 ${urls.length - deadLinks.length} / ${urls.length}  |  死链 ${deadLinks.length}`);
}

main().catch(err => {
  console.error('检查失败：', err.message);
  process.exit(1);
});
