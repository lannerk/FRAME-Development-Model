# Domain practice: apps and plugin ecosystems

> Any product that can have apps / plugins / extensions installed is thought through this way.

| Dimension | What to do | Why |
|---|---|---|
| One generic protocol | One app-and-plugin protocol, **core + profile**: the generic part once, and each product only extends fields (`<base>.plugin/1` + `<product>.app/1`) | The next product does not redefine plugins |
| An install engine | One abstraction handling install / uninstall (including a "pretend" install for tests), the kernel interfaces and app permissions | Packages from every source take the same path |
| Classification | By **who wrote the interface**: plugin apps (written with your components, optionally with a container back end) · container apps (the interface comes with the container) · pure resource packs (styles / layouts / languages / screensavers / skills — **no process, no executable code**); a plugin may have no interface at all | The class decides the review depth and the sandbox strength |
| One action definition | An app declares `actions`, and **one definition generates HTTP / CLI / MCP tools / UI buttons / flow steps** | AI and people take the same path, so nothing is possible for one and impossible for the other |
| Projections and slots | An app projects into the system: windows · enhancements (filling a place the host already has, such as a sidebar on a settings page) · menus · file handlers · widgets · overlays; slots have a JSON Schema, and **adding a slot is always fine, removing one is not** | Host and app evolve without interrupting each other |
| Capability and exclusion | Dependencies name **capabilities**, never app ids; several implementations of one capability may all be in the store but only one can be installed — the exclusion falls out of cardinality | Users can swap implementations and the system never installs two that conflict |
| SDK capabilities | Tasks (progress / pause), notifications, network events, device plug-in events, logging, AI capabilities (including chat cards), voice, personal data and backup, cache clearing, camera and microphone permission, tray menus, app updates | This is what third parties ask for most |
| Public services | An app may expose HTTP / MCP / SSE, with the system doing encryption, authentication, rate limiting and auditing; **opening it to the internet is only possible after an administrator deploys it**, never hard-coded in the package; callers are scoped by credential | An app author should not decide the user's exposure |
| A protocol-enhancing proxy (reserved) | Expose standard protocol ports (database / object store / cache / queue) with a plugin in between doing optimization, caching, auditing and masking | Old clients get the enhancement without changing |
| Ecosystem stages | Built-ins written against the standard protocol → the first installable app → pure resource packs opened to third parties → third parties with back ends (signing, review, tiered compatibility) → paid plans and subscriptions | Risk is opened up one level at a time |
| No-code supply | Style packs and skill packs are things an ordinary user or an AI can produce | The first wave of supply need not wait for professional developers |
| The command line | A thin CLI plus `invoke <app> <action>`; an app may ship its own troubleshooting CLI, but **AI does not run an app's own CLI directly**; the command tree can be aliased by the host, protocol ids are never aliased | AI only travels paths that have permissions and an audit trail |
