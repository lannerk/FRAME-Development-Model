# Domain practice: outward-facing material (investors / customers / developers)

| Dimension | What to do | Why |
|---|---|---|
| Formats | One Markdown master, from which you generate: a web page (`index.html`, uploadable as is) + slides + PDF (laid out page by page against the web page and the slides, **not** a printed web page) | Change it once, everything follows |
| The opening | A large icon + the product name + one line of positioning | The first screen has to make it memorable |
| Positioning | Write what the product **is**, not the first use case (the first case is a starting point, not a boundary) | Investors are looking at the ceiling |
| What to include | Capabilities, the app ecosystem, and the space it opens up; screenshots taken from the running product | A real screenshot is more credible than a mockup |
| What to leave out | Internal version differences; "what is not built yet"; links to competitors; **market numbers with no source** (if numbers are needed, publish them separately with their definitions and sources) | One number that does not hold up discredits the whole document |
| Visuals | The logo and icons actually in use (ask which version first); a background consistent with the brand | The material and the product have to be the same thing |
| The web page | A standalone HTML with its own `<!doctype html>` and `<meta charset="utf-8">` (otherwise it is mojibake once uploaded); no overseas font services for audiences that cannot reach them; compressed images in the body, click to see the original | Fast to load, and the detail is still there |
| Slides | Validate on generation: connector heights cannot be negative, and images must be baseline JPEG (progressive JPEG renders blank in some versions of PowerPoint) | These two traps make PowerPoint report "there is a problem with the content" |
