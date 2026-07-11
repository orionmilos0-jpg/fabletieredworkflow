# Tiered Model Workflow for Claude Code

A drop-in setup that makes Claude Code **switch models automatically based on the
kind of work** — using native subagents, each pinned to its own model.

- **Architect** (Fable) — plans, decomposes the task, writes handoff packages, does the final eval. Never writes code, so its context stays clean.
- **Developer** (Opus) — the heavy lifting: real implementation + the build/fix/retry loop.
- **Test-writer** (Sonnet) — boilerplate tests, mocks, fixtures, smoke checks.
- **Reviewer** (Fable) — reads the diff, worker reports, and Codex's findings; returns a structured verdict. Read-only.
- **Codex** (OpenAI Codex CLI) — an independent second-opinion reviewer (a different model family, so it catches different bugs) and an on-demand troubleshooter when a worker gets stuck. Optional but recommended.

The point: keep the expensive, context-sensitive reasoning (Fable) at the two
ends, route the high-volume trial-and-error middle to cheaper models, and add a
cross-model reviewer (Codex) so no single model's blind spots slip through. Full
rationale and diagram in [`docs/workflow/TIERED-AGENTS.md`](docs/workflow/TIERED-AGENTS.md).

Three disciplines make or break the savings: **explicit handoffs** (the
architect must pass a Definition of Ready before routing, or a cheaper worker
will confidently wander down the wrong path), a **boring shared run log**
(`handoffs/RUN-STATE.md`, updated by every tier) so the reviewer reads what
happened instead of reconstructing it from chat, and **run-log hygiene** —
RUN-STATE holds exactly ONE run at a time, and finished runs are archived to
`handoffs/runs/` via the archive + drain ritual (below) instead of accreting
into a context tax every tier pays on every run.

---

## What's in this package

```
.claude/
  agents/
    architect.md        # Fable  — plan + evaluate (read-only)
    developer.md        # Opus   — implementation
    test-writer.md      # Sonnet — tests / mocks / fixtures
    reviewer.md         # Fable  — read-only verdict
  commands/
    tier.md             # /tier slash command — one-shot trigger
docs/workflow/
    TIERED-AGENTS.md    # how the workflow works + how to drive it
    HANDOFF-TEMPLATE.md # the spec the architect hands to workers (+ Definition of Ready)
handoffs/
    RUN-STATE.md        # boring shared run log every tier updates (ONE run at a time)
    runs/               # per-run archives (YYYY-MM-DD-<slug>.md) — greppable history
    packages/
      README.md         # where generated handoff packages land
scripts/
    codex-review.sh     # independent Codex second-opinion review (optional)
install.sh              # copies the above into a target repo
README.md               # this file
```

---

## Install

### Option A — project-scoped (recommended)

Puts the workflow in one repo, committed alongside the code so your whole team
gets it.

**With the helper script:**

```bash
# from inside this unzipped folder
./install.sh /path/to/your/repo
```

**Or manually** — copy these into your repo root (merge with any existing
`.claude/` and `docs/`):

```bash
cp -r .claude docs handoffs scripts /path/to/your/repo/
```

Commit them:

```bash
cd /path/to/your/repo
git add .claude docs/workflow handoffs/packages scripts/codex-review.sh
git commit -m "chore: add tiered model workflow"
```

### Option B — global (all your projects)

Agents and commands in `~/.claude/` apply to every project on your machine (they
are NOT shared with your team):

```bash
mkdir -p ~/.claude/agents ~/.claude/commands
cp .claude/agents/*.md   ~/.claude/agents/
cp .claude/commands/*.md ~/.claude/commands/
# keep the docs somewhere you can reference them
```

> Note: `.claude` is a hidden folder. In a file manager, enable "show hidden
> files" (macOS Finder: `Cmd+Shift+.`) to see it after unzipping.

---

## Use

From your Claude Code session, run the slash command with your task:

```
/tier add rate limiting to the public API endpoints
```

That expands into the full delegation instruction: the **architect** plans and
writes handoff packages, the **developer** and **test-writer** execute them, the
**reviewer** gives a verdict, and it pauses for your go-ahead before committing.

Prefer plain English? This works too:

> Use the tiered workflow: have the architect plan this, run the packages on the
> developer and test-writer, then get a reviewer verdict before we commit.

Or drive one tier at a time when you want a checkpoint:

> Use the architect subagent to plan X. *(review the packages yourself)*
> Now use the developer subagent to implement handoffs/packages/PKG-….md.

Verify the subagents are picked up with `/agents` in Claude Code.

---

## Run-log hygiene: the archive + drain ritual

`RUN-STATE.md` is read by the reviewer and the architect **every run**, so stale
history in it is a context tax on every run — and interleaved old runs are a
correctness hazard (a reviewer can mistake a prior run's worker entry for
current). Two rules keep it self-limiting:

1. **Archive, don't delete.** When a run finishes (or at the next plan time),
   the finished run section moves to `handoffs/runs/YYYY-MM-DD-<slug>.md`,
   topped with a short header: final status, blessed commits, and how the
   carry-forward was drained. Git has the history anyway; per-run files keep it
   greppable. Never overwrite an existing archive — suffix `-2` on a collision.
2. **Drain before reset — enforced.** Resetting RUN-STATE is permitted only
   when the previous run carries no undone obligations: deferred issues get
   actually FILED in your real bug tracker, and unfinished gates / operator
   follow-ups move to your cross-session handoff doc (or become tracker items).
   A "Carry-forward" section is a hand-off to this drain step, never a place
   where work lives — RUN-STATE must never become a shadow bug tracker.

Division of labor: **workers** can't usually reach your tracker's tooling from
inside a subagent, so they write *tracker-ready blocks* (title, file:line,
fix shape, why deferred) under a `Punches to file:` line in their RUN-STATE
entry; the **orchestrator** (your main session) does the actual filing when the
package lands, and performs the end-of-run archive, leaving RUN-STATE at an
idle `## Run: none active` sentinel. The next architect replaces the sentinel —
never archives it. A cheap advisory tripwire (warn when RUN-STATE has more than
one `## Run:` heading or exceeds ~300 lines — warn, never block) makes a
skipped ritual visible; wire it into whatever status script or pre-commit hook
your repo already runs.

---

## Requirements & notes

- **Claude Code** with subagent support (`.claude/agents/`) and custom slash
  commands (`.claude/commands/`).
- **Model access** to Fable, Opus, and Sonnet on your plan/org.
- **OpenAI Codex CLI** (optional, for the review gate + troubleshooting) —
  install from https://github.com/openai/codex and run `codex login` once. If
  it's absent, `scripts/codex-review.sh` exits cleanly and the workflow proceeds
  without the second opinion.
- **The `fable` alias.** The agent files use `model: fable`. If your Claude Code
  build doesn't resolve that alias, open `.claude/agents/architect.md` and
  `.claude/agents/reviewer.md` and replace `fable` with the full identifier
  `claude-fable-5`. `opus` and `sonnet` resolve as-is. Use `inherit` to make an
  agent match your main session's model.
- **The main session is the orchestrator, not Fable.** Whatever model you launch
  Claude Code with runs the top-level chat; you keep Fable at the top by
  delegating planning/review to the subagents (which `/tier` does for you).
- **Adapt to your repo.** The agents reference generic "project conventions /
  invariants docs." Point them at your real files (`CONTRIBUTING.md`, a
  `CLAUDE.md`, an architecture doc) for best results.

---

## Customize

- Change a tier's model: edit the `model:` line in that agent file.
- Loosen/tighten what a tier can touch: edit its `tools:` line.
- Add a tier (e.g. a docs-writer on Haiku): copy an agent file, rename it, set
  its `model:`/`tools:`, and reference it from `docs/workflow/TIERED-AGENTS.md`
  and `.claude/commands/tier.md`.
