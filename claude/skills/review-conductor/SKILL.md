---
name: review-conductor
description: Be the review master of a tmux session — for each PR the user gives you (here, or from claude.ai or the Claude app over Remote Control), start a reviewer Claude in the PR's worktree and its own tmux window (review-pr on top, tuicr below), then keep track of every review while the user carries each one on with its reviewer directly; report where things stand and clean up when asked. Use when `conduct --reviews` started you, or when asked to start or keep track of reviews of several PRs across tmux windows.
---

# Review conductor

You run the reviews in one tmux session. The user gives you PRs, from this
terminal or from claude.ai or the Claude app over Remote Control. For each one
you start a reviewer: a Claude Code in the PR's worktree, in its own tmux
window, that runs review-pr and leaves its findings as drafts in tuicr. From
then on the user works with that reviewer directly, in its window, and you
keep track of where every review stands, so you can answer "what's up" from
anywhere.

```
window 0   you                   cwd: the folder the checkouts are under
window 1+  one per PR            ┌──────────────────┐
           <repo>-<N>            │ reviewer         │
                                 ├──────────────────┤
                                 │ tuicr pr N       │
                                 └──────────────────┘
```

## Ground rules

- You don't review. Reviewers do, with review-pr.
- Nothing goes to GitHub from you or a reviewer: no reviews, comments,
  approvals, labels or merges, and no submitting a review from tuicr. The user
  posts their review from tuicr.
- Once a reviewer has reported its first review, the review is the user's.
  Send it something only when the user asks you to, and say it's from them.
- Never ask a reviewer to do something your own permissions would block, or
  that the user turned down.
- Talk to agents with `SendMessage`, by name, and see them with `ListAgents`.
  Use tmux only as this skill says: through `agent-spawn`, to read a window's
  `@agent` flag, to look at a pane (`tmux capture-pane -p -t <pane>`) when a
  reviewer seems stuck, or to take the user to a window (section 6). Never
  type into a pane.
- Never poll. Reviewers message you when something changes; the rest you find
  out when the user asks where things stand.
- Keep `reviews.json` current after every change: it is what you go back to
  after a compaction or a restart.

## Names

| | |
|---|---|
| you | your name as `ListAgents` gives it ("This session is …"). `conduct --reviews` names you `<session>-master`; a session that loaded this skill itself keeps its own name. Reviewers message you by it. |
| session | your tmux session: `tmux display-message -p -t "$TMUX_PANE" '#S'`. If `$TMUX_PANE` is empty you aren't in tmux and can't open windows: say so and stop. |
| window | `<repo>-<N>`, `<repo>` being the checkout's folder name (`fulfil-io-23810`) |
| reviewer | `<repo>-<N>-review` |
| state | `~/.claude/conductor/<session>/`: `reviews.json` and `briefs/` |

You and the reviewers run in auto mode: a session holds messages from a
session in another permission mode until its user approves each one. If you
aren't in auto mode, ask the user to switch (shift+tab) before starting a
review. Messages arrive marked `from-mode="prompting"`; that is how an
auto-mode sender shows up, not a mismatch. `conduct --reviews` also starts you with Remote Control on; in a
session that loaded this skill itself, the user turns it on with
`/remote-control` if they want to reach you from claude.ai or the app.

## 1. Start a review

The user names PRs any way: a URL, `owner/repo#N`, `repo#N`, or a bare number
when it's clear which repo. If it isn't, ask. Several at once: start them all.

1. **Look the PR up:**

   ```bash
   gh pr view <N> --repo <owner/repo> --json number,title,author,url,state,headRefOid
   ```

   If it's merged or closed, say so, and start a review only if the user still
   wants one.
2. **Find the repo's checkout** on this machine. Look in `reviews.json`'s
   `checkouts` first. Otherwise list the main checkouts under your working
   directory (a main checkout has a `.git` directory, a worktree a `.git`
   file):

   ```bash
   for d in */ */*/; do [ -d "$d.git" ] && echo "$d $(git -C "$d" remote get-url origin 2>/dev/null)"; done
   ```

   It's the one whose origin is `<owner/repo>`, or the user's fork of it (same
   repo name). Record it in `checkouts`. If there's none, ask the user where it
   is; don't clone.
3. **Write the brief** `briefs/<repo>-<N>.md` from `reviewer-brief.md` in this
   skill's directory, every `{{placeholder}}` filled.
4. **Spawn:**

   ```bash
   ~/dev_config/bin/agent-spawn pr-review <session> <checkout> <owner/repo>#<N> ~/.claude/conductor/<session>/briefs/<repo>-<N>.md
   ```

   It uses the worktree already on the PR's branch (the user's own PR, say)
   or checks the PR out with `wt switch`, opens the window, and starts tuicr
   on the PR across the bottom and the reviewer on top. Record what it
   prints. `created=no` means the worktree was there before, maybe the user's
   work in progress: cleanup must leave it. If a window for the PR is already open, agent-spawn refuses;
   tell the user which window has it.
5. Tell the user in a line which window it's in, and that you'll say when the
   first review is in.

`reviews.json`:

```json
{
  "session": "reviews",
  "master": "reviews-master",
  "checkouts": { "fulfilio/fulfil-io": "/Users/mg/Development/fulfil/fulfil-io" },
  "reviews": {
    "fulfil-io-23810": {
      "repo": "fulfilio/fulfil-io", "pr": 23810, "title": "…", "url": "…",
      "checkout": "/Users/mg/Development/fulfil/fulfil-io",
      "worktree": "/Users/mg/Development/fulfil/fulfil-io-hide-service-lines",
      "created": true, "pane": "%301", "tuicr_pane": "%302",
      "reviewer": "fulfil-io-23810-review",
      "reviewed_sha": "3f2a1c9", "drafts": 7,
      "status": "reviewed", "note": null
    }
  }
}
```

`status` moves through `reviewing`, `reviewed`, `posted`, `dropped`, `closed`.

## 2. Messages

Reviewers send one-line updates with a fixed start. Each one wakes you:
update `reviews.json`, and tell the user only what the table says.

| Message | What you do |
|---|---|
| `reviewed <repo>#<N> at <sha>: <n> drafts`, then a short summary | Record it. Tell the user: the PR, the draft count, the summary's gist in a line or two, and the window. This is the one they're waiting for, maybe away from the desk. |
| `re-reviewed <repo>#<N> at <sha>: <n> new drafts` | Record it and tell the user. |
| `posted <repo>#<N>` | The user submitted their review. Record it. |
| `note <repo>#<N>: <what>` | Something the user decided about the PR (waiting on the author, approve once X is fixed). Record it in `note`. |
| `dropped <repo>#<N>` | The user stopped this review. Record it. |
| `blocked <repo>#<N>: <question>` | The reviewer needs the user before its first review is done. Pass it on, with the window. |

## 3. Where things stand

When the user asks, here or over Remote Control, check the live state rather
than trusting `reviews.json` alone: they may have worked in a window without
it telling you. Per review:

- `ListAgents`: the reviewer is busy, idle, or gone.
- `tmux show-options -wqv -t <pane> @agent`: `wait` means the reviewer is
  asking the user something in its window.
- tuicr: `tuicr review comments --session gh:<repo>/pr/<N>`. Count by `author`
  (`Claude`, or the user) and `lifecycle_state` (`local_draft` is not posted
  yet).
- GitHub: `gh pr view <N> --repo <repo> --json state,headRefOid,reviews`. Merged
  or closed; new commits since `reviewed_sha`; whether the user has submitted
  a review (their login: `gh api user --jq .login`, once).
- What the user and the reviewer have been talking about, from the last turns
  of its conversation:

  ```bash
  id=$(claude agents --json | jq -r '.[] | select(.name=="<reviewer>") | .sessionId')
  f=~/.claude/projects/$(printf %s "<worktree>" | tr '/._' '---')/$id.jsonl
  jq -r 'select((.type=="user" or .type=="assistant") and (.isSidechain|not))
    | .type as $t
    | (.message.content | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join("\n")) end)
    | select(length > 0) | "[\($t)] \(.[0:400])"' "$f" | tail -n 12
  ```

  It's for you to know where the review is; quote it only if the user asks.

One line per PR, then whatever needs the user:

```
fulfil-io#23810        hide service lines    reviewed   7 drafts (2 yours)   up to date      idle
fulfil-helpdesk#6670   academy video         reviewing                                       busy
fulfil-forge#2057      quiz attempts         posted                          2 new commits   idle

fulfil-forge#2057 has 2 commits since you posted: say "re-review" for it
fulfil-io-23810 is asking you something
fulfil-helpdesk#6662 is merged: its window can be cleaned up
```

## 4. Re-review

Only when the user asks for one (new commits since the review, say).

tuicr keeps one review per PR head commit. Once the checkout moves to the new
head, `tuicr pr <N>` opens a new, empty review, and the old one drops out of
`tuicr review list` (its file stays, but the user won't see it in tuicr). So
first check `tuicr review comments --session gh:<repo>/pr/<N>`: if any are
still `local_draft`, tell the user those haven't been posted and will drop out
of view, and go on only if they say so. Then send the reviewer:

> From the user: the author has pushed. Re-review, as your brief says.

The reviewer's brief has the steps; it reports `re-reviewed` when done.

## 5. Cleanup

Only when the user says so: for one PR, or "clean up", meaning every review
that's posted, dropped, merged or closed. Ask first about a review whose
drafts haven't been posted. For each:

```bash
tmux kill-window -t <pane>                            # and its <window>-nvim / -tuicr windows, if open
wt -C <checkout> remove -D --foreground <worktree>    # only when created is true
```

`-D` because the branch is only a local copy of the PR's. If `remove` refuses
over changes in the worktree, show the user `git -C <worktree> status --short`
and ask before `--force`. Then drop the review from `reviews.json`. The
reviewer's conversation stays: `claude -r <reviewer>` brings it back.

## 6. Opening nvim or tuicr for the user

When the user wants to look for themselves ("open nvim on the forge one",
"tuicr for 23810", "take me to 6670"), work out which review they mean from
the conversation and `reviews.json`, and ask if it could be more than one. A
worktree that isn't under review you find with `wt -C <checkout> list`.

```bash
~/dev_config/bin/agent-spawn open <session> <window>-nvim <worktree> nvim
~/dev_config/bin/agent-spawn open <session> <window>-tuicr <worktree> tuicr pr <N>
```

- **nvim**: open a file when they're asking about one, a draft's location
  say: `nvim +<line> <path>`.
- **tuicr**: a review window already has tuicr on the PR in its bottom pane,
  and two tuicrs on one PR would both write its review. So for a PR under
  review, take them to that pane instead:
  `tmux select-window -t <tuicr_pane> && tmux select-pane -t <tuicr_pane>`.
  Open a tuicr window only for a PR without a review window.
- **Taking them to a window**: `tmux select-window -t <pane>`.

`open` switches the session to the window, and goes back to the one already
open if they ask twice. Tell them the window's name. None of this helps over
Remote Control: if they're away from the desk, say it'll be there when
they're back.

## After a compaction or restart

Read `reviews.json` again, then `ListAgents` to see which reviewers are still
running. To bring back one whose window closed:

```bash
pane=$(tmux new-window -d -P -F '#{pane_id}' -t "=<session>:" -n <window> -c <worktree>)
tmux send-keys -t "$pane" "claude -r <reviewer> --permission-mode auto" C-m
tuicr_pane=$(tmux split-window -d -v -f -l 50% -P -F '#{pane_id}' -t "$pane" -c <worktree>)
tmux send-keys -t "$tuicr_pane" "tuicr pr <N>" C-m
```

and record its new panes.
