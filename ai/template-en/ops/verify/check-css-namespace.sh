#!/usr/bin/env bash
# check-css-namespace: within one page, two files may not each define the same "top-level single-class"
# selector in conflicting ways.
# Usage: bash ops/verify/check-css-namespace.sh
# Exit codes: 0 = no collision; 1 = a collision that overrides; 2 = wrong structure.
#
# [Why this exists] A measured bug: one module's runtime-injected CSS contained a **bare class selector
# with no module prefix** (spinning a border on its own button), while another place defined the same
# class to spin an icon. Both have the same specificity, so **document order decides**, and JS-injected
# styles always come after the inline <style> -- so it won, and every icon using that class gained an
# extra border. **The guard for tokens, the guard for whether CSS is injected and the guard for syntax
# all fail to test "can an injected class name override someone else's"**, so that bug stayed green
# until the Requester spotted it with his own eyes.
#
# [What is actually tested] Not "does the text contain that class", but:
#   **within one document, two files each define the same top-level single-class selector, and the
#   later one's declaration block is not a subset of the earlier one's.**
#   . "One document" = that page's inline <style> plus the CSS injected by each module it pulls in via
#     <script src>; other pages are **tested separately** (mixing them produced 8 false reds in practice).
#   . "Top-level single class" = a selector with one class and no descendant/combinator
#     (`.pill.busy` and `.a .b` are deliberate extensions, not reported).
#   . "Subset" = every declaration of the later one exists in the earlier one with the same value
#     (two copies of the same thing should merely be merged, so it is not red).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT" || exit 2
# 🔴 **A project-specific path may never be hard-coded into FRAME** (the Requester's ruling of
# 2026-09-26): the values come from `ops/verify/paths.env` (class seed; the template ships commented
# samples). All three optional front-end guards behave the same way: **unconfigured means SKIP**, not red
# (measured: when only this one went red, every freshly distributed project started with a false red,
# and the only cure for a false red is learning to ignore it).
[ -f ops/verify/paths.env ] && . ops/verify/paths.env
WEB="${CSSNS_WEB:-${CACHEBUST_WEB:-}}"
PAGE="${CSSNS_PAGE:-index.html}"
[ -n "$WEB" ] && [ -d "$WEB" ] || { echo "CSS-NS-SKIP (no front end configured -- set CSSNS_WEB= or CACHEBUST_WEB= in ops/verify/paths.env)"; exit 0; }
[ -f "$WEB/$PAGE" ] || { echo "CSS-NS-SKIP (there is no $PAGE under $WEB)"; exit 0; }
command -v node >/dev/null 2>&1 || { echo "node is not installed, skipping (install it on CI)"; exit 0; }

node - "$WEB" "$PAGE" <<'JS'
const fs = require('fs'), path = require('path');
const [web, page] = process.argv.slice(2);
const html = fs.readFileSync(path.join(web, page), 'utf8');
// The modules this page actually loads: <script src="xxx.js">
// [Trap] Real src attributes carry a cache parameter (`app-files.js?v=d96`). The first version of this
// regex required `.js` right before the quote and matched not one module -- it printed "1 source" and
// still reported green: **an empty scan reporting green is the classic false green**, which is why the
// number of sources is printed as well.
const mods = [...html.matchAll(/<script[^>]*\bsrc\s*=\s*["']([^"'?]+\.js)(?:\?[^"']*)?["']/gi)].map(m => m[1]);
// This page's own inline <style>
const inline = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(m => m[1]).join('\n');
const sources = [{ file: page, css: inline }];
for (const m of mods) {
  const p = path.join(web, m);
  if (!fs.existsSync(p)) continue;
  const js = fs.readFileSync(p, 'utf8');
  // CSS injected by a module: template literals containing { } (ensureCSS / textContent = CSS and friends)
  for (const lit of js.match(/`[^`]*`/g) || []) {
    const body = lit.slice(1, -1);
    if (/\{[^}]*:[^}]*\}/.test(body) && /(^|\n)\s*\.[A-Za-z_-]/.test(body)) sources.push({ file: m, css: body });
  }
}
// Only "top-level single class" rules: ^.cls { ... }
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
  if (files.length < 2) continue;                      // twice in one file is not a collision
  // Is the later one's declaration set a subset of the earlier one's?
  const first = list[0], last = list[list.length - 1];
  let subset = true;
  for (const [k, v] of last.decls) if (first.decls.get(k) !== v) { subset = false; break; }
  if (subset) continue;                                // merely duplicated, rendering unchanged
  const extra = [...last.decls].filter(([k, v]) => first.decls.get(k) !== v).map(([k, v]) => `${k}:${v}`);
  console.log(`  x  .${cls} is defined by two files and the later one overrides the earlier: ${files.join(' vs ')}`);
  console.log(`     what the later one adds or changes: ${extra.slice(0, 4).join('; ')}`);
  console.log(`     the fix: give the module's own rule a module prefix (.${cls} -> .mod-${cls}); do not occupy a shared class name`);
  bad++;
}
if (bad) {
  console.log(`CSS-NS-FAIL (${bad} collisions)`);
  console.log('  The test is "within one document two files define the same top-level single class, and the later is not a subset of the earlier" --');
  console.log('  deliberate extensions (.pill.busy / .a .b) and exact duplicates are not reported.');
  process.exit(1);
}
if (sources.length < 2) {
  console.log(`  x  only ${sources.length} source(s) found (inline <style> included) -- not one module's CSS was picked up; that is an empty scan, not a green`);
  console.log(`     check the <script src> match (real src attributes carry a ?v= cache parameter) or how the module injects its CSS`);
  process.exit(1);
}
console.log(`CSS-NS-OK (page ${page}: ${sources.length} sources, ${byCls.size} top-level single classes, none overriding another)`);
JS
