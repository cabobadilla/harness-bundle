#!/usr/bin/env bash
# Persists a session summary at the end of each Claude Code session.
set -euo pipefail
DATE=$(date +%Y-%m-%d-%H%M%S)
SESSION_DIR="memory/sessions"
mkdir -p "$SESSION_DIR"
INPUT=$(cat)
cat > "$SESSION_DIR/$DATE.md" <<HOOKEOF
# Sesión $DATE

\`\`\`json
$INPUT
\`\`\`
HOOKEOF
exit 0
