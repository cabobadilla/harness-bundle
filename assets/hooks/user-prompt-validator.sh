#!/usr/bin/env bash
# UserPromptSubmit hook — block prompts that contain obvious secrets.
# Reads JSON from stdin, returns JSON decision when a secret is detected.
set -euo pipefail
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
[[ -z "$PROMPT" ]] && exit 0

# Patrones de secretos comunes — bloquear antes de mandar al modelo.
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                      # AWS access key
  'aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{40}'
  'sk-(proj-)?[A-Za-z0-9_-]{32,}'         # OpenAI / Anthropic style
  'sk-ant-[A-Za-z0-9_-]{20,}'             # Anthropic
  'ghp_[A-Za-z0-9]{30,}'                  # GitHub PAT classic
  'github_pat_[A-Za-z0-9_]{60,}'          # GitHub fine-grained
  'glpat-[A-Za-z0-9_-]{20,}'              # GitLab PAT
  '-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----'
  'xox[abposr]-[A-Za-z0-9-]{10,}'         # Slack tokens
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$PROMPT" | grep -qE "$pattern"; then
    cat <<HOOKEOF
{"decision": "block", "reason": "El prompt contiene lo que parece ser un secreto/credencial. Quítalo y reintenta — el modelo no lo necesita."}
HOOKEOF
    exit 0
  fi
done
exit 0
