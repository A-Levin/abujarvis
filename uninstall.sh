#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${ABUJARVIS_HOME:-$HOME/.abujarvis}"
BIN_DIR="${ABUJARVIS_BIN:-$HOME/.local/bin}"
SETTINGS="$HOME/.claude/settings.json"

echo "abujarvis: uninstalling"

python3 - "$SETTINGS" <<'PY'
import json, os, sys, tempfile
path = sys.argv[1]
if not os.path.exists(path):
    sys.exit(0)
s = json.load(open(path))
hooks = s.get("hooks", {})
n = 0
for event in list(hooks):
    before = len(hooks[event])
    hooks[event] = [e for e in hooks[event]
                    if not any("abujarvis" in h.get("command", "") for h in e.get("hooks", []))]
    n += before - len(hooks[event])
    if not hooks[event]:
        del hooks[event]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as f:
    json.dump(s, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
print(f"  hooks    -> removed {n}")
PY

rm -f "$BIN_DIR/abujarvis" "$BIN_DIR/aj"
echo "  cli      -> removed"
echo
echo "state kept in $HOME_DIR (cards, queues, your manager role) — delete it yourself if you want:"
echo "  rm -rf $HOME_DIR"
echo "settings backup, if you need it: $SETTINGS.bak-abujarvis"
