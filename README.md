# Abu Jarvis

A manager for a fleet of **long-lived** Claude Code tabs.

You have a tmux session with a dozen Claude Code instances — one per project, one per area of
your life. Abu Jarvis sees what each of them is doing, hands out tasks, and shows you a board.

[По-русски](README.ru.md)

```
$ abujarvis board
WORKING (2)
    2  api                  ● Fix the flaky checkout test
       next: run the suite, open a PR | queued: 1
    5  docs                 ● Rewrite the onboarding guide

BLOCKED (1)
    8  billing                Waiting for a staging key

NO TASK (12)
    1  notes                  ~/notes
   ...
```

## Why this exists

Most tools in this space (claude-squad, vibe-kanban, kanban-code…) assume **task → new git
worktree → fresh agent → PR**. That is a great model for shipping features, and if it fits you,
use one of those — they are more mature.

Abu Jarvis is for the other shape: tabs that **already exist and outlive any single task**.
Some of them aren't even code — notes, study, journaling. You don't spawn them per task; they
are just where you work.

Two design choices follow from that, and they are the whole point:

- **It never interrupts a tab.** Tasks go into a queue. A tab picks one up only when it has
  finished what it was doing and is about to stop. (Other tools deliver work with
  `tmux send-keys`, which types into the agent mid-thought.)
- **It never guesses.** State comes from `claude agents --json`, the official interface, not from
  scraping the ANSI output of a terminal.

## Install

Requires Python 3.8+, tmux, and Claude Code.

```bash
git clone https://github.com/A-Levin/abujarvis
cd abujarvis
./install.sh
```

This symlinks the CLI into `~/.local/bin` (as `abujarvis` and `aj`), installs the manager role
into `~/.abujarvis/CLAUDE.md`, and registers four hooks in `~/.claude/settings.json`
(a backup is written next to it). Existing hooks are preserved.

## Use

```bash
abujarvis ls                        # every tab: window, status, project
abujarvis board                     # kanban by stage
abujarvis jump api                  # switch to a tab
abujarvis assign api "pull master into the open PR"
abujarvis chat                      # talk to the manager
```

`abujarvis chat` is just Claude Code with a manager role — it runs `abujarvis ls` and answers
from what it sees, so it can't make up the state of your session.

Inside a tab, the agent reports on itself (the hooks tell it to, you don't have to):

```bash
abujarvis set --goal "Fix the flaky checkout test" --stage doing --next "run the suite"
```

## How it works

| | |
|---|---|
| **Who is running** | `claude agents --json` → pid, sessionId, cwd, name, status |
| **Which tmux window** | walk `/proc` PPid chain from the pid up to a `pane_pid` |
| **What a tab is doing** | `~/.abujarvis/state/<sessionId>.json` — hooks write facts, the agent writes meaning |
| **Handing out tasks** | `~/.abujarvis/inbox/<sessionId>.jsonl`, drained by the `Stop` hook |

The identifier is `sessionId`, not pid: a pid dies when a tab restarts, a sessionId survives.

### Why a queue instead of just typing into the tab

You **cannot** programmatically inject a prompt into a live interactive Claude Code process —
`claude --resume` spawns a *new* one. So the only correct channel is to let the tab come get the
work itself:

1. `abujarvis assign` appends to the tab's inbox (under `flock`).
2. The tab finishes, is about to stop, and the `Stop` hook fires.
3. The hook pops a task and returns `{"decision": "block", "reason": "<task>"}`.
4. The agent keeps going, now working on that task.

Loop protection: if `stop_hook_active` is true, the hook exits immediately — and the task stays
in the queue rather than being consumed.

### Cards

Hooks write what can be measured; the agent writes what only it knows.

```json
{
  "cwd": "…", "branch": "fix-checkout", "dirty_files": 4,  // hooks
  "last_prompt": "fix the flaky test",                     // hook
  "goal": "Fix the flaky checkout test",                   // agent
  "stage": "review", "next": "run the suite, open a PR"    // agent
}
```

An instruction alone would not survive: the agent eventually forgets, and the board starts
lying quietly. A board you can't trust is worse than no board.

## What it writes to disk

The hooks are registered **globally**, so they fire in every Claude Code session you run — not
just the tabs of the managed tmux session. Per session, Abu Jarvis writes one card to
`~/.abujarvis/state/<sessionId>.json` (mode `0600`) with the cwd, git branch, dirty-file count,
and whatever the agent reported about itself.

It does **not** log your prompts by default. Set `ABUJARVIS_LOG_PROMPTS=1` if you want the first
200 characters of each prompt stored in the card too.

Tasks and their history live in `~/.abujarvis/inbox/` and `~/.abujarvis/done/`.

Nothing is sent anywhere. It is all local files.

## Trust model

The inbox is a plain file. Anything running as your user can drop a task into a tab's queue —
including another Claude Code agent. A task is handed to the agent as *user input*, not as a
system order: the agent keeps its own judgment and permissions and can refuse it. Still, if a tab
runs with `--dangerously-skip-permissions`, treat its inbox as trusted input, because that is
what it is.

## Kill switch

```bash
touch ~/.abujarvis/OFF     # every hook becomes a no-op, instantly
```

The hooks touch the lifecycle of every tab you work in, so this matters. `hook.py` is wrapped in
`try/except → exit 0`: malformed JSON, empty stdin, a missing session id, a non-git directory —
all exit silently rather than breaking the tab you are typing in.

Queued tasks are not lost while OFF; they are just not handed out.

If the repo is moved or deleted, the hooks become no-ops rather than blocking your tabs — the
registered command checks that `hook.py` exists first. To remove Abu Jarvis properly:

```bash
./uninstall.sh     # unregisters the hooks and the CLI; leaves your state alone
```

One caveat worth knowing: a task is popped from the queue *before* the agent acts on it. If the
session dies in that window, the task is gone from the queue without having been done.

## Status

Working: tab registry, cards, kanban in the terminal, task queue, the manager you can talk to.

Not built yet: a TUI/web board, and the "full orchestrator" role (creating and killing tabs,
making worktrees, restarting stuck tabs) — that one touches your live session, so it waits.

## Configuration

| Env var | Default | Meaning |
|---|---|---|
| `ABUJARVIS_SESSION` | `dev` | tmux session to manage |
| `ABUJARVIS_HOME` | `~/.abujarvis` | state, queues, manager role |

## License

MIT
