// SEO 检查插件
const fs = require('fs');
const path = require('path');

const postsDir = path.join(process.cwd(), 'source', '_posts');

function parseFrontMatter(content) {
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  return m ? m[1] : '';
}

function hasField(fm, ...keys) {
  return keys.some(k => new RegExp(`^${k}\\s*:`, 'm').test(fm));
}

function getField(fm, key) {
  const m = fm.match(new RegExp(`^${key}\\s*:\\s*(.+)`, 'm'));
  return m ? m[1].trim().replace(/^['"]|['"]$/g, '') : '';
}

if (!fs.existsSync(postsDir)) {
  console.log('source/_posts 目录不存在');
  process.exit(1);
}

const files = fs.readdirSync(postsDir).filter(f => f.endsWith('.md'));
const issues = [];

files.forEach(file => {
  const content = fs.readFileSync(path.join(postsDir, file), 'utf8');
  const fm = parseFrontMatter(content);
  const fileIssues = [];

  if (!hasField(fm, 'title')) {
    fileIssues.push('缺少 title');
  }
  if (!hasField(fm, 'description', 'desc', 'excerpt', 'summary')) {
    fileIssues.push('缺少 description');
  } else {
    const desc = getField(fm, 'description') || getField(fm, 'desc');
    if (desc && desc.length < 20) {
      fileIssues.push(`description 太短（${desc.length} 字，建议 50~160）`);
    } else if (desc && desc.length > 200) {
      fileIssues.push(`description 过长（${desc.length} 字）`);
    }
  }
  if (!hasField(fm, 'tags', 'tag')) fileIssues.push('缺少 tags');
  if (!hasField(fm, 'categories', 'category')) fileIssues.push('缺少 categories');

  if (fileIssues.length > 0) {
    const title = getField(fm, 'title') || file;
    issues.push({ title, file, problems: fileIssues });
  }
});

console.log('SEO 检查');
console.log('');
console.log(`共检查 ${files.length} 篇文章，通过 ${files.length - issues.length} 篇，发现问题 ${issues.length} 篇`);
console.log('');

if (issues.length === 0) {
  console.log('全部文章 SEO 字段完整，无问题。');
} else {
  issues.forEach(({ title, problems }) => {
    console.log(`[WARN] ${title}`);
    problems.forEach(p => console.log(`       - ${p}`));
  });
}
