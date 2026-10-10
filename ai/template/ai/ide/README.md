# `ai/ide/` —— 四档接口的各工具实现

> 规矩本身在 `ai/rules/model-effort.md`（四档、标签、谁标、开关）。这个目录只回答一件事：**在某一种 AI 开发工具里，四档各落成什么。**
> 🔴 **实现文件只写一份英文**，中英项目共用（内容是路径、字段、模型 ID、官方文档链接）。这份 README 分中英两份。

## 一、一种工具一份，文件名＝工具名

文件名就是 `ai/frame-repo.conf` 里 `ide=` 写的那个值（小写、连字符），也是口令 `ide <工具>` 里的那个词。
第一批之外查过、暂时不用的放 `_spare/`，格式一样，谁用到谁挪出来。

## 二、每份长什么样

头部是机器读的字段，正文七节：

```markdown
---
tool: claude-code                 # ＝文件名
name: Claude Code
npm: "@anthropic-ai/claude-code"  # 没有 npm 包写 none，另给 version-url
version: 2.1.296                  # 上次核对时的版本
checked: 2026-10-10               # 上次核对日期
verified: no                      # 在项目里真派过一次「轻」「强」、看过实际跑的模型与等级，才写 yes（并写日期）
agents-dir: .claude/agents        # 四档子代理文件放哪；做不到子代理文件的写 none
docs:                             # 更新时要重读的页，按重要性排
  - https://…
---
## 1 What it is · is it alive
## 2 Models (what can be chosen; alias or full ID)
## 3 Effort / level (name, how many steps, where it is set)
## 4 Subagent files (path, format, field names)
## 5 Tier mapping   ← 各席用的就是这张表
## 6 Files FRAME generates (the four, verbatim)
## 7 Cannot do · unsure · not verified
```

**第 5 节四档对照表的规矩**：一行一档，四列：档、模型（**别名优先**，别名会自动跟到新一代；没有别名才写完整 ID）、等级、备注。写不进子代理文件的等级，备注里写「在哪补一手」；做不到四档的写「顶＝强」这种合并。对照表是**建议值**，需求方改了就改这一份，接口和任务都不动。

**四档子代理文件的统一正文**（各工具只有头部格式不同）：

```
You are a FRAME execution subagent (tier: <key>). The main session gives you the work, the material and the reply format in one go.
Do what you are given and do not widen the scope; write "unsure" rather than guessing; reply in the requested format and list the files you changed.
```

`description` 统一写：`FRAME tier <key>. Use when the main session says "use tier-<key>" or the task part is labelled <key>.`
（有的工具主会话不能当场点名子代理、只能靠 `description` 自动路由，这句话就是路由依据。）

## 三、怎么更新

1. 跑 `bash ops/scripts/ide-refresh.sh <工具>`（或 `--all`）：它读头部，有 npm 包的和 `version:` 比，印「变了 / 没变」；`checked:` 超过 90 天的标「久没核」。**版本没变、没超 90 天 → 不用更新。**
2. 变了 → 派一个 `light` 档的子代理按 `docs:` 的顺序逐页重读，**只核三件**：子代理文件的路径与字段名（第 4 节）、模型别名 / ID 与等级取值（第 2、3 节）、项目级配置文件有没有改名。
3. 对着第 4、5、6 节逐条改；改了的地方前面加 `(changed 2026-xx-xx: was …)`，留一行旧值好回滚。
4. 改头部的 `version:` `checked:`；第 6 节的四份变了，就按 `ide <工具>` 的流程重新生成到项目里。**改了第 5、6 节的，`verified:` 改回 `no`，等再实测。**
5. 跑 `bash ops/verify/check-ide.sh`；维护记录一条；这些文件是 FRAME 本体，回流源仓库、盖版本。

**为什么不自动抓网页**：各家文档站常禁抓、路径常改，脚本能稳定做的只有版本号；文档变了没变，靠第 2 步人读。

## 四、现在有哪几份

| 工具 | 文件 | 实测 |
|---|---|---|
| Claude Code（终端 / IDE / 桌面里的 Claude Code，读项目的 `.claude/agents/`） | `claude-code.md` | 未（`verified: no`） |
| Claude 云端会话（Claude App 里开的会话，工作目录在云端、可连到电脑；**读不到项目的 `.claude/agents/`**，派活时直接指定模型和等级） | `claude-app.md` | 已验（模型 ＋ 等级，2026-10-10 看会话记录核过） |
| OpenCode（开源命令行，任意模型商；文件名就是子代理名） | `opencode.md` | 未（`verified: no`） |
| TRAE（字节，国内版；只能按模型分档，没有等级；子代理只靠 `description` 自动派） | `trae.md` | 未（`verified: no`） |
| Qoder / Qoder CN（阿里，原通义灵码；模型本身就是档位，`ultimate` `performance` `efficient`） | `qoder.md` | 未（`verified: no`） |
| CodeBuddy Code（腾讯；子代理写槽位 `reasoning` / `lite`，具体模型在它自己的 `variantModels` 里定） | `codebuddy.md` | 未（`verified: no`） |

第一批其余七种（Codex、Cursor、Copilot、Kiro、Cline、Gemini CLI、Antigravity）与备用十二种（Qwen Code、Kimi Code、文心快码、ZCode、Devin Desktop、Zed、Junie、Augment、Factory Droid、Warp、Amp、Aider）：**需求方 2026-10-10 定暂不写**，事实已在监督席 2026-10-10 的调查里，要用哪种时说一声再补。在这之前 `ide <工具>` 只认这张表里有的。
