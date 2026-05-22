// 中文排版优化插件（pangu-style）
const fs = require('fs');
const path = require('path');

const postsDir = path.join(process.cwd(), 'source', '_posts');

const CJK = '一-鿿㐀-䶿豈-﫿⺀-⻿㇀-㇯　-〿＀-￯぀-ゟ゠-ヿ';
const ANS = 'A-Za-z0-9';

function addSpacing(text) {
  text = text.replace(new RegExp(`([${CJK}])([${ANS}])`, 'g'), '$1 $2');
  text = text.replace(new RegExp(`([${ANS}])([${CJK}])`, 'g'), '$1 $2');
  text = text.replace(/ {2,}/g, ' ');
  return text;
}

function processContent(content) {
  const fmMatch = content.match(/^(---\r?\n[\s\S]*?\r?\n---\r?\n)([\s\S]*)$/);
  const frontMatter = fmMatch ? fmMatch[1] : '';
  const body = fmMatch ? fmMatch[2] : content;

  const preserved = [];
  const placeholder = '\x00PRES\x00';
  let processed = body.replace(/```[\s\S]*?```|`[^`\n]+`|https?:\/\/\S+/g, m => {
    preserved.push(m);
    return placeholder + (preserved.length - 1) + '\x00';
  });

  processed = addSpacing(processed);
  processed = processed.replace(new RegExp(`${placeholder}(\\d+)\x00`, 'g'), (_, i) => preserved[+i]);

  return frontMatter + processed;
}

if (!fs.existsSync(postsDir)) {
  console.log('source/_posts 目录不存在');
  process.exit(1);
}

const files = fs.readdirSync(postsDir).filter(f => f.endsWith('.md'));
let modifiedCount = 0;

console.log('中文排版优化');
console.log('');

files.forEach(file => {
  const filePath = path.join(postsDir, file);
  const original = fs.readFileSync(filePath, 'utf8');
  const processed = processContent(original);
  if (original !== processed) {
    fs.writeFileSync(filePath, processed, 'utf8');
    modifiedCount++;
    console.log(`  [修改] ${file}`);
  }
});

console.log('');
if (modifiedCount === 0) {
  console.log('排版已是最优状态，无需修改。');
} else {
  console.log(`已优化 ${modifiedCount} / ${files.length} 篇文章。`);
}
