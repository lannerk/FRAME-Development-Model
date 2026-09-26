# Chains: say A, and you should be thinking B

> Requesters tend to add one thing at a time. **He says one thing, you should be able to derive three** — but raise two or three at most, each with its upside and cost, ordered by your recommendation.

| Say | Raise at the same time |
|---|---|
| Support several frameworks | de-frameworking the contract; SSR per framework; the scaffold filtering by framework; docs with a tab per framework; one test suite running against all |
| Adapt a third-party library | official builds only? adapt it for every framework you support? a gap table for what cannot be mapped; falling back to your own; keeping the library's languages and themes in sync |
| Build a scaffold | TS / JS; the build-tool matrix; non-interactive flags (for AI); docs and AI entries for the scaffold itself |
| Install only what was chosen | the compatibility table and version ranges; a size budget; isolating optional capabilities |
| Make it usable by AI | no context dumping, layered retrieval; skill / MCP / CLI all present and generated from one source; version numbers; diagnostic codes and self-check commands; AI evaluation in acceptance; entries in English |
| Docs | an overview page, live examples, API tables generated from the contract; multiple languages; majors side by side |
| Internationalization | UI copy / human docs / AI entries settled separately; integrating the host's i18n; date and number formatting; RTL; loading the language pack before first paint in SSR |
| Themes / styles | changing a few colours at runtime; changing one component only; overriding on top of a built-in style; a nested region on another style; high contrast and accessibility |
| Build components | a per-item completion checklist; how older components are back-filled when the checklist grows; doing a hard component early to prove the engine |
| Use the latest version | the runtime (Node / Go) too; reading that version's docs while implementing; a compatibility table with the versions actually tested |
| Anything "done gradually" | put it in each task's definition of done; one tidy-up pass at the end of the milestone |
| A new product line / system | what the full and the light form factor share; a client connecting several devices; cloud control plane versus data plane; licence activation; error reports flowing back into the development queue |
| Plugins / apps | core + profile protocol; projections and extension slots; capabilities and mutual exclusion; the absent state; signing and review; a store and paid plans; no-code resource packs |
| An AI assistant | making it a replaceable module; the AI base (models, skills, knowledge, usage) belonging to the system; three permission tiers and "proposals"; remote conversation from a phone; a separate AI identity per user; memory; voice |
| An agent | the evolution boundary (data evolves, permissions and judges do not); an evaluation set and rollback; orchestration and sub-agents whose permissions can only narrow; a small decision model for speed and token cost; browser control |
| Local models | self-hosted, not bound to one tool; VRAM / RAM budgets and tiers; routing several models by capability; visible usage |
| Public services / remote access | data not passing through us; public exposure only after an administrator turns it on; separate tokens; a rate-limited fallback relay |
| Open or closed source | a gate on the public surface; the licence allowlist; secrets never in a public repo |
| Naming / renaming | command collisions, company collisions, trademarks, package names, domains; repo name ≠ brand; a bulk rename must not hit other words containing the same letters |
| Compatibility with what exists | a data migration tool; how long the old interface is promised; how old clients are told to upgrade; import and export formats |
| Outward-facing material | one source, several formats (md / web page / slides / PDF); logos and icons from what already exists; nothing about what is not built, no unsourced numbers |
| A new seat / a new process | every gate that enumerates seats (the ownership table, the mailboxes, the budgets, the READMEs) changes with it — **adding a seat is not just adding a handbook** |
