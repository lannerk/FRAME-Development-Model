#!/usr/bin/env bash
# check-css-namespace: 同一个页面里，两个文件不许各自定义同一个「顶层单类」选择器且互相冲突。
# 用法：bash ops/verify/check-css-namespace.sh
# 退出码 0 = 没有撞名；1 = 有撞名且会互相覆盖；2 = 结构不对。
#
# 【为什么要这条】开发席 2026-09-16 报来 B-0003／T-0035 的根因：
# `inos-files.js` 运行时注入的 CSS 里有一条**没带模块前缀的裸 `.spin`**（给它自己的按钮做边框转圈），
# 而聊天侧的 `.spin` 只让 SVG 旋转。两条特指度都是 (0,1,0)，**胜负只看文档顺序**，
# JS 注入的样式永远排在内联 <style> 之后 → 它赢，于是每个 `<svg class="ic spin">` 都被多套一圈 2px 边框。
# **ui-lint 判令牌、css-inject-check 判有没有注入、web-syntax-check 判语法——三条都不判「注入进来的类名会不会撞掉别人的」**，
# 所以这个 bug 从写下那天起一直绿着，是需求方肉眼看出来的。
#
# 【判的是要保的那件事】不判「文本里有没有 .spin」，判：
#   **同一份文档里，两个文件各自定义了同一个顶层单类选择器，且后者的声明块不是前者的子集。**
#   · 「同一份文档」＝ index.html 的内联 <style> ＋ 它 <script src> 进来的每个模块注入的 CSS；
#     installer/setup/login 是**另外的页面**，不一起判（否则 8 条假红）。
#   · 「顶层单类」＝ 选择器只有一个类、没有后代/组合（`.pill.busy`、`.fx-item .fx-badge` 是有意扩写，不报）。
#   · 「子集」＝ 后者的每条声明在前者里都有且值相同（`.iu-spin` 那种两份写重复的，只是该合并，不报红）。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
WEB="${CSSNS_WEB:-src/inos/web}"
PAGE="${CSSNS_PAGE:-index.html}"
[ -d "$WEB" ] || { echo "找不到 $WEB"; exit 2; }
command -v node >/dev/null 2>&1 || { echo "没有 node，跳过（CI 上要装）"; exit 0; }

node - "$WEB" "$PAGE" <<'JS'
const fs = require('fs'), path = require('path');
const [web, page] = process.argv.slice(2);
const html = fs.readFileSync(path.join(web, page), 'utf8');

// 这一页真正会加载的模块：<script src="xxx.js">
// 【坑】真实的 src 带缓存参数（`inos-files.js?v=d96`），第一版正则要求 `.js` 紧跟引号，一个模块都没匹配到
//（跑出来「1 个来源」就是这个原因——**空扫却报绿，典型的假绿**，所以这里顺手多打一行来源数）。
const mods = [...html.matchAll(/<script[^>]*\bsrc\s*=\s*["']([^"'?]+\.js)(?:\?[^"']*)?["']/gi)].map(m => m[1]);
// 这一页自己的内联 <style>
const inline = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(m => m[1]).join('\n');

const sources = [{ file: page, css: inline }];
for (const m of mods) {
  const p = path.join(web, m);
  if (!fs.existsSync(p)) continue;
  const js = fs.readFileSync(p, 'utf8');
  // 模块注入的 CSS：模板字符串里带 { } 的那几段（ensureCSS/textContent = CSS 这类）
  for (const lit of js.match(/`[^`]*`/g) || []) {
    const body = lit.slice(1, -1);
    if (/\{[^}]*:[^}]*\}/.test(body) && /(^|\n)\s*\.[A-Za-z_-]/.test(body)) sources.push({ file: m, css: body });
  }
}

// 只取「顶层单类」规则：^.cls { ... }
const rules = [];   // {cls, file, decls:Map}
for (const s of sources) {
  const css = s.css.replace(/\/\*[\s\S]*?\*\//g, '');
  for (const m of css.matchAll(/(^|[\n;}])\s*\.([A-Za-z_][\w-]*)\s*\{([^}]*)\}/g)) {
    const cls = m[2], body = m[3];
    const decls = new Map();
    for (const d of body.split(';')) {
      const i = d.indexOf(':'); if (i < 0) continue;
      decls.set(d.slice(0, i).trim().toLowerCase(), d.slice(i + 1).trim().replace(/\s+/g, ' '));
    }
    if (decls.size) rules.push({ cls, file: s.file, decls });
  }
}

const byCls = new Map();
for (const r of rules) { if (!byCls.has(r.cls)) byCls.set(r.cls, []); byCls.get(r.cls).push(r); }

let bad = 0;
for (const [cls, list] of byCls) {
  const files = [...new Set(list.map(r => r.file))];
  if (files.length < 2) continue;                      // 同一个文件里写两次不是撞名
  // 后者（文档顺序靠后）的声明是不是前者的子集
  const first = list[0], last = list[list.length - 1];
  let subset = true;
  for (const [k, v] of last.decls) if (first.decls.get(k) !== v) { subset = false; break; }
  if (subset) continue;                                // 内容重复而已，不会改变渲染
  const extra = [...last.decls].filter(([k, v]) => first.decls.get(k) !== v).map(([k, v]) => `${k}:${v}`);
  console.log(`  ✗  .${cls} 被两个文件各自定义，后者会盖掉前者：${files.join(' vs ')}`);
  console.log(`     后者多出来/改掉的声明：${extra.slice(0, 4).join('; ')}`);
  console.log(`     改法：给模块自己的那条加模块前缀（例如 .${cls} → .dk-${cls}），别占用公共类名`);
  bad++;
}

if (bad) {
  console.log('');
  console.log(`CSS-NS-FAIL（${bad} 处撞名）`);
  console.log('  判的是「同一份文档里两个文件定义同一个顶层单类、且后者不是前者的子集」——');
  console.log('  有意扩写（.pill.busy / .a .b）和内容完全重复的不报。');
  process.exit(1);
}
if (sources.length < 2) {
  console.log(`  \u2717  只扫到 ${sources.length} 个来源（内联 <style> 都算上）——模块 CSS 一个都没抓到，这是空扫，不是绿`);
  console.log(`     检查 <script src> 的匹配（真实的 src 带 ?v= 缓存参数）或模块注入 CSS 的写法`);
  process.exit(1);
}
console.log(`CSS-NS-OK（${page} 这一页：${sources.length} 个来源、${byCls.size} 个顶层单类，没有互相覆盖的）`);
JS
