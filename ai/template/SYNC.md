# 模板同步清单

> **拿这份模板开新项目时，把 `SYNC.md` 删掉**——它是维护模板用的，不是项目的一部分。
>
> **维护这份模板是维护席的职责**（`ai/roles/maintainer.md`）。
>
> **这份模板是本项目新结构的通用副本。** 新设计里定了更好的约定或改进，**当轮同步到这里**。
> 守门：`ops/verify/check-template-sync.sh`（比**内容指纹**，并把 A 类再分「通用规矩类／项目内容类」两种判法，见文末「同步的判据」）。

## 进模板的原则：**与项目本身无关的、通用共性的东西**

同步时只问一句：**换一个项目，这条还成立吗？**

- **成立 → 进**：做事的方法、角色分工与话语权、目录职责与命名、状态机、收尾判据、通用的坑。
- **不成立 → 不进**：产品是什么、技术栈、机器/IP/路径/端口、AD 编号、任务号、具体文件名、某次事故的细节。

一条规矩常常两种成分都有。**留道理、换例子**——
把项目专属的名字换成占位，把事故细节抽象成一句通用的话，道理原样保留。

> 两个方向都会出事：项目专属的混进模板，新项目一开张就背上不属于它的历史；
> 通用的改进不同步，模板就悄悄过时了。

## 分两类

### A · 结构性文件 —— 改了源文件就要同步（去掉项目专属内容）

| 本项目 | 模板 | 同步时要做什么 |
|---|---|---|
| `FRAME-Development-Model.md` | `ai/template/FRAME-Development-Model.md` | **原样**（本来就是通用的） |
| `README.md` | `ai/template/README.md` | 换成填空版 |
| `CLAUDE.md` | `ai/template/CLAUDE.md` | 换掉产品介绍段；铁律 2/3 的「核心框架」改回占位 |
| `ai/index.md` | `ai/template/ai/index.md` | 项目名换占位；「当前状态」三行换占位 |
| `ai/roles/developer.md` | `ai/template/ai/roles/developer.md` | 自检清单改为指向 `conventions.md` §五；去掉本项目的具体例子 |
| `ai/roles/reviewer.md` | `ai/template/ai/roles/reviewer.md` | 同上 |
| `ai/roles/supervisor.md` | `ai/template/ai/roles/supervisor.md` | 同上 |
| `ai/roles/maintainer.md` | `ai/template/ai/roles/maintainer.md` | **原样**（本来就是通用的） |
| `ai/rules/maintenance-log.md` | `ai/template/ai/rules/maintenance-log.md` | 清空表，只留规矩与状态定义 |
| `ai/rules/laws.md` | `ai/template/ai/rules/laws.md` | 去掉 AD 编号；铁律 2/3 改为占位 + 「没有核心平台就删掉这两条」 |
| `ai/rules/workflow.md` | `ai/template/ai/rules/workflow.md` | **几乎原样**（状态机、任务模板、优先级、收尾四件都是通用的） |
| `ai/rules/layout.md` | `ai/template/ai/rules/layout.md` | **几乎原样**（目录职责、大小预算、命名、禁止项都是通用的） |
| `ai/rules/conventions.md` | `ai/template/ai/rules/conventions.md` | §一 §二 §六 §七 §八 通用照搬；**§三 §四 §五 换成填空表** |
| `ops/verify/check-cachebust.sh` | `ai/template/ops/verify/check-cachebust.sh` | **原样**（没有前端的项目它会自己跳过） |
| `ops/verify/check-randd.sh` | `ai/template/ops/verify/check-randd.sh` | **原样**（没开 R&D 线的项目它会自己跳过；判据按 `00-` `01-` `02-` 前缀认，**不按语言认**） |
| `ai/roles/researcher.md` | `ai/template/ai/roles/researcher.md` | **原样**（研究席的边界与每轮四件是通用的） |
| `ai/RandD/`（整棵） | `ai/template/ai/RandD/` | **空骨架**：`README.md`（规矩＋九条判据）· `index.md` 空表 · `memory.md` 空表 · `NN-topic/` 一份话题骨架（四个归档目录各一份 `INDEX.md`）。🔴 **文件名中性、内容按项目语言**——两份模板路径必须一字不差 |
| `ai/mail/to-researcher/from-supervisor.md` · `ai/mail/to-supervisor/from-researcher.md` | 同路径 | **空信箱**（研究席只和监督席通信，守门会把别的配对报红） |
| `ops/frame/frame-sync.sh` · `ops/frame/classes.txt` | 同路径 | **原样**（口令「同步 FRAME」的工具与分类表；不同仓库靠各自的 `ai/frame-repo.conf` 区分，**脚本里不写死仓库名**） |
| `docs/guide/frame-sync.md` | `ai/template/docs/guide/frame-sync.md` | **原样**（十步走法、五条铁律、开源用户单向拉回那一节都是通用的） |
| `ai/FRAME-VERSION` | `ai/template/ai/FRAME-VERSION` | **版本号跟着 FRAME 走**；`fingerprint` 由脚本自动算，别手填 |
| `ai/frame-repo.conf` | `ai/template/ai/frame-repo.conf` | **空白样板**：`role=consumer` ＋ `home=<绝对路径或 ../源仓库>` 占位 ＋ `push=no`（开源用户单向拉回），初始化时填。🔴 **同步永不覆盖它**（在 skip 名单里） |
| `ai/decisions/index.md` | `ai/template/ai/decisions/index.md` | 编号重置为 AD1；去掉本项目的已知编号问题那一节 |
| `ai/tasks/index.md` | `ai/template/ai/tasks/index.md` | 清空表；任务号重置 T-0001 |
| `ai/specs/index.md` | `ai/template/ai/specs/index.md` | 清空表，只留文件头规矩 |
| `ai/specs/testing.md` | `ai/template/ai/specs/testing.md` | **只留骨架**：八类的四个空（手段/环境/动作/证据）与填法，去掉本项目的机器、引擎、ISO 之类 |
| `ai/state/now.md` | `ai/template/ai/state/now.md` | 全部换成填空 |
| `ai/check-links.sh` | `ai/template/ai/check-links.sh` | **原样** |
| `ops/verify/check-paths.sh` | `ai/template/ops/verify/check-paths.sh` | 旧目录名那一串换成占位 |
| `ops/verify/check-inbox.sh` | `ai/template/ops/verify/check-inbox.sh` | **原样** |
| `ops/paths.ps1` | `ai/template/ops/paths.ps1` | 项目子目录名换占位 |
| `ops/machines.json` | `ai/template/ops/machines.json` | 换成一台示例机 |
| `product/requirements/inbox.md` | `ai/template/product/requirements/inbox.md` | 清空表，只留规矩与状态定义 |
| `claude-outputs/README.md` | `ai/template/claude-outputs/README.md` | 转正表里本项目专属的行换占位 |
| 各目录 `README.md`（`docs/ ops/ product/ src/ dist/ tmp/ archive/`） | 同名 | 去掉本项目例子 |
| `.gitignore` | `ai/template/gitignore.template` | 去掉本项目专属的产物名 |

### B · 模板独有 —— 本项目没有，不用回流

| 文件 | 是什么 |
|---|---|
| `docs/guide/project-init.md` | 新项目十分钟起步指引（填五个空 → 告诉 AI 身份 → 开第一条任务） |
| `SYNC.md` | 本文件 |

### C · 本项目独有 —— 不进模板

一次性的迁移脚本与说明（`MIGRATION*.md`、`ops/verify/migration-map.py` 这类）——用完即弃，不进模板。

## D · 英文版模板 `ai/template-en/`

**同一套东西的英文版。内容语言不同，路径一字不差。**

| | |
|---|---|
| **谁维护** | 维护席。改一条规范＝改三处：本项目 + `ai/template/` + `ai/template-en/`（`ai/roles/maintainer.md` 开头那条 ⛔） |
| **什么时候用** | 需求方用英文或其他非中文开新项目时从它起步；做「初始化项目」时它是**翻译的源文本** |
| **硬约束** | 两份模板的**文件清单必须完全一致**。`diff <(cd ai/template && find . -type f\|sort) <(cd ai/template-en && find . -type f\|sort)` 必须为空 |
| **守门** | `ops/verify/check-template-sync.sh` 同时比「本项目→中文模板」和「中文模板→英文模板」的 mtime，并比两份的文件清单 |

**译的时候注意三件**：

1. **只译内容，不译路径。** 目录名、文件名、占位符里的尖括号名一律英文，两份一致。
2. **机器也在读的词要连脚本一起改**：状态词、收件簿的 `待处理`、bug 状态、
   `- **步骤**:` `- **现象**:` `## 复测` 这些节名——`check-inbox.sh` 和 `check-bugs.sh` 都在 grep 它们。
   清单在 `ai/glossary.md`。**改完两个方向都要验**（造一条坏的看它红，删掉看它绿）。
3. **守门输出标记不许译**：`INBOX-OK` `BUGS-OK` `CHECK-PATHS-OK` `TEMPLATE-SYNC-OK` `FRAME-SCAN-DONE`。
   唯一的例外是中文版打的那句「引用完整性 OK」，英文版打 `LINKS-OK`——
   **引用到它的文档要跟着改**（`docs/guide/project-init.md`）。

## 同步的时机

**改了 A 类里任何一个源文件，当轮同步。** 不要攒——攒到下次就是「模板和实际做法对不上」，
那时候拿它开新项目，开出来的是个过时的方法论。

## 同步的判据

```
bash ops/verify/check-template-sync.sh
```

它比的是**内容指纹**（不是 mtime —— mtime 是文本影子，`git clone` 一次就全变了），
并且**A 类内部再分两种**（监督席 2026-09-15 提的，实测过误报才改）：

| | 哪些 | 怎么判 |
|---|---|---|
| **通用规矩类** | 角色手册 · `ai/rules/` · 守门脚本 · `CLAUDE.md` · `README.md` · `FRAME-Development-Model.md` | **源改了、模板一个字没动 = 没同步**（内容指纹对账） |
| **项目内容类** | `ai/memory.md` · `ai/state/now.md` · `ai/bugs/index.md` · `ai/tasks/index.md` · `ai/decisions/index.md` · `ai/rules/maintenance-log.md` · `product/requirements/inbox.md` · `ops/machines.json` · **`ai/mail/to-<席>/from-<席>.md` 与 `ai/mail/archive/*`** | 模板那份**本来就是空表／填空版，两边永远不该一样**。所以不比指纹，只查三样：**没有内网 IP · 没有填好的台账行 · 还留着占位符或空行**；信箱更严——**模板里一封信都不许有**（那条判数据行，不判正文里的 `<年月>`）|

**为什么要分**：把项目内容类留在指纹对账里，本项目每记一条记忆、每动一次台账都会红，
而唯一的修法是 `--accept`——**高误报 ＋ 一键消音，最后一定退化成条件反射按消音键**。

另外还比：**两份模板的 .md 小节标题数与表格行数**（指纹发现不了「英文漂成另一个样子」）、
**两份模板的文件清单一字不差**、`ai/frame-manifest.txt` 是不是最新。
🔴 **`--accept` 是「三处都改完」之后的最后一个动作，不是让它变绿的按钮。**
