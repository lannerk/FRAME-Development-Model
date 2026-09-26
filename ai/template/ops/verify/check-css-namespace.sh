#!/usr/bin/env bash
# check-css-namespace: 同一个页面里，两个文件不许各自定义同一个「顶层单类」选择器且互相冲突。
# 用法：bash ops/verify/check-css-namespace.sh
# 退出码 0 = 没有撞名；1 = 有撞名且会互相覆盖；2 = 结构不对。
#
# 【为什么要这条】实测过的一个 bug：某个模块运行时注入的 CSS 里有一条**没带模块前缀的裸类选择器**
# （给它自己的按钮做边框转圈），而另一处同名的类只让图标旋转。两条特指度相同，**胜负只看文档顺序**，
# JS 注入的样式永远排在内联 <style> 之后 → 它赢，于是每个用到那个类的图标都被多套了一圈边框。
# **判令牌的、判有没有注入的、判语法的三条守门，都不判「注入进来的类名会不会撞掉别人的」**，
# 所以那个 bug 一直绿着，最后是需求方肉眼看出来的。
#
# 【判的是要保的那件事】不判「文本里有没有 .spin」，判：
#   **同一份文档里，两个文件各自定义了同一个顶层单类选择器，且后者的声明块不是前者的子集。**
#   · 「同一份文档」＝ 那一页的内联 <style> ＋ 它 <script src> 进来的每个模块注入的 CSS；
#     别的页面**各判各的**，不混在一起（混判实测会出 8 条假红）。
#   · 「顶层单类」＝ 选择器只有一个类、没有后代/组合（`.pill.busy`、`.a .b` 是有意扩写，不报）。
#   · 「子集」＝ 后者的每条声明在前者里都有且值相同（两份写重复的只是该合并，不报红）。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **项目专属的路径不许写死在 FRAME 里**（需求方 2026-09-26 拍板：「frame 也应该和具体项目无关」）：
# 值从 `ops/verify/paths.env` 读（一行一个 `KEY=值`，seed 类：模板里只有注释掉的样例），
# 也可以用环境变量临时盖过。**没配就跳过并说清怎么配**——不许报红：
# 一条不适用的守门报红，等于每个新项目开局就带一处假红，而假红的唯一修法是学会忽略它。
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
WEB="${CSSNS_WEB:-${CACHEBUST_WEB:-}}"
PAGE="${CSSNS_PAGE:-index.html}"
# 三条可选检查要一个样子：**没配就跳过**，不是报错（实测过：只有这一条报红时，
# 新项目一分发过去就带着一处假红，而假红的唯一修法是学会忽略它）。
[ -n "$WEB" ] && [ -d "$WEB" ] || { echo "CSS-NS-SKIP（未配置前端——在 ops/verify/paths.env 里写 CSSNS_WEB= 或 CACHEBUST_WEB=）"; exit 0; }
[ -f "$WEB/$PAGE" ] || { echo "CSS-NS-SKIP（$WEB 下没有 $PAGE）"; exit 0; }
command -v node >/dev/null 2>&1 || { echo "没有 node，跳过（CI 上要装）"; exit 0; }

node - "$WEB" "$PAGE" <<'JS'
const fs = require('fs'), path = require('path');
const [web, page] = process.argv.slice(2);
const html = fs.readFileSync(path.join(web, page), 'utf8');

// 这一页真正会加载的模块：<script src="xxx.js">
// 【坑】真实的 src 带缓存参数（`<前缀>-files.js?v=d96` 这种），第一版正则要求 `.js` 紧跟引号，一个模块都没匹配到
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
