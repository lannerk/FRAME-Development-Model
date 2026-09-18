# dist/ — build output

Executables, installers, upgrade packages, images, packaging intermediates.

**The whole directory stays out of the repo** (`.gitignore`). Want a particular build? Rebuild it, or get it from the real machine or the Requester.
The path comes from `$Dist` in `ops/paths.ps1`; don't stitch it together yourself in a script.
