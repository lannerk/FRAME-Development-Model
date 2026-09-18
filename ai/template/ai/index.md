# <项目名> · 索引（全项目地图）

> 上限 80 行。**开场读 `CLAUDE.md` → 你的角色手册 → 这一份**，然后按路标跳，不通读任何大文件。

## 四个角色，各读各的

| 角色 | 手册 | 一句话职责 | 产出落哪 |
|---|---|---|---|
| 开发者 | `roles/developer.md` | 可靠地把功能实现出来 | `src/` · 任务文件的「开发者回报」 |
| 审查者 | `roles/reviewer.md` | 资深技术专家：审代码/审方案、对需求方、排活 | 任务文件的「审查结论」· `decisions/` · `specs/` |
| 监督者 | `roles/supervisor.md` | 需求方的全能技术顾问，单独沟通 | `claude-outputs/supervisor/`（原样入库） |
| **维护者** | `roles/maintainer.md` | **维护这套开发模式本身**，不参与开发、不碰需求 | `ai/rules/` · `ai/roles/` · `ai/template/` |

四方都要遵守：`rules/laws.md`（铁律）· `rules/conventions.md`（工程约定）· `rules/workflow.md`（怎么配合）· `rules/layout.md`（东西放哪）· **`rules/investigate.md`（怎么查一个「坏了」）**

## 找东西 → 去哪

| 要找 | 去 |
|---|---|
| 正在干什么 / 谁卡着 | `tasks/index.md` |
| 某条决策定了什么（AD 编号） | `decisions/index.md` → 按号段文件跳（每条带主题标签，可 grep） |
| **一个「坏了」怎么查**（开发席与审查席都读） | `rules/investigate.md`（头一小时手册，五步；拿到 bug 那一刻读） |
| 某个功能的技术方案 | `specs/index.md`（带状态：提案 / 已定 / 已作废） |
| 现在系统是什么样、最近的坑 | `state/now.md`（≤200 行） |
| **他交代过、以后都算数的事**（token 在哪拿、机器脾气、他的偏好） | `memory.md`（**项目记忆**，四席都读、四席都能写；**和规范重复的不记**） |
| **别席给我留了什么话** | `mail/to-<我这一席>/`（**席间信箱**，一个发信人一份，只放未读；规矩 `mail/README.md`） |
| **需求方说过的每一句、处置到哪了** | `../product/requirements/inbox.md`（**收件簿**，一轮结束前 `待处理` 清零） |
| 这套模式改过什么、为什么 | `rules/maintenance-log.md`（**维护记录**，维护者专用，和收件簿两条线） |
| 需求方原话全文 | `../product/requirements/verbatim/` |
| 整理后的可验收规格 | `../product/requirements/specs/` |
| 正式需求 | `../product/requirements/formal/` |
| 产品愿景 | `../product/vision.md` |
| 系统怎么搭的 / 目录里什么是什么 / 功能清单 | `../docs/architecture.md` · `../docs/repo-layout.md` · `../docs/features.md` |
| 部署 / 测试 / 排坑 / 真机 | `../docs/ops/` |
| 源码 | `../src/` |
| 机器清单（**唯一能写 IP 的地方**） | `../ops/machines.json` |
| 原型 / UI 基线 | `../product/design/` |
| 截图 / 实测输出 / 一次性报告 | `../claude-outputs/` |
| 历史（默认不读） | 各目录的 `archive/` + 根 `archive/` |

## 取号与登记（只有一个入口，别各写各的）

| 要 | 去 |
|---|---|
| 决策编号 AD | `decisions/index.md` 顶部「下一个可用编号」，**用谁加一** |
| 任务号 T-#### | `tasks/index.md` 顶部「下一个可用任务号」，同样规矩 |

## 当前状态（每段收尾由开发者更新这三行）

- 测试机：见 `../ops/machines.json`
- 最近交付：<第几段>
- 最近审查：<第几轮>

## 五条不许犯

1. **不许开第二本待办**——待办就是 `tasks/index.md`，交接就是 `state/now.md`。
2. **不许把状态只写在对话里**——段与段之间会换会话，对话里的话下一段没人看得到。
3. **不许在 `ai/` 根下放散件**——只有 `index.md` 和 `check-links.sh` 两个。
4. **不许从 `tmp/` 引用任何东西。**
5. **不许在正式文件里写没有依据的结论**（铁律 7）。
