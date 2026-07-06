# Tiered Model Workflow for Claude Code

A drop-in setup that makes Claude Code **switch models automatically based on the
kind of work** — using native subagents, each pinned to its own model.

- **Architect** (Fable) — plans, decomposes the task, writes handoff packages, does the final eval. Never writes code, so its context stays clean.
- **Developer** (Opus) — the heavy lifting: real implementation + the build/fix/retry loop.
- **Test-writer** (Sonnet) — boilerplate tests, mocks, fixtures, smoke checks.
- **Reviewer** (Fable) — reads the diff and worker reports, returns a structured verdict. Read-only.

The point: keep the expensive, context-sensitive reasoning (Fable) at the two
ends, and route the high-volume trial-and-error middle to cheaper models. Full
rationale and diagram in [`docs/workflow/TIERED-AGENTS.md`](docs/workflow/TIERED-AGENTS.md).

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
    HANDOFF-TEMPLATE.md # the spec the architect hands to workers
handoffs/packages/
    README.md           # where generated handoff packages land
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
cp -r .claude docs handoffs /path/to/your/repo/
```

Commit them:

```bash
cd /path/to/your/repo
git add .claude docs/workflow handoffs/packages
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

## Requirements & notes

- **Claude Code** with subagent support (`.claude/agents/`) and custom slash
  commands (`.claude/commands/`).
- **Model access** to Fable, Opus, and Sonnet on your plan/org.
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
