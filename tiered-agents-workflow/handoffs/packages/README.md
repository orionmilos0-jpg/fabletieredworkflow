# Handoff Packages

The Architect agent writes one self-contained handoff package per modular unit
of work here (`PKG-<yyyymmdd>-<slug>.md`), following
`docs/workflow/HANDOFF-TEMPLATE.md`. Workers (developer / test-writer) execute
them. See `docs/workflow/TIERED-AGENTS.md`.

This directory is kept in version control so the package files land somewhere
sensible; the packages themselves are generated per task and can be cleaned up
or committed as you prefer.
