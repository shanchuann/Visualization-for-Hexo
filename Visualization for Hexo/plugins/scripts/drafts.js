// 草稿管理插件
const fs = require('fs');
const path = require('path');

const draftsDir = path.join(process.cwd(), 'source', '_drafts');

function parseFrontMatter(content) {
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  return m ? m[1] : '';
}

function getField(fm, ...keys) {
  for (const key of keys) {
    const m = fm.match(new RegExp(`^${key}\\s*:\\s*(.+)`, 'm'));
    if (m) return m[1].trim().replace(/^['"]|['"]$/g, '');
  }
  return '';
}

function countWords(content) {
  const body = content.replace(/^---[\s\S]*?---\r?\n/, '');
  return (body.match(/[一-鿿]/g) || []).length + (body.match(/\b[a-zA-Z]+\b/g) || []).length;
}

function timeAgo(date) {
  const diff = (Date.now() - date.getTime()) / 1000;
  if (diff < 60) return `${Math.round(diff)} 秒前`;
  if (diff < 3600) return `${Math.round(diff / 60)} 分钟前`;
  if (diff < 86400) return `${Math.round(diff / 3600)} 小时前`;
  if (diff < 86400 * 30) return `${Math.round(diff / 86400)} 天前`;
  return date.toLocaleDateString('zh-CN');
}

console.log('草稿管理');
console.log('');

if (!fs.existsSync(draftsDir)) {
  console.log('source/_drafts/ 目录不存在，暂无草稿。');
  console.log('新建草稿：hexo new draft "标题"');
  process.exit(0);
}

const files = fs.readdirSync(draftsDir)
  .filter(f => f.endsWith('.md'))
  .map(f => {
    const filePath = path.join(draftsDir, f);
    const content = fs.readFileSync(filePath, 'utf8');
    const fm = parseFrontMatter(content);
    const stat = fs.statSync(filePath);
    return {
      file: f,
      slug: f.replace('.md', ''),
      title: getField(fm, 'title') || f.replace('.md', ''),
      tags: getField(fm, 'tags', 'tag') || '（无标签）',
      words: countWords(content),
      mtime: stat.mtime,
    };
  })
  .sort((a, b) => b.mtime - a.mtime);

if (files.length === 0) {
  console.log('暂无草稿。');
  console.log('新建草稿：hexo new draft "文章标题"');
} else {
  console.log(`共 ${files.length} 篇草稿（按修改时间排序）`);
  console.log('');
  files.forEach((d, i) => {
    console.log(`${i + 1}. ${d.title}`);
    console.log(`   文件：${d.file}`);
    console.log(`   字数：${d.words}  |  修改：${timeAgo(d.mtime)}`);
    console.log(`   标签：${d.tags}`);
    console.log(`   发布：hexo publish "${d.slug}"`);
    console.log('');
  });
}

console.log('新建草稿：hexo new draft "文章标题"');
console.log('预览草稿：hexo server --draft');
