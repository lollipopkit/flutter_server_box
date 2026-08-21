import { readdir } from 'node:fs/promises';
import { join } from 'node:path';

const docsRoot = join(process.cwd(), 'src', 'content', 'docs');
const chineseRoot = join(docsRoot, 'zh');
const pageExtensions = new Set(['.md', '.mdx']);
const logicalPath = (path) => path.replaceAll('\\', '/');

async function pagePaths(root, prefix = '', skipDirectories = new Set()) {
  const paths = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      if (!skipDirectories.has(entry.name)) {
        paths.push(
          ...(await pagePaths(path, logicalPath(join(prefix, entry.name)))),
        );
      }
    } else if (pageExtensions.has(entry.name.slice(entry.name.lastIndexOf('.')))) {
      paths.push(logicalPath(join(prefix, entry.name)));
    }
  }
  return paths;
}

const [english, chinese] = await Promise.all([
  pagePaths(docsRoot, '', new Set(['zh'])),
  pagePaths(chineseRoot, 'zh'),
]);

const chinesePaths = new Set(chinese);
const englishPaths = new Set(english);
const missingChinese = english.filter((path) => !chinesePaths.has(`zh/${path}`));
const missingEnglish = chinese
  .filter((path) => !englishPaths.has(path.slice('zh/'.length)))
  .map((path) => path.slice('zh/'.length));

if (missingChinese.length || missingEnglish.length) {
  if (missingChinese.length) {
    console.error('Missing Simplified Chinese pages:');
    for (const path of missingChinese) console.error(`- zh/${path}`);
  }
  if (missingEnglish.length) {
    console.error('Missing English pages:');
    for (const path of missingEnglish) console.error(`- ${path}`);
  }
  process.exitCode = 1;
} else {
  console.log(`Locale parity OK: ${english.length} English and Simplified Chinese pages.`);
}
