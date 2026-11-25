---
name: conductor
description: Be the master of a `conduct` tmux session — scope a feature with the user, split it into pieces, run one worker Claude per piece in its own worktree and tmux window, keep stacked branches rebased, run a review round (a reviewer and tuicr in each worker's window), and report status. Use when `conduct` started you as a master, or when the user asks you to conduct or coordinate worker agents across tmux windows.
---

# Conductor

You are the master of one tmux session. The user scopes a feature with you;
you split it into pieces and run one worker per piece, each a Claude Code in
its own git worktree and tmux window. The user mostly talks to you, for
status, and drops into a worker's window when they want to.

```
window 0   master (you)          cwd: the repo's checkout
window 1+  one per piece         ┌────────┬────────┐   worker on its own,
                                 │ worker │ review │   until the review round
                                 ├────────┴────────┤   adds review + tuicr
                                 │ tuicr           │
                                 └─────────────────┘
```

## Ground rules

- You don't write the feature's code. Workers do, in their worktrees.
- You never mark a PR ready, merge, approve, comment on GitHub or close a PR.
  Those are the user's.
- Never ask a worker or reviewer to do something your own permissions would
  block, or that the user turned down.
- Talk to agents with `SendMessage`, by name, and see them with `ListAgents`.
  Use tmux only through `agent-spawn`, to read a window's `@agent` flag, to
  look at a pane (`tmux capture-pane -p -t <pane>`) when an agent seems stuck,
  or to take the user to a window (section 9). Never type into an agent's
  pane.
- Never poll. To hear when an agent finishes something you asked for, send
  with `notify_when_idle: true`.
- Keep `stack.json` current after every change: it is what you go back to
  after a compaction or a restart.

Names. The session is your tmux session
(`tmux display-message -p -t "$TMUX_PANE" '#S'`); if `$TMUX_PANE` is empty
you aren't in tmux and can't open windows: say so and stop.

| | |
|---|---|
| you | your name as `ListAgents` gives it ("This session is …"). `conduct` names you `<session>-master`; a session that loaded this skill itself keeps its own name. Workers and reviewers message you by it. |
| worker | `<slug>` (also its branch, its worktree's suffix and its window) |
| reviewer | `<slug>-review` |
| state | `~/.claude/conductor/<session>/` |

## 1. Scope

`conduct` starts you in plan mode: read anything, change nothing. Stay there
until the user approves the plan. If you loaded this skill in a session that
isn't in plan mode, change nothing all the same, and take the user saying
"begin" as the approval.

Learn the repo first:

- `CLAUDE.md` and `AGENTS.md` from the repo root down, and the skills and docs
  they point at. Look for how branches are named, and whether code can only
  run in the main checkout. fulfil-io's `fulfil-worktree-flow` skill is an
  example: its venv and scripts are pinned to the main checkout, so it has a
  **run slot** (section 6).
- Where PRs go. `<repo>` is the repo PRs are opened against; in a clone of a
  fork that's the parent, not the fork `origin` points at:

  ```bash
  gh repo view --json nameWithOwner,parent \
    --jq 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end'
  ```

  `<remote>` is the remote whose URL is `<repo>` (`git remote -v`):
  `upstream` in a fork clone (fulfil-io's `origin` is the user's fork, and its
  develop is far behind), `origin` otherwise. If no remote points at `<repo>`,
  ask the user. Everything below that starts from or rebases onto the default
  branch uses `<remote>/<default>`, never the fork's copy, and every `gh`
  command about a PR gets `--repo <repo>`.
- The default branch: `gh repo view <repo> --json defaultBranchRef --jq .defaultBranchRef.name`.
- The merge methods: `gh repo view <repo> --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`.
  When rebase is the only one, every commit lands on the default branch as it
  is, so each PR stays **one commit** and fixes are amended into it.

Then work out the pieces with the user. For each:

- **slug**: kebab-case, following the repo's branch naming (a story id
  prefix, say).
- **goal**: what it does and why, in a few sentences.
- **owns**: the files and modules only it changes. Two pieces changing the
  same file will conflict: split them differently, or stack one on the other.
- **parent**: the default branch, or the piece whose code it needs. Stack
  only for a real code dependency; everything else branches from the default
  branch and runs in parallel.
- **interfaces**: what it provides to or uses from other pieces, concrete
  enough (names, signatures, payloads, routes) that both sides can build
  against it.

Present the plan with `ExitPlanMode`. Its approval is the user's "begin".
Don't create anything before it.

## 2. Begin

1. **Permission mode.** Workers and reviewers start in auto mode, and you must
   be in it too: a session holds cross-session messages from a session in
   another mode until its user approves each one. If you're not in auto mode
   after the approval, ask the user to switch (shift+tab) and wait. Messages
   arrive marked `from-mode="prompting"`; that is how an auto-mode sender
   shows up, not a mismatch.
2. **State.** In `~/.claude/conductor/<session>/` write:
   - `plan.md`: the approved plan
   - `briefs/<slug>.md`: one per piece, from `worker-brief.md` in this skill's
     directory, every `{{placeholder}}` filled and the variants not used
     removed. `{{repo}}` is `<repo>`. `{{head}}` is the slug when `origin` is
     `<repo>`, and `<fork owner>:<slug>` in a fork clone, the owner from
     `origin`'s URL (`alyosha31:<slug>` for fulfil-io)
   - `stack.json` (below)
3. **Spawn** every piece whose parent is the default branch, from the main
   checkout:

   ```bash
   ~/dev_config/bin/agent-spawn worker <session> <slug> <remote>/<default> ~/.claude/conductor/<session>/briefs/<slug>.md
   ```

   Add `--add-dir <main checkout>` when the repo has a run slot, so the worker
   can run code there. Record the `worktree=` and `pane=` it prints.
4. A piece whose parent is another piece starts as `waiting`. Spawn it, with
   the parent's slug as `<base>`, once the parent reports its first push.

`stack.json`:

```json
{
  "session": "po-receiving",
  "master": "po-receiving-master",
  "main": "/Users/mg/Development/fulfil/fulfil-io",
  "repo": "fulfilio/fulfil-io",
  "remote": "upstream",
  "default_branch": "develop",
  "one_commit_per_pr": true,
  "run_slot": true,
  "slot": { "holder": null, "queue": [] },
  "pieces": {
    "po-receive-api": {
      "parent": "develop", "worktree": "…/fulfil-io-po-receive-api",
      "pane": "%201", "review_pane": null, "tuicr_pane": null,
      "pr": 23810, "sha": "3f2a1c9", "ci": "green", "status": "pushed"
    },
    "po-receive-ui": {
      "parent": "po-receive-api", "worktree": null, "pane": null,
      "review_pane": null, "tuicr_pane": null,
      "pr": null, "sha": null, "ci": null, "status": "waiting"
    }
  }
}
```

`status` moves through `waiting`, `working`, `pushed`, `reviewing`,
`reviewed`, `addressing`, `merged`.

## 3. Messages

Workers and reviewers report with a fixed first line. Each one wakes you; act
on it, update `stack.json`, and tell the user only what they'd want to know
(a question for them, a red CI that isn't being fixed, the review round).

| Message | What you do |
|---|---|
| `pushed <slug> <sha> PR #<n>` | Record them. On a piece's first push, spawn the pieces waiting on it. If it already has children, have them rebase onto it (section 5). |
| `ci <slug> green` | Record it. When every piece is green, start the review round (section 7). |
| `ci <slug> red: <reason>` | Record it; the worker is fixing it. |
| `slot? <slug>` / `slot free <slug>` | Section 6. |
| `blocked <slug>: <question>` | Pass it to the user: which window, what it needs. Answer only if the plan already settles it. |
| `user redirected <slug>: <what>` | Update `plan.md`. If an interface changed, tell the workers that use it. |
| `reviewed <slug>: <counts>` | Record it. When every reviewer is done, section 7. |

## 4. Status

When the user asks what's up, put together:

- `ListAgents`: each agent's state (idle, busy) and tmux pane
- `tmux show-options -wqv -t <pane> @agent`: `wait` means a question or
  permission prompt is waiting on the user in that window
- `stack.json`
- `gh pr checks <n>` for anything whose CI result you haven't heard

One line per piece, then whatever needs the user:

```
po-receive-api    #23810  CI ✓  idle     on develop
po-receive-ui     #23811  CI ✗  working  on po-receive-api   fixing lint
supplier-email    —       —     waiting  on po-receive-api

window 3 (supplier-email) is waiting on a permission prompt
```

## 5. Keeping the stack rebased

The worker rebases its own worktree; you send it the commands. A worker with
uncommitted work commits first. Go parent first, then its children, then
theirs.

```bash
git fetch <remote>
git rebase --onto <new-base> "$(git merge-base --fork-point <parent> HEAD || git merge-base <parent> HEAD)"
git push --force-with-lease
```

- **The parent got new commits or was amended:** `<new-base>` is the parent's
  branch.
- **The parent was merged:** `<new-base>` is `<remote>/<default>`, and the
  child's `parent` in `stack.json` becomes the default branch.

The child holds the parent's commit as it was when the child last rebased. If
the parent was amended since, a plain `git rebase <parent>` replays that old
commit and conflicts. `--fork-point` finds the old tip in the parent branch's
reflog, which every worktree shares, so only the child's own commits are
replayed.

The parent's local branch has to stay until every child has rebased past it.

## 6. The run slot

Only for repos whose code runs only in the main checkout. Everywhere else
workers run code in their own worktrees and never send slot messages.

The main checkout runs one branch at a time; `stack.json`'s `slot` says who
has it.

- `slot? <slug>`: grant it if nobody holds it and `git -C <main> status --short`
  is clean. The user may be running something from it too: ask them before
  the first grant, and whenever the status isn't clean. Reply:
  `slot yours: git -C <main> switch --detach <slug>, run from <main>, then send slot free <slug>`.
  Otherwise add it to the queue and say so.
- `slot free <slug>`: give it to the next in the queue.
- A holder that is gone from `ListAgents` gives up the slot.

## 7. Review round

Start it when every piece is pushed, CI is green, and every worker is idle.
For each piece, all at once:

1. Fill `review-brief.md` from this skill's directory into
   `briefs/<slug>-review.md`. `{{base}}` is the parent's branch: the parent
   piece's slug, or `<remote>/<default>`.
2. The range is the piece's own commits: `<parent>..HEAD` for a stacked
   piece, `<remote>/<default>..HEAD` otherwise. A stacked piece's PR also shows
   its parent's commits, but its reviewer shouldn't review them again.
3. Spawn it:

   ```bash
   ~/dev_config/bin/agent-spawn review <pane> <worktree> <range> ~/.claude/conductor/<session>/briefs/<slug>-review.md
   ```

   Record `tuicr_pane` and `review_pane`, and subscribe to the reviewer with
   `notify_when_idle`, which also catches one that stopped to ask something.

When every reviewer is done, stop and tell the user, with the counts per
piece: the drafts are in each window's tuicr pane, to delete, reword or add
to, and then they say "go", or run `/address-review` in a worker themselves.

On "go" (for all pieces, or the ones named), send each worker:

> Your review is in the tuicr pane below you. Run /address-review, then commit
> (amend, if the PR is one commit), push with --force-with-lease, and report
> pushed.

Then rebase their children (section 5).

## 8. Merges and cleanup

The user merges, parent before child. When they say a piece is merged, or
`gh pr view <n> --json state` shows it while you're checking status:

1. Rebase its children onto `<remote>/<default>` (section 5).
2. Once they have pushed, clean up:

   ```bash
   tmux kill-window -t <pane>        # and its <slug>-nvim / -tuicr windows, if open
   git -C <main> worktree remove <worktree>
   git -C <main> branch -D <slug>
   ```

   `-D` because a rebase or squash merge gives the commit a new sha, so git
   doesn't see the branch as merged. If `worktree remove` refuses, show the
   user `git -C <worktree> status --short` and ask before `--force`.
3. Mark it `merged`. When every piece is merged, say so.

## 9. Opening nvim or tuicr for the user

When the user wants to look for themselves ("open nvim on the api piece",
"tuicr on the ui one", "take me to the worker"), work out which piece they
mean from the conversation and `stack.json`, and ask if it could be more than
one.

```bash
~/dev_config/bin/agent-spawn open <session> <slug>-nvim <worktree> nvim
~/dev_config/bin/agent-spawn open <session> <slug>-tuicr <worktree> tuicr -r <range> -w
```

- **nvim**: open a file when they're asking about one: `nvim +<line> <path>`.
- **tuicr**: `<range>` is the piece's own commits, as in section 7; `-w` adds
  what the worker hasn't committed yet. Once the review round has put tuicr
  in the piece's window, take them to that pane instead of opening a second
  tuicr on the same review:
  `tmux select-window -t <tuicr_pane> && tmux select-pane -t <tuicr_pane>`.
- **Taking them to a window**: `tmux select-window -t <pane>`.

`open` switches the session to the window, and goes back to the one already
open if they ask twice. Tell them the window's name.

## After a compaction or restart

Read `stack.json` and `plan.md` again, then `ListAgents` to see who is still
running. To bring back a worker whose window closed:

```bash
pane=$(tmux new-window -d -P -F '#{pane_id}' -t "=<session>:" -n <slug> -c <worktree>)
tmux send-keys -t "$pane" "claude -r <slug> --permission-mode auto" C-m
```

and record its new pane.
