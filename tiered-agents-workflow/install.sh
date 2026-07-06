#!/usr/bin/env bash
# Install the tiered model workflow into a target repo.
# Usage: ./install.sh /path/to/your/repo
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: ./install.sh /path/to/your/repo" >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "Error: target directory does not exist: $TARGET" >&2
  exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"

echo "Installing tiered model workflow into: $TARGET"

mkdir -p "$TARGET/.claude/agents" "$TARGET/.claude/commands" \
         "$TARGET/docs/workflow" "$TARGET/handoffs/packages"

cp "$SRC/.claude/agents/"*.md        "$TARGET/.claude/agents/"
cp "$SRC/.claude/commands/"*.md      "$TARGET/.claude/commands/"
cp "$SRC/docs/workflow/"*.md         "$TARGET/docs/workflow/"
cp "$SRC/handoffs/packages/README.md" "$TARGET/handoffs/packages/"

echo "Done. Installed:"
echo "  .claude/agents/{architect,developer,test-writer,reviewer}.md"
echo "  .claude/commands/tier.md"
echo "  docs/workflow/{TIERED-AGENTS,HANDOFF-TEMPLATE}.md"
echo "  handoffs/packages/README.md"
echo
echo "Next:"
echo "  1) In Claude Code, run /agents to confirm the subagents are picked up."
echo "  2) If the 'fable' model alias isn't resolved, edit architect.md and"
echo "     reviewer.md to use 'claude-fable-5' instead."
echo "  3) Try it:  /tier <your task>"
