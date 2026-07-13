#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${ABUJARVIS_HOME:-$HOME/.abujarvis}"
BIN_DIR="${ABUJARVIS_BIN:-$HOME/.local/bin}"
SETTINGS="$HOME/.claude/settings.json"

echo "abujarvis: installing from $REPO"

mkdir -p "$HOME_DIR" "$BIN_DIR"
ln -sf "$REPO/abujarvis" "$BIN_DIR/abujarvis"
ln -sf "$REPO/abujarvis" "$BIN_DIR/aj"
echo "  cli      -> $BIN_DIR/abujarvis (alias: aj)"

if [ ! -f "$HOME_DIR/CLAUDE.md" ]; then
  cp "$REPO/templates/role.md" "$HOME_DIR/CLAUDE.md"
  echo "  role     -> $HOME_DIR/CLAUDE.md"
else
  echo "  role     -> $HOME_DIR/CLAUDE.md (kept, already exists)"
fi

if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$HOME/.claude"
  echo '{}' > "$SETTINGS"
fi
[ -f "$SETTINGS.bak-abujarvis" ] || cp "$SETTINGS" "$SETTINGS.bak-abujarvis"

HOOK="sh -c '[ -f \"$REPO/hook.py\" ] || exit 0; python3 \"$REPO/hook.py\" || exit 0'"
python3 - "$SETTINGS" "$HOOK" <<'PY'
import json, os, sys, tempfile
path, hook = sys.argv[1], sys.argv[2]
s = json.load(open(path))
hooks = s.setdefault("hooks", {})
for event in ("SessionStart", "UserPromptSubmit", "PreCompact", "Stop"):
    lst = hooks.setdefault(event, [])
    lst[:] = [e for e in lst
              if not any("abujarvis" in h.get("command", "") for h in e.get("hooks", []))]
    lst.append({"hooks": [{"type": "command", "command": hook}]})
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as f:
    json.dump(s, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print("  hooks    -> SessionStart, UserPromptSubmit, PreCompact, Stop")
PY

echo "  backup   -> $SETTINGS.bak-abujarvis"
echo
echo "done. make sure $BIN_DIR is on your PATH, then:"
echo "  abujarvis ls        # see your tabs"
echo "  abujarvis chat      # talk to the manager"
echo
echo "kill switch: touch $HOME_DIR/OFF  (disables every hook instantly)"
