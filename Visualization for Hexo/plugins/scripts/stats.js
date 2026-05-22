// 文章统计插件
const fs = require('fs');
const path = require('path');

const postsDir = path.join(process.cwd(), 'source', '_posts');

function parseFrontMatter(content) {
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  return m ? m[1] : '';
}

function getListField(fm, key) {
  const inlineMatch = fm.match(new RegExp(`^${key}\\s*:\\s*\\[([^\\]]+)\\]`, 'm'));
  if (inlineMatch) {
    return inlineMatch[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
  }
  const blockMatch = fm.match(new RegExp(`^${key}\\s*:[^\\S\\r\\n]*\\r?\\n((?:\\s+-[^\\r\\n]+\\r?\\n?)*)`, 'm'));
  if (blockMatch) {
    return blockMatch[1].split('\n').map(s => s.replace(/^\s*-\s*/, '').trim()).filter(Boolean);
  }
  const singleMatch = fm.match(new RegExp(`^${key}\\s*:\\s*(.+)`, 'm'));
  if (singleMatch) return [singleMatch[1].trim().replace(/^['"]|['"]$/g, '')];
  return [];
}

function countChars(content) {
  const body = content.replace(/^---[\s\S]*?---\r?\n/, '');
  const cjk = (body.match(/[一-鿿]/g) || []).length;
  const eng = (body.match(/\b[a-zA-Z]+\b/g) || []).length;
  return cjk + eng;
}

if (!fs.existsSync(postsDir)) {
  console.log('source/_posts 目录不存在');
  process.exit(1);
}

const files = fs.readdirSync(postsDir).filter(f => f.endsWith('.md'));
let totalChars = 0;
const catCount = {};
const tagCount = {};

files.forEach(file => {
  const content = fs.readFileSync(path.join(postsDir, file), 'utf8');
  const fm = parseFrontMatter(content);
  totalChars += countChars(content);
  const cats = getListField(fm, 'categories');
  (cats.length ? cats : ['未分类']).forEach(c => { catCount[c] = (catCount[c] || 0) + 1; });
  getListField(fm, 'tags').forEach(t => { tagCount[t] = (tagCount[t] || 0) + 1; });
});

console.log('文章统计报告');
console.log('');
console.log(`  文章总数：${files.length} 篇`);
console.log(`  总字数：  ${totalChars.toLocaleString()} 字`);
console.log(`  平均字数：${files.length ? Math.round(totalChars / files.length) : 0} 字/篇`);
console.log('');

const sortedCats = Object.entries(catCount).sort((a, b) => b[1] - a[1]);
console.log(`分类（共 ${sortedCats.length} 个）`);
sortedCats.slice(0, 8).forEach(([c, n]) => {
  console.log(`  ${c.padEnd(14)} ${n} 篇`);
});
if (sortedCats.length > 8) console.log(`  ... 及其他 ${sortedCats.length - 8} 个分类`);

const sortedTags = Object.entries(tagCount).sort((a, b) => b[1] - a[1]);
console.log('');
console.log(`高频标签（共 ${sortedTags.length} 个）`);
const tagLine = sortedTags.slice(0, 15).map(([t, n]) => `#${t}(${n})`).join('  ');
console.log('  ' + tagLine);
