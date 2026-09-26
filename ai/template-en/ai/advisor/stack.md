# Choice cards

> Every card: **situation → recommendation → why → when it does not apply → what can still be reversed**.
> This is the recommendation "absent any other constraint"; where the profile settles it, the profile wins, and choosing otherwise means saying why.
> 🔴 Always check the day's latest stable version, and **read that version's official docs or source before implementing** — the cards carry no version numbers precisely so that nobody copies an old one.

---

### Back-end language
- **Situation**: a device-side service, to be installed on all sorts of machines, cross-compiled, and cleanly removable.
- **Recommendation**: **Go**, standard library only in the core.
- **Why**: a single binary with no runtime to install; cross-compilation is nearly free; the standard library already does HTTP, JSON and SSE; no dependencies means no dependency conflicts, and several modules can live in one repo without fighting; contract types can be imported directly by both device and cloud with no code generation.
- **Does not apply**: web-first and a JS-only team → **Node + TypeScript** (one language front to back, shared types); data analysis / machine learning first → **Python**; extreme performance and memory safety, learning cost accepted → **Rust**; an existing corporate Java estate → **Java / Kotlin**.
- **Reversible**: only HTTP / CLI contracts are exposed, so the language can be changed per module.

### Front-end framework
- **Situation**: development is mostly done by AI, and components are shared with the site and the console.
- **Recommendation**: **React + Vite + TypeScript**.
- **Why**: AI writes React most reliably (the most training material); the largest ecosystem; site, console and client can import the same components.
- **Does not apply**: a team fluent in Vue → Vue; minimum bundle size → Svelte; a component library for other people → consider React / Vue / Svelte in step with a de-frameworked contract.
- **Reversible**: keep the component contract framework-free and a framework can be added.

### The headless component layer (accessibility)
- **Recommendation**: **React Aria** for React; **Zag.js** for Vue / Svelte.
- **Why**: focus management, keyboard behaviour, ARIA and right-to-left are built in, and hand-writing those is hand-writing them wrong.
- **Reversible**: wrapped inside your own components, invisible from outside.

### Styling
- **Recommendation**: **CSS Modules + design tokens** (`var(--*)`), with stylelint enforcing "tokens only"; logical properties in CSS.
- **Why**: themes, style packs and dark mode all ride on tokens, and stylelint can mechanically forbid literal style values inside components.
- **Does not apply**: prototypes and one-off pages → Tailwind is faster; but Tailwind's arbitrary values (`w-[13px]`) are a back door through the token contract, so be careful in a themeable product.
- **Reversible**: the token names are stable, the implementation is not.

### Global state
- **Recommendation**: **zustand** (small).
- **Why**: a tiny API that AI writes reliably, with adapters for the common renderers.
- **Does not apply**: extremely complex state with time-travel debugging → Redux Toolkit.
- **Reversible**: keep state access behind hooks of your own and the store can be swapped.

### Interfaces described as data (JSON UI / AI-generated interfaces)
- **Situation**: the interface has to be describable in JSON by an AI or a plugin, and rendered as it streams.
- **Recommendation**: use a mature JSON rendering engine as the **engine**, and **own the JSON format yourself**.
- **Why**: a component allowlist, buttons that only emit actions, state binding and streaming rendering all come free; owning the format is what makes the engine replaceable.
- **Reversible**: the format is the contract, the engine is the implementation.

### Marketing site
- **Recommendation**: **Next.js** (Nuxt in the Vue world).
- **Why**: SEO, server rendering and localized routing are required.
- **Does not apply**: a few static pages → plain static generation is enough.
- **Reversible**: the content is Markdown, so the generator can be changed.

### Admin console
- **Recommendation**: React plus a mature admin component library (the antd class).
- **Why**: tables, forms and filters come ready-made, and a console does not need a branded look.
- **Does not apply**: the console *is* part of the product's face (a customer-facing control panel) → use your own component library and tokens, not the admin library's default look.
- **Reversible**: console pages are usually the most self-contained, so replacing the library touches only them.

### Multi-platform clients (phone / tablet / desktop)
- **Recommendation**: **Tauri 2**.
- **Why**: one front end on five platforms; a light shell (Rust, the system WebView); far smaller than Electron.
- **Does not apply**: a desktop tool leaning heavily on the Node ecosystem → Electron; a phone app needing a truly native feel → native, Flutter or React Native.
- **Reversible**: the front end is shared, so the shell can be changed.

### Server push
- **Recommendation**: **SSE** (Server-Sent Events).
- **Why**: plain HTTP that the standard library can write; browsers reconnect by themselves and resume with `Last-Event-ID`; one event connection per client.
- **Does not apply**: high-frequency bidirectional traffic (collaborative editing, games) → WebSocket.
- **Reversible**: keep the event shape in the contract and the transport can change.

### State sync
- **Recommendation**: the truth lives on the server; "list first, then watch", with a version number on every record (epoch / rev / modRev and the like).
- **Why**: after a reconnect a client can tell what it missed, and every client sees the same truth.
- **Does not apply**: several clients editing the same data offline → you need CRDTs or an operation log, and this card is not enough.
- **Reversible**: keep the version field and it still anchors the resume point after an algorithm change.

### Device-side storage
- **Recommendation**: small volumes → a **single-writer KV store with a WAL and snapshots** (or an embedded KV library).
- **Why**: SQL is not needed; version numbers come for free; smaller than embedding SQLite, which matters for a light form factor.
- **Does not apply**: complex queries or reporting → SQLite.
- **Reversible**: keep reads and writes behind one storage interface.

### Cloud storage
- **Recommendation**: **PostgreSQL + object storage**.
- **Why**: licensing, orders and ticket state machines need transactions; large files belong in object storage.
- **Does not apply**: only key-value and cache, no transactions → a managed KV service saves an operations burden.
- **Reversible**: keep the schema and queries in one data-access layer so the engine can change without touching business code.

### The base operating system (for system / device products)
- **Recommendation**: full form factor on **Debian stable** with a rollback-capable filesystem (btrfs snapshots); light / router form factor on **OpenWrt stable**; Wayland for the graphics stack.
- **Why**: stable, huge package selection, licence-friendly; an automatic snapshot before an upgrade is one step from being undone.
- **Does not apply**: you have to follow a hardware vendor's BSP → go with the distribution that vendor supports rather than fighting for uniformity.
- **Reversible**: collect platform differences in the Provider layer (`platform.md`) and only that layer changes with the base.

### Local model inference
- **Recommendation**: **llama.cpp** (MIT) as the core, with the models managed by you; Ollama only as an optional adapter.
- **Why**: you can do your own VRAM / RAM budgeting and tiers (low memory / balanced / fast) instead of being bound by another tool's defaults.
- **Does not apply**: just trying models on a dev machine → use Ollama directly.
- **Reversible**: keep inference behind one capability interface.

### Model access
- **Recommendation**: one model gateway: several models routed by capability (image and text / PDF / audio and video / reasoning / search / coding), with a default, switchable off, usage visible.
- **Why**: models keep changing, and a gateway means the layers above never care whose they are.
- **Does not apply**: one model only and no plan to change → the gateway is a spare layer, call it directly (but keep the calls in one module).
- **Reversible**: the gateway's interface is the contract, so adding or changing models touches nothing above it.

### The back-end language for plugins / apps
- **Recommendation**: any language: a separate process over a unix socket (or local HTTP); official SDKs for one or two main languages first.
- **Why**: third parties use what they know, and process isolation *is* the sandbox boundary.
- **Does not apply**: plugins must run inside a browser sandbox → JS/WASM only, and the process-isolation argument does not hold.
- **Reversible**: communication goes through the socket contract, so language and runtime can both change.

## Conventions for the whole product (settle them at the start, nearly free; **this section is not a choice card**)
- One error-code registry only; time in UTC + RFC 3339; long operations always asynchronous, returning a task id; a trace id all the way through; CalVer for the product version, SemVer for contracts and SDKs.
