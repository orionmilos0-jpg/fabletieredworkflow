# Tiered Agent Workflow

A model-tiered coding workflow: the right model does the right job, so the
expensive, context-sensitive reasoning stays at the top and the bulk of the
token volume flows to cheaper models. Built on Claude Code **subagents** — each
agent pins its own model and tool set.

## The hierarchy

| Tier | Agent | Model | Role |
|------|-------|-------|------|
| Plan / Evaluate | `architect` | **Fable** | Ingest goal, explore read-only, decompose into handoff packages, route work, do the high-level final eval. Never writes code. |
| Review | `reviewer` | **Fable** | Read diffs + worker reports against the plan and conventions. Read-only verdict. |
| Implement | `developer` | **Opus** | The heavy lifting: real implementation code, owns the build/fix/retry loop. |
| Assist | `test-writer` | **Sonnet** | Boilerplate unit tests, mocks, fixtures, smoke checks — repetitive, well-specified work. |

Why it works: the architect/reviewer (Fable) never ingest massive log output or
raw code churn, so their context stays compact. The trial-and-error loop — where
most tokens are burned — lives in Opus/Sonnet workers.

## The loop

```
        ┌──────────────────────────────────────────────┐
Goal ──▶ │  ARCHITECT (Fable)                            │
        │  restate goal → explore read-only → plan →    │
        │  write handoff packages → route by tier       │
        └───────────────┬──────────────────────────────┘
                        │  handoff packages (handoffs/packages/*.md)
          ┌─────────────┴───────────────┐
          ▼                             ▼
   DEVELOPER (Opus)              TEST-WRITER (Sonnet)
   implementation               tests / mocks / fixtures
   + build loop                 smoke checks
          │                             │
          └─────────────┬───────────────┘
                        │  synthesized reports (no raw logs)
                        ▼
        ┌──────────────────────────────────────────────┐
        │  REVIEWER (Fable) → verdict                    │
        │  approve / changes-required (routed back down) │
        └───────────────┬──────────────────────────────┘
                        ▼
              ARCHITECT final eval → commit
```

## How to run it

You (the human) talk to your top-level Claude Code session. Two ways to drive
the tiers:

**1. Let the orchestrator delegate.** Just describe the goal and ask it to use
the workflow — the easiest way is the bundled `/tier` slash command:

> `/tier add rate-limiting to the public API endpoints`

Or spell it out:

> Use the tiered workflow: have the **architect** plan this, then run the
> packages on the **developer** and **test-writer**, then get a **reviewer**
> verdict before we commit.

Claude Code routes each phase to the matching subagent (by the `name:` in the
agent file), and each subagent runs under its pinned model with its own clean
context window.

**2. Invoke a tier directly** when you already know what you want:

> Ask the **test-writer** to scaffold unit tests for `services/rate_quote.py`
> following `handoffs/packages/PKG-...-rate-tests.md`.

### Typical sequence

1. **Architect** → produces the plan + `handoffs/packages/*.md`, one per unit,
   each tagged with a tier.
2. **Developer** → implements the packages, owns the build/test loop, reports
   back synthesized results.
3. **Test-writer** → scaffolds/fills the test coverage the packages call for.
4. **Reviewer** → reads the diff + reports, returns a structured verdict.
5. **Architect** → final eval; anything failing routes back to the right worker.
6. Commit.

## Notes / knobs

- **The main session is the orchestrator, not Fable.** Whatever model you launch
  Claude Code with is what the top-level chat runs on. You keep Fable at the top
  by *delegating* planning/review to the `architect` and `reviewer` subagents —
  which is exactly what `/tier` does. Don't let the main chat do the planning
  itself.
- **Model aliases.** Agent files use `model: fable | opus | sonnet`. If your
  Claude Code build doesn't resolve the `fable` alias, replace it with the full
  identifier `claude-fable-5` in `architect.md` and `reviewer.md`. `opus` and
  `sonnet` resolve to the current Opus / Sonnet. Use `inherit` to make an agent
  match the main session's model.
- **Tools are least-privilege.** The architect and reviewer have no
  `Write`/`Edit` on code (architect gets `Write` only to emit handoff packages);
  workers get the full file+Bash set. Tighten or loosen in each file's `tools:`
  line.
- **Where things live.** Agents: `.claude/agents/*.md`. Slash command:
  `.claude/commands/tier.md`. Packages the architect emits: `handoffs/packages/`.
  This doc + the template: `docs/workflow/`.
- **Cost intuition.** Keep Fable at the two ends (plan + evaluate) and route the
  voluminous middle to Opus/Sonnet. If a task is small, skip the ceremony and
  just ask the developer directly — the tiering pays off on multi-step work.
- **Adapt to your repo.** The agents reference generic "project conventions /
  invariants docs." Point them at your actual files (e.g. `CONTRIBUTING.md`, a
  `CLAUDE.md`, an architecture doc) for best results.
