// 图片审计插件
const fs = require('fs');
const path = require('path');

const sourceDir = path.join(process.cwd(), 'source');
const imagesDir = path.join(sourceDir, 'images');
const postsDir = path.join(sourceDir, '_posts');

function fmt(bytes) {
  if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${bytes} B`;
}

function scanDir(dir, results = []) {
  if (!fs.existsSync(dir)) return results;
  fs.readdirSync(dir).forEach(f => {
    const full = path.join(dir, f);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      scanDir(full, results);
    } else if (/\.(png|jpe?g|gif|webp|bmp|svg|tiff?)$/i.test(f)) {
      results.push({
        abs: full,
        rel: path.relative(imagesDir, full).replace(/\\/g, '/'),
        size: stat.size,
        ext: path.extname(f).toLowerCase(),
      });
    }
  });
  return results;
}

function collectRefs() {
  const refs = new Set();
  if (!fs.existsSync(postsDir)) return refs;
  fs.readdirSync(postsDir)
    .filter(f => f.endsWith('.md'))
    .forEach(file => {
      const content = fs.readFileSync(path.join(postsDir, file), 'utf8');
      const mdImgs = content.match(/!\[.*?\]\(([^)]+)\)/g) || [];
      mdImgs.forEach(m => {
        const src = (m.match(/\(([^)]+)\)/) || [])[1];
        if (src) refs.add(src.split('#')[0].split('?')[0]);
      });
      const htmlImgs = content.match(/src=["']([^"']+)["']/g) || [];
      htmlImgs.forEach(m => {
        const src = (m.match(/["']([^"']+)["']/) || [])[1];
        if (src) refs.add(src.split('#')[0].split('?')[0]);
      });
    });
  return refs;
}

const images = scanDir(imagesDir);
const refs = collectRefs();

console.log('图片审计');
console.log('');

if (images.length === 0) {
  console.log('source/images/ 为空或不存在');
  process.exit(0);
}

const total = images.reduce((s, i) => s + i.size, 0);
console.log(`图片总数：${images.length} 个`);
console.log(`占用空间：${fmt(total)}`);
console.log('');

const byExt = {};
images.forEach(i => { byExt[i.ext] = (byExt[i.ext] || 0) + 1; });
console.log('格式分布：');
Object.entries(byExt).sort((a, b) => b[1] - a[1]).forEach(([ext, n]) => {
  console.log(`  ${ext.padEnd(8)} ${n} 个`);
});
console.log('');

const BIG = 500 * 1024;
const big = images.filter(i => i.size >= BIG).sort((a, b) => b.size - a.size);
if (big.length > 0) {
  console.log(`[WARN] 大图（>= 500 KB，建议压缩）：${big.length} 个`);
  big.forEach(i => console.log(`  ${fmt(i.size).padStart(10)}  ${i.rel}`));
  console.log('');
}

const convertible = images.filter(i => !['.webp', '.svg'].includes(i.ext));
if (convertible.length > 0) {
  const potentialSaving = convertible.reduce((s, i) => s + i.size * 0.4, 0);
  console.log(`[INFO] 可转 WebP 的图片：${convertible.length} 个（估计节省 ${fmt(potentialSaving)}）`);
  convertible.slice(0, 5).forEach(i => console.log(`  ${i.rel}`));
  if (convertible.length > 5) console.log(`  ... 及其他 ${convertible.length - 5} 个`);
  console.log('');
}

const unreferenced = images.filter(i => {
  const variants = ['/images/' + i.rel, 'images/' + i.rel, i.rel];
  return !variants.some(v => refs.has(v));
});

if (unreferenced.length > 0) {
  console.log(`[INFO] 未被文章引用的图片：${unreferenced.length} 个`);
  unreferenced.slice(0, 8).forEach(i => console.log(`  ${fmt(i.size).padStart(10)}  ${i.rel}`));
  if (unreferenced.length > 8) console.log(`  ... 及其他 ${unreferenced.length - 8} 个`);
} else {
  console.log('[OK] 所有图片均被文章引用');
}
