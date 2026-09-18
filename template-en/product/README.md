# product/ — product definition

| Path | What goes in | The rule |
|---|---|---|
| `vision.md` | The product vision (the ten-point architecture). **It is the evidence the decision ledger sits under** | Changing it needs the Requester's final call |
| `requirements/verbatim/` | **The Requester's exact words, not a character changed, append only.** File name `<date>-<topic>.md` | Paraphrase loses things — "chunked multi-part upload" got paraphrased into "just upload reliably", losing its real purpose |
| `requirements/specs/` | The **specs that can be accepted** the Reviewer works up (what to build / boundaries / acceptance points / what not to build) | One file per feature |
| `requirements/formal/` | Formal requirement documents R-xx | The single source for numbered requirements |
| `design/prototype/_PROJECT_/suite/` | **A whole prototype suite** (= a mirror of the running state: desktop, installer, mobile…). Changing the frontend means mirroring it over the same round | Run the prototype self-check when you are done |
| `design/prototype/_PROJECT_/feature/<name>/` | **The finalized design of a single feature**: prototype html + icons + notes. **Development takes it from here, not from the scratch area** | One README per directory saying how development is meant to use it |
| `design/ui/` | **Confirmed baseline assets**: icon SVGs, color scheme, annotated images | Confirmed things, **development does not change them on its own** |
| `design/reference/` | Reference designs, competitor screenshots | Treat as leads only |

**Exact words → spec → task**, don't skip a step:
once the exact words come in, **the Reviewer turns them into a spec or a task that same round**; don't leave them lying in `verbatim/` waiting for someone to dig them out.

**Every question put to the Requester is multiple choice**, never open-ended: two or three options + the cost of each + which one you recommend and why.
(Bad: "which protocols does VPN phase one do?" → good: "A: IKEv2+WireGuard (recommended, NM supports it natively, no third party pulled in) /
B: add OpenVPN (one more package, NM doesn't recognize some of its config directives, which has to be flagged in the UI) / C: all of them")
