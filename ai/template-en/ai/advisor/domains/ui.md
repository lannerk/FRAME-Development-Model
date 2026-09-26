# Domain practice: UI frameworks, component libraries and system interfaces

> Think it through this way when building a component library, a design system, or a product with a complex interface. **An ordinary app takes only the lines it needs.**

## The component library

| Dimension | What to do | Why |
|---|---|---|
| Scope | A full set, the way the mainstream admin libraries are: base components + charts + icons + composites; every component with its props / events / methods | Nobody wants to bolt a second library on |
| Process | contract → your own implementation → third-party adapters → a consistency test → the docs page; **one per-item completion checklist plus a ledger**, and older components are back-filled when the checklist grows | Without a checklist, the components built later are of a different quality from the earlier ones |
| Order | One simple component as the template, then **the hardest ones first** (combobox, date picker, table) to prove the engine | Hard components expose architectural problems, and the earlier the cheaper |
| Frameworks | A library for other people should consider React / Vue / Svelte in step; de-framework the contract | You do not get to choose your users' framework |
| Third-party adapters | Official builds only; if a library supports several frameworks, adapt it for all of them | Unofficial wrappers tend to go unmaintained |
| Builds and scaffolding | The mainstream build per framework (Vite / Next / Nuxt / SvelteKit / webpack); your own scaffold filters the optional adapters once a framework is picked; support both TS and JS | The scaffold is the first thing a downstream developer sees |
| SSR | It has to be able to build a front-end website: no flash, no hydration mismatch | Site builders will ask |
| Theming | Several style packs, switchable, installable, generatable by AI; style × appearance (light / dark / high contrast) × density × motion × direction are orthogonal | Orthogonality is what stops the combinations exploding |
| Customization | Match the mainstream libraries' global configuration: changing tokens at runtime, deriving from a seed colour, component-level tokens, nested local configuration, global defaults; overriding on top of a built-in style | The most common request by far is "change just a little" |
| Internationalization | Languages matched to the mainstream libraries, loaded on demand, RTL; **the host's i18n can be merged into one language source** | Two language sources will never stay in sync |
| Docs for people | A global guide + one page per component + **an overview page** + **live examples**; majors side by side; several languages | This is where a user decides whether it is usable |
| Things for AI | Layered retrieval: overview → index → entry; skill / MCP / CLI from one source; versioned (default to the version the project has installed, else the latest); in English | Dumping it into the context once is both expensive and inaccurate |
| Fill in as you go | Frameworks, components, adapters, languages and docs are completed item by item during development, with only a tidy-up at the end | Leaving it to the end means never finishing it |
| Reserved | Animation, effects, a canvas, composites (an AI chat with a plan panel, window controls) get their interfaces registered now | Adding them later then needs no contract change |

## System interfaces (for desktop / platform products)

| Dimension | What to do | Why |
|---|---|---|
| Four orthogonal axes | Style pack × appearance mode × transparency × layout | Each axis changes on its own and the combinations hold automatically |
| Layout | The desktop may have several (classic multi-window plus single-window); app and file interfaces adapt from one definition; the first release ships at least two styles × two layouts | Two of each is the only way to prove the orthogonality is real |
| Style packs | Installable, uploadable (names and descriptions need not be multilingual; the list and detail view carry a preview), generatable from an AI prompt; **they may change appearance only, never position or existence**; no executable code inside | Style packs are the ecosystem's first no-code supply, and also a security boundary |
| The style contract | No literal style values inside a component, only `var(--*)`; CSS uses logical properties only | A machine can check it, which is what makes style packs meaningful |
| One set of components | Every interface is built from the same components (layout components included); if one is missing, add it — the component library ships inside the app SDK | Third-party and built-in look the same |
| Composites | Frequent combinations (a progress bar with an expandable terminal log, say) become components | Otherwise every app writes its own version |
| The widget panel | Apps register widgets (data / toggle / progress / jump), draggable and paged, the same set on a phone | One glance for the whole picture |
| System level | Notification centre, card notifications, screensaver and power, a recovery page, a setup wizard | Without these it does not feel like a system |
| The effects layer (reserved) | Effects for the background, boot, login and AI feedback; **decoration is not a component: turn it off and the interface still works**; with a performance budget and a degradation ladder | Low-end devices have to work too |
