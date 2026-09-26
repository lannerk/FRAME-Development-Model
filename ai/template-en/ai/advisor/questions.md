# The kickoff question bank

> **How to use it**: on a new project, first see what the profile already settles — **do not ask those again**; of what is left, pop up only the ones that **genuinely need the Requester's ruling** (≤ 4 per round, 2–4 options each, the recommendation first and marked "(recommended)", every option with its cost, no default).
> Technical questions you can settle yourself: settle them, write down what can be reversed, and say one line about it in the body. **Ask about the dimensions he never mentioned too** — that is exactly why this bank exists.
>
> Four parts per question: **Why ask** · **If you do not** · **Options and their cost** · **Recommend** when he has no preference (in plain-language mode, phrased as "pick this if you are unsure").
> A 🔒 question is **irreversible**: once settled it is very hard to change, so ask it before any code.

---

## A The product and its scope

**A1 Who is this for, and what problem does it solve?** 🔒
- Why ask: every trade-off (surfaces, performance, looks, price) follows from who it is for.
- If you do not: what gets built is "what the developer wanted", and the intended users cannot use it.
- Options: give a one-line user picture plus the single most painful scenario.
- Recommend: write it as one sentence — "**who**, in **what situation**, uses it to **get what done**" — and put it in `product/vision.md`.

**A2 How far does phase one go? What does the endgame look like? Which future capabilities get reserved?** 🔒
- Why ask: the start can be small, but the endgame decides how the interfaces are cut today.
- If you do not: phase two arrives and the data model, permissions and protocol all have to be torn down.
- Options: ① phase one *is* the endgame (cost: large scope, slow) ② a small start plus a written endgame plus reserved interfaces (cost: one more round of thinking) ③ only what is in front of you (cost: rework, near certainly).
- Recommend: ②.

**A3 What are you explicitly not doing?**
- Why ask: a boundary is what stops the scope creeping.
- If you do not: every new idea squeezes in and phase one never ends.
- Recommend: write 3–5 "will not do" lines into the vision.

**A4 What is it called? Should the package name / domain / command name be claimed now?** 🔒
- Why ask: once a name is in the code, the package name, the URLs and the docs, renaming is brutally expensive.
- If you do not: you discover a clash with a system command, a company in the field or a trademark just before launch.
- Options: ① check collisions and settle it now (cost: half a day) ② use a code name and settle before release (cost: a full replacement before release, and replacements hit the wrong things easily).
- Recommend: ①; and keep the **repo / package namespace** separate from the **public brand** — they need not match.

**A5 Open or closed source? If closed, which surfaces are public?** 🔒
- Why ask: it decides the licence, the dependency allowlist, the repo structure and the gate on the public surface.
- If you do not: a closed-source project takes a GPL dependency, or internal information rides out in public docs.
- Options: ① closed source with docs / examples / the AI catalogue public behind an automatic gate (cost: maintaining the gate) ② fully open (cost: competitors can use it directly, so the business model has to come from elsewhere) ③ fully closed, nothing public (cost: poor ecosystem and poor AI discoverability).
- Recommend: it depends on the business model — **this one has to be his ruling**.

**A6 Build a generic base first, or go straight at the product?**
- Why ask: a generic base is slower, but the next product reuses it.
- If you do not: two products each write the same thing, incompatibly.
- Options: ① capabilities unrelated to the product become standalone generic modules first (cost: slower up front, contracts to design) ② build the product and extract later (cost: extraction later usually means a rewrite).
- Recommend: ① if more than one product is planned.

**A7 How does it make money / how is it licensed?**
- Why ask: licensing, activation and subscriptions shape the account system and the data model.
- If you do not: licensing is added after launch and a large surface has to change.
- Options: one-off purchase / subscription / free plus paid tiers / enterprise licence; licence form: a signed licence document (online / offline / remote activation).
- Recommend: **keep licensing (did they buy it) and permissions (are they allowed) as two separate sets of fields**, whichever model you pick.

## B Surfaces and form factors

**B1 Which surfaces are there?** 🔒
- Why ask: site, admin console, device side, phone / desktop client and CLI each have a different best stack.
- If you do not: one stack is forced onto every surface and some of them are painful.
- Recommend: **pick a stack per surface** (see `stack.md`); list each surface and whether phase one includes it.

**B2 Is there a "full" and a "light" form factor?** 🔒
- Why ask: how far up the two share decides how the code is cut.
- If you do not: the light one becomes a second product, with two codebases and two sets of bugs.
- Options: ① one product in two form factors sharing kernel, protocol, interface and permission table, with platform differences in one Provider layer (cost: abstraction up front) ② build them separately (cost: double maintenance forever).
- Recommend: ①; express a missing feature as an "absent state" rather than a platform fork.

**B3 Target hardware, operating systems, CPU architectures, browser floor?**
- Why ask: it decides the build matrix, the test matrix and which APIs are available.
- If you do not: you find out after release that a class of device cannot run it.
- Recommend: support only versions the vendor still maintains; amd64 + arm64 first, no 32-bit unless the user base clearly needs it.

**B4 Will one user connect several devices / need remote access?**
- Why ask: several devices drag in accounts, addressing, sync and relays.
- If you do not: there is no device id in the addressing scheme, and adding devices later changes every URL.
- Recommend: even if phase one has one device, **carry a device id in the addressing from day one**.

## C Choice of stack

> The recommendations and reasoning live in `stack.md`. This section only lists what to ask.

**C1 Front-end framework: one, or several at once?** 🔒
- Why ask: for a component library / SDK used by others, the number of frameworks decides whether the contract must be framework-free.
- Recommend: one for an application (usually React); for a library other people use, consider several in step with a de-frameworked contract.

**C2 Back-end language?** 🔒
- Why ask: it drives the deployment shape, the size, and how fluent the team and the AI are.
- Recommend: device side / single binary / cross-compiled → Go; web-first with one language front to back → Node + TypeScript (details in `stack.md`).

**C3 Where does the data live?** 🔒
- Why ask: the data model and the storage engine are among the hardest things to change.
- Recommend: small volumes on a device → embedded storage; cloud with transactions → PostgreSQL + object storage.

**C4 How do front and back end talk? What is used for live push?**
- Why ask: the transport decides how reconnection and resume work, and those two are the hardest things to add after launch.
- Recommend: plain requests over HTTP + JSON; server push via SSE first (resume comes built in); WebSocket only for genuinely high-frequency two-way traffic.

**C5 Build and scaffolding: use what exists, or build your own? Both TS and JS?**
- Why ask: if there are downstream developers, the scaffold is part of the product.
- Recommend: internal use only → the official scaffold; for other people → your own (with non-interactive flags so AI can drive it), supporting both TS and JS.

**C6 Version policy?**
- Why ask: the policy decides whether the traps you hit are "known ones" or "ones that should have been fixed long ago".
- Recommend: the day's latest stable, always, plus a tested compatibility table per release; read that version's docs before implementing.

## D Compatibility and migration (routinely forgotten)

**D1 Must it be compatible with an existing system / data / interface / accounts?** 🔒
- Why ask: compatibility is the constraint most often ignored and most able to wreck a schedule.
- If you do not: at launch you find the old users' data will not import and the old clients cannot connect.
- Options: ① full compatibility (cost: the new design is bound by old constraints) ② a one-off migration tool, no long-term compatibility (cost: the migration window has to be communicated) ③ no compatibility, start over (cost: losing old users).
- Recommend: ②; and write into the irreversible list how long the public interface is promised from v1.

**D2 Is there an old project to draw on? How should it be treated?**
- Why ask: what is valuable in an old project is the conclusions and the traps; copying whole blocks of code brings the old constraints along.
- Recommend: an old project is an asset, not a starting point — take the conclusions, the designs and the traps (including what was rejected), not whole blocks of code.

**D3 Do public interfaces / protocols / file formats need version numbers?**
- Why ask: once a third party depends on it, it cannot be changed casually.
- Recommend: every public contract carries a version from day one (`name/1`); "adding a field is always fine, removing one is not".

**D4 Should it interoperate with a third-party ecosystem (import/export, standard protocols)?**
- Why ask: with standard formats, third parties and AI can connect; invent your own and you write every adapter yourself.
- Recommend: prefer the industry's standard formats and protocols (S3, MQTT, OpenAPI, MCP, for instance) over inventing one.

## E Internationalization and accessibility (routinely forgotten)

**E1 Multiple languages or not?** 🔒
- Why ask: once UI copy is hard-coded, adding languages later means going through every page.
- If you do not: taking on overseas customers later means changing copy *and* layout (German is long, Arabic is right-to-left) at the same time.
- Options: ① adopt an i18n framework now and ship one language (cost: one key per string, nearly free) ② ship several languages now (cost: translation and review) ③ do not (cost: the largest change surface later).
- Recommend: ①, **even if the first release has one language**.

**E2 Default language, which languages, right-to-left (RTL) or not?**
- Why ask: languages and writing direction affect layout and how the CSS is written; changing it later means going through every page.
- Recommend: the default follows the main audience; languages loaded on demand; logical properties in CSS (`margin-inline-start`, not `margin-left`), which makes RTL nearly free.

**E3 How are dates, times, numbers, currency and time zones handled?**
- Why ask: date and number format bugs are the hardest class to notice — only users in another time zone or region expose them.
- Recommend: store and transmit in UTC + RFC 3339; format for display by the user's locale.

**E4 Three things settled separately: UI copy, human docs, AI entries — how many languages each?**
- Why ask: the three audiences have different needs; settling them together produces "fully translated docs and badly translated AI entries".
- Recommend: the UI follows the market; docs in the source language plus English, the rest machine-translated and labelled; **AI entries in English only** (models retrieve English most reliably).

**E5 What if the host / consumer has its own i18n?** (ask when building a component library or SDK)
- Why ask: when the consumer already has i18n, **two language sources will not stay in sync**.
- Recommend: one language source, bridged to the mainstream i18n libraries, so the consumer never maintains two.

**E6 How far does accessibility go (keyboard, screen reader, high contrast)?**
- Why ask: how far it goes decides whether an extra appearance is needed, and whether government / enterprise procurement passes.
- Options: ① the default appearance itself passes (cost: less design freedom) ② the default holds the design standard and a separate high-contrast appearance carries accessibility (cost: one more appearance to test) ③ not for now (cost: some users, and procurement, are shut out).
- Recommend: at minimum use a mature headless component layer (never hand-write focus, keyboard and ARIA), then rule between ① and ②.

## F Experience and appearance

**F1 Should the appearance be changeable (themes / style packs)?**
- Why ask: if it is changeable, styles must be extracted into design tokens from day one.
- If you do not: colours and sizes end up scattered through hundreds of components and adding a theme means changing all of them.
- Recommend: changeable or not, **components may only use tokens (`var(--*)`), never literal style values** — nearly free now, extremely expensive to regret.

**F2 Light / dark / high contrast / transparency — which are wanted?**
- Why ask: if the appearance axes are not orthogonal the combinations explode, and each new one touches every component.
- Recommend: light plus dark at minimum; keep the axes orthogonal (style × appearance × density × motion × direction).

**F3 How many layouts (desktop / single window / phone)?**
- Why ask: the number of layouts decides whether modules can merely declare semantics; hard-code positions and changing layout later touches every module.
- Recommend: keep layout separate from style — a module declares semantics, the layout decides where it goes.

**F4 Where do icons, the logo and fonts come from?**
- Why ask: the source carries licence and brand-consistency questions; replacing them later means going through every page and package.
- Recommend: use the Requester's existing assets, asking first "which one is in use right now"; check font licences (OFL is fine).

## G Data, security and permissions

**G1 Where does user data live? Does it pass through our servers?** 🔒
- Why ask: whether data passes through you decides privacy commitments, cost and compliance at once, and changing it later is changing the architecture.
- Recommend: we run the control plane (accounts, licensing, addressing) and keep the data plane out of our hands as far as possible; the fallback relay is rate-limited and stated in the UI.

**G2 How are secrets (passwords, tokens, API keys) stored?**
- Why ask: secret leaks almost always escape through logs and diagnostic bundles, and retrofitting means auditing every output path.
- Recommend: encrypted secret keys; never in environment variables, logs, diagnostic bundles or prompts; schema fields marked `secret` are masked automatically.

**G3 The permission model: how many roles? Is an audit trail needed?** 🔒
- Why ask: adding auditing and roles later means threading permission checks into every entry point already written.
- Recommend: have "who did what and when" from day one; more than one user means roles.

**G4 Can upgrades, installs and configuration changes be rolled back?**
- Why ask: whether it can be rolled back decides whether people dare to upgrade; retrofitting means adding a snapshot to every stateful step.
- Recommend: all of them one step from being undone; an automatic snapshot before a stateful upgrade.

**G5 Error collection? On by default, or the user's choice?**
- Why ask: the default is a privacy-versus-maintainability trade-off, and changing it after launch means asking for consent again.
- Options: ① let the user choose whether to report (cost: less data) ② report by default, switchable off (cost: privacy argument) ③ do not collect (cost: production problems are hard to diagnose).
- Recommend: ①, and let the collected defects flow straight into the development queue.

## H AI

**H1 Is AI among this product's users?** 🔒
- Why ask: with AI users you owe it directly callable interfaces, docs retrievable on demand, and diagnostic codes.
- Recommend: design as if the answer is yes — the cost is low and the return keeps growing.

**H2 Which calling surfaces does AI get (JSON / CLI / MCP / skill)?**
- Why ask: a missing surface is a place where the AI becomes "a person can, it cannot".
- Recommend: one action definition generating HTTP / CLI / MCP / UI buttons; docs retrieved in layers (overview → index → entry), versioned, never dumped into the context at once.

**H3 Does the product itself have AI features? Does it still work with AI off?**
- Why ask: this decides whether AI is an enhancement or a dependency, and what is left when the network is gone.
- Recommend: fully usable with AI off; AI features as a replaceable module with a configurable model.

**H4 How much can the AI do?** (ask when there is an AI operator) 🔒
- Why ask: this is the permission boundary, and narrowing it later breaks flows that are already running.
- Recommend: the AI has its own identity and does not inherit a person's permissions by default; three tiers — **reading is given · writing asks · dangerous things can only be proposed** — executed after approval, with the audit trail recording "initiated by AI".

**H5 Models locally or in the cloud?**
- Why ask: local or cloud decides the hardware budget, the privacy commitment, and behaviour with no network.
- Options: ① cloud models (cost: fees, privacy, useless offline) ② local models (cost: hardware requirements) ③ both, routed by capability (cost: one more gateway layer).
- Recommend: ③, with usage visible to the user.

**H6 Should AI evaluation be part of acceptance?**
- Why ask: without an evaluation set, AI changes rest on "it feels better", which can neither be proven nor used to judge a rollback.
- Recommend: yes — accept AI-related features against a fixed evaluation set.

## I Extensibility

**I1 Third-party plugins / apps or not?** 🔒
- Why ask: if yes, the built-in features have to be written against the public protocol too.
- If you do not: when you open up later you find the built-ins are all back-door calls that third parties cannot match.
- Recommend: even if phase one is closed, **write the built-ins against the public protocol**; split the protocol into core + profile so another product only extends fields.

**I2 In how many steps is the ecosystem opened?**
- Why ask: the order of opening is the order of risk; open everything at once and review and compatibility problems arrive together.
- Recommend: built-ins on the protocol → the first installable module → no-code resource packs (themes, languages, skills) opened to third parties → third parties with back ends (signed, reviewed) → paid plans.

## J Docs, testing and delivery

**J1 Who are the docs for? Which kinds?**
- Why ask: docs for people and docs for AI have different requirements; one document for both serves neither.
- Recommend: keep them separate (for people: a guide + one page per component / interface + an overview + live examples); generate both from the contracts; majors side by side.

**J2 How far does testing go, and who accepts?**
- Why ask: who accepts decides who says "it is done"; reviewing your own work is not acceptance.
- Recommend: every rule machine-checkable (with a reverse assertion); acceptance done by a separate seat.

**J3 Release channels and CI?**
- Why ask: channels involve accounts, fees and review periods; settling it just before launch blocks the release.
- Options: public package registry / private registry / app store / mirrors; the CI platform.
- Recommend: **this one usually needs his ruling** (accounts and money are involved).

**J4 Development rhythm: one complete thing at a time, or a skeleton first?**
- Why ask: the rhythm decides when architectural problems surface; doing the easy things first leaves the hard one to explode at the end.
- Recommend: one simple template first, then **the hardest one** to prove the architecture; every task has a completion checklist, and older work is back-filled when the checklist grows.

## K Licences and dependencies

**K1 A dependency licence allowlist?** 🔒
- Why ask: licence problems get more expensive the later they surface, and may mean replacing a dependency wholesale.
- Recommend: MIT / Apache-2.0 / BSD / ISC / OFL are fine; MPL if you do not modify its files; LGPL dynamically linked only; GPL / AGPL never linked into closed source; no licence, no use; no forking, no vendoring.

**K2 Are third parties bundled or peer dependencies?**
- Why ask: bundled or peer decides whose job an upgrade is, and drives both size and version conflicts.
- Recommend: the adapter pattern, with third parties as peer dependencies the user installs and upgrades.

## L Outward-facing material

**L1 Who is it for (investors / customers / developers)? Which formats?**
- Why ask: different audiences want different formats; one master generating all of them keeps three documents from contradicting each other.
- Recommend: one Markdown master generating web page / slides / PDF; the PDF laid out page by page, not printed from the web page.

**L2 What goes in, and what stays out?**
- Why ask: one claim that does not hold up discredits the whole document, so the boundary comes first.
- Recommend: capabilities, ecosystem, the space it opens; **never "what is not built yet" or internal version differences**; no unsourced market numbers (if numbers are wanted, publish them separately with their definitions).

**L3 What about the visuals?**
- Why ask: visual assets carry licence and brand-consistency questions; replacing them later means regenerating every format.
- Recommend: the logo and icons actually in use; a standalone page with its own `<!doctype>` and `<meta charset="utf-8">`; no font services your audience cannot reach.
