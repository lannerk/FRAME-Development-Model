# Hard laws of development (apply to the whole project)

> The Requester made the final call on every one of these. **On conflict, the lower number wins.**
> Once decided, record a number here (take the number from `decisions/index.md`); from then on, cite a hard law by that number.

## 1. Shipping the feature is not the top goal (master rule)
Reliable, verifiable, maintainable > "it's built". Better to ship one feature fewer than to leave one implementation nobody can explain.
Broken into actions: first check whether the requirement is reasonable → for a complex requirement, put up 2~3 options, compare them and recommend one → read the first-hand official docs for any technology you use →
for a designated third-party framework/platform, go down to the source and test on the same version → stability first → cut complexity, don't reinvent wheels.

## 2. Before starting, check whether an existing capability already supports it
Whatever the core framework/platform chosen for this project (`<write down which one here>`) can do, **always use it first**, don't build your own.
How to check: read the source and the official docs of **the version running on the real machine**; don't guess, don't go on impressions, don't treat a search snippet as evidence.

> For a project with no such core platform, replace this with "whatever the language/framework standard library can do, don't pull in a third party", or delete the whole entry.

## 3. The goal is "build the system with it", not wrap it in a layer
For a capability it doesn't have, change the design or drop it; don't smear another layer on top.
**Corollary**: an abstraction layer left behind to accommodate "we might swap it out someday" has exactly one path — delete it.

> Same as above: no core platform, delete this one.

## 4. Review and oversight give opinions, not orders
You may push back, **but you must actually verify and give evidence**. Complying without verifying and refusing without verifying both leave the responsibility on whoever executes.
**Evidence > seniority**: source line numbers / measured numbers / official docs — pick one of the three.

## 5. If you can finish it yourself, don't bother the Requester
Things that need a human at the machine (plugging a cable, pasting a key, a reboot, a second machine): stack them up, write down how many minutes they take and what they unlock, and ask once.
**"Please run this command for me" is not a solution** — if you have the permission, do it yourself; if you don't, ask for the permission once.

## 6. Give the best solution, not compliance
What the Requester states is **the problem to solve**, not necessarily **the best way to solve it**. If you see a better way, say so and spell out the cost; once he makes the final call, do it.

## 7. Every conclusion carries evidence
Any factual conclusion written into any document must be able to point at its source.
**Check the file mtime before citing code line numbers** — reading an old version and drawing the wrong conclusion is the most common way to crash.
**A negative conclusion must state which form you tried** — "not supported" and "not supported the way I tried it" are two different things.
**"I cannot do it / cannot reach it / it has to be the real machine / I need your help" are negative conclusions too**; the criterion is in `ai/rules/investigate.md`, the section "\"I cannot do it\" is a negative conclusion too".
