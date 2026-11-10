---
name: review-pr
description: Review a GitHub pull request, or the current branch's local work before there is one, end to end from its checkout — the repo's conventions, whether each change is sound and needed, what it affects outside the diff, and whether a test covers it — adding every finding as a draft comment in the reviewer's tuicr review, then hand the reviewer a summary to start from: what the change is for, the business reason, the approach taken, and the files they must read themselves. Works in any repo, forks included. Local only; never posts to GitHub. Use when asked to review a PR, review a branch or another agent's changes, or give feedback on someone's change.
---

# Review a pull request, or local work

Read the whole change on your own, put every finding into the reviewer's tuicr
review as a draft, and finish with a summary that gets them oriented. They read
the change themselves afterwards, in tuicr, with your drafts already in place,
and keep, rewrite or delete each one. On a PR, everything they post goes out
under their name; on local work, the agent that wrote it picks the comments up
with `/address-review`.

Local only. Never `gh pr review`, `gh pr comment`, any `gh api` write, or
tuicr's `:submit`. Never edit, commit, switch branches, or run tests in the
checkout. Drafts go only into tuicr (`tuicr review add` writes a local file).
Never change or delete a comment the reviewer wrote.

## 1. Decide what to review

The reviewer runs this from inside the checkout: a PR's worktree (usually made
with `wt switch pr:N`), or the branch another agent is working on. The checkout
is the current repo root.

First, the repo PRs are opened against. In a fork that is the parent, not the
fork the checkout cloned:

```bash
gh repo view --json nameWithOwner,parent \
  --jq 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end'
```

`<repo>` below is that `owner/name`. Then the mode:

- **PR mode** when the argument is a PR number, or when there is no argument,
  the working tree is clean, and a PR's head is this checkout:

  ```bash
  gh pr list --repo <repo> --state open \
    --search "$(git rev-parse HEAD)" --json number,title
  ```

- **Local mode** otherwise: the branch's commits plus its uncommitted and
  untracked changes, before there is a PR. With uncommitted changes, use local
  mode even when a PR matches `HEAD`, since a PR review would leave them out.

Say in one line which mode you chose and what it covers.

### PR mode

```bash
gh pr view N --repo <repo> \
  --json number,title,body,author,url,baseRefName,headRefOid,commits,additions,deletions,changedFiles
```

If `HEAD` is not `headRefOid`, stop and say so: the author has pushed since it
was checked out, and reviewing a stale commit produces comments on code that no
longer exists. Ask the reviewer to bring the checkout up to date. The base
branch is `baseRefName`.

### Local mode

The base branch is `<repo>`'s default branch, unless the argument names
another:

```bash
gh repo view <repo> --json defaultBranchRef --jq .defaultBranchRef.name
```

If the commits since the merge-base include work that is clearly not this
branch's (it was cut from another feature branch), ask which base to use.

Another agent may still be at work in this checkout. Review what is on disk
now; if a file changes while you read it, read it again.

### The base and the diff

Fetch the base branch straight from `<repo>` and take the merge-base in the
same command, before anything else fetches and moves `FETCH_HEAD`:

```bash
git fetch --quiet https://github.com/<repo>.git <base-branch> && git merge-base FETCH_HEAD HEAD
```

`<base>` below is that sha. The fetch goes to `<repo>` itself because the
checkout's own remotes may be a fork whose base branch is far behind, which
would add changes that are not in the review, and over HTTPS because that uses
gh's credentials where an SSH remote may need a passphrase.

PR mode diffs `<base>` against `HEAD`, which is what GitHub shows; check the
totals match `additions`, `deletions` and `changedFiles`:

```bash
git diff --stat <base> HEAD
```

Local mode diffs `<base>` against the working tree, so commits and uncommitted
edits come as one diff. `git diff` leaves out untracked files: list them and
read each one whole as an added file.

```bash
git diff --stat <base>
git rev-list --count <base>..HEAD
git ls-files --others --exclude-standard
```

## 2. Open the tuicr review

Drafts need tuicr to have the review open: until it does, `tuicr review add`
fails.

**PR mode.** PR reviews are listed under `<repo>`:

```bash
tuicr review list --repo <repo>
```

A row whose `slug` is `gh:<repo>/pr/N` means it is open; use that slug.
Otherwise open it with `tuicr pr N`. tuicr finds a fork's parent on its own,
so the bare number is enough.

**Local mode.** Local reviews are listed under the checkout, by branch and the
commits they cover:

```bash
tuicr review list
```

Open it on the branch's commits and the working tree, or on the working tree
alone when `git rev-list --count <base>..HEAD` is 0:

```bash
tuicr -r <base>..HEAD -w
tuicr -w
```

The slug to use is the row with `"kind": "local"`, `"active": true` and the
current branch as its `anchor`.

**Either mode**, inside tmux (`$TMUX` is set), open tuicr in a pane beside this
one, in this checkout so its `e` opens the real files, and leave the reviewer's
focus where it is. The last argument is the tuicr command from above:

```bash
tmux split-window -d -h -c "$(git rev-parse --show-toplevel)" "tuicr pr N"
tmux split-window -d -h -c "$(git rev-parse --show-toplevel)" "tuicr -r <base>..HEAD -w"
```

Then run `tuicr review list` every few seconds until the row appears; tuicr
loads the diff first. Outside tmux, or if the split fails (a sandbox can block
the tmux socket), ask the reviewer to run the same tuicr command in this
checkout and to say when it is open. If they don't want tuicr this time, carry
on and give the findings in the chat at the end instead (section 6).

If the reviewer quits tuicr before you finish, an empty review is deleted and
adds start failing again; reopen it the same way.

## 3. Load what this repo expects

Some repos have review knowledge their own docs don't spell out: files that are
generated, checks that matter for their framework, how their commits are
written. It lives in `~/.claude/review-notes/`, one file per repo, named after
`<repo>` with the slash as a dash (`acme/shop` → `acme-shop.md`):

```bash
ls ~/.claude/review-notes/
```

If there is one for `<repo>`, read it now. It adds to every section below, and
where it is more specific, it wins.

## 4. Establish what the change sets out to do

The "is this hunk needed" check, and the summary at the end, are only as good
as this.

- **PR mode:** the PR title and body, the commit messages, and any issue or
  ticket they link. If the goal is unclear from what the author wrote, that is
  itself a comment for the PR: add it as a review-level draft.
- **Local mode:** the commit messages, the branch name, and any ticket in
  either. If that leaves the goal unclear, ask the reviewer in one line before
  reading on: in local mode they are the one who asked for the work.

Skip, with one line each in the summary, files that are generated or checked
by CI: lock files, generated code, snapshots, compiled or minified assets,
translation catalogues, and whatever the repo notes or the repo's own docs
name as generated.

## 5. Review every file

Go through the files in diff order without stopping to check in. Don't list
findings in the chat as you go; they go into tuicr.

### Before reading the hunks

Load the rules that govern this file, from the checkout (the change may change
them):

- every `AGENTS.md` and `CLAUDE.md` from the repo root down to the file's
  directory, root first; the nearer one wins
- `README.md` and `CONTRIBUTING.md` files on that same path
- the skills or docs those point at for this kind of file (migrations, tests,
  frontend, security and so on), and any the repo notes name

Read the whole file as it is now, not only the hunks, and
`git show <base>:<path>` when you need what it replaced.

### The four checks, per hunk

**1. The repo's conventions.** Written: the rules loaded above. Unwritten: how
the surrounding code does the same thing — sibling functions in the file, the
same pattern in neighbouring modules, a helper the codebase already has that
the hunk reimplements. An unwritten convention needs a precedent: cite the
`path:line` that shows it. No precedent means it is a preference, and it is
dropped.

**2. Sound and necessary.** Does the logic hold: null and empty inputs, the
error path, boundaries and off-by-ones, the order things are processed in,
concurrent runs, what happens on the second run, plus whatever the repo notes
list for its domain. Then: does this hunk serve the goal from section 4? A hunk
that does not is scope creep, a leftover from an earlier approach, or an
unrelated fix that belongs in its own change — say which.

**3. Effects outside the diff.** A hunk can be correct in isolation and break
something the diff does not show. Look before claiming:

- callers of any function whose signature, return value or side effects changed
  — search the checkout for them
- overrides and extensions: subclasses, plugins, or anything else that hooks
  the changed code and now receives different arguments or a different result
- existing data: a new required field on existing rows, a changed or removed
  enum value, a rename with no migration, a default that only applies to new
  records
- consumers outside the repo when a public API, route, payload, config key or
  CLI flag changes

**4. Test coverage.** Is there a test in the change that would fail without
this hunk? Name it, or say none does. Do not run it.

### What not to report

- what the linters, formatters, type checkers and CI already fail on — CI tells
  the author
- anything you have not confirmed by reading the code; a suspicion that needs
  the reviewer to verify is a question, not a finding
- style preferences with no rule or precedent behind them

### How a comment reads

The comments go out under the reviewer's name, so they read the way the
reviewer types a quick comment to a teammate, not like a report:

- all lowercase, the first word included
- no punctuation but commas and periods: no question marks, colons, dashes,
  brackets, quotes or exclamation marks. A question is still a question, it
  just ends without the mark
- short, one or two sentences. Point at the spot and ask, rather than walking
  the author through the whole scenario: they know the code, and a question
  lets them find it
- ask rather than tell, with the hunch in a few words: can you check, what
  happens when, could we, why does this, i think
- code keeps its exact spelling and case inside backticks, like
  `order.address` or `None`. That is the only exception to the rules above

| Instead of | Write |
|---|---|
| `order.address` is empty for pickup orders, so this line raises. Could we guard it, or skip the shipping quote for those? | can you check what happens here for pickup orders, i think `order.address` is empty for those so this would raise |
| This duplicates the rounding in `round_price` (pricing.py:40); please reuse the helper. | could we use `round_price` here, the other totals in this file go through it |
| Nit: `q` is unclear — consider renaming it to `qty` to match the rest of the module. | maybe `qty` instead of `q`, the rest of the file uses that |
| There's no test covering the pickup case, which is the bug this PR fixes. | is there a test for the pickup case, i couldnt find one |

### Add each finding as a draft

As soon as a finding is settled, add it, so the reviewer can watch them arrive.
Only the comment goes in, one point each, written as above. The reasoning
behind it stays out.

```bash
tuicr review add --session <slug> --input - <<'JSON'
{"username": "Claude", "type": "issue", "file": "src/orders/checkout.py", "line": 212,
 "content": "can you check what happens here for pickup orders, i think `order.address` is empty for those so this would raise"}
JSON
```

- JSON on stdin under a quoted heredoc: comments hold backticks and quotes
  that a shell argument would mangle or run
- `username` is always `Claude`, so the reviewer can tell drafts from their own
- `type` says how much it matters, whatever the wording: `issue` for must fix,
  `suggestion` for should fix, `nit` for nit, and `question` when you don't
  know and nothing may be wrong
- line numbers are new-file lines (in local mode, the file as it is on disk),
  from the `+c,d` side of the hunk header. A range takes `start_line` and
  `end_line` instead of `line`; a removed line takes its old line number and
  `"side": "old"`
- a point about the change as a whole leaves out `file` and `line`
- a line comment must sit inside one of the diff's hunks: on a PR GitHub
  rejects anything else on submit, though tuicr stores it without complaint. A
  finding about code outside the hunks, such as a caller or an override, goes
  on the changed line it concerns, or on the file by leaving out `line`
- clean hunks get no draft

## 6. Hand over

The summary is a starting point for the reviewer's own reading, not a list of
your comments: those are in tuicr.

```
## #N <title>
@author · +A −D across F files · <ticket, if the PR names one>

### What it's for
The business problem in two or three sentences: who runs into it, what they see
today, and what changes for them with this change.

### How the author went about it
The approach and the main decision in it: where the behaviour changes, what
was left alone, and anything the code or PR shows they considered and dropped.

### Read these yourself
1. src/orders/checkout.py — the behaviour change itself; check that pickup
   orders skip the shipping quote rather than failing
2. tests/orders/test_checkout.py — whether the test proves the pickup case,
   not just the happy path
Skipped: package-lock.json (generated)

### In tuicr
5 drafts from Claude: 1 issue, 3 questions, 1 nit. Keep, rewrite (`i`) or
delete (`dd`) each one; whatever you `:submit` posts under your name.
```

In local mode the header is the branch instead, and the drafts go back to the
agent rather than to GitHub:

```
## <branch> — local, no PR yet
3 commits + uncommitted changes · +A −D across F files · <ticket, if any>
...
### In tuicr
5 drafts from Claude: 1 issue, 3 questions, 1 nit. Keep, rewrite (`i`) or
delete (`dd`) each one, then run `/address-review` in the agent that made the
change to work through what's left.
```

- "Read these yourself" holds the files that need human judgement, most
  important first, each with what to look for. Mechanical files are named
  once under "Skipped" or left out.
- If no tuicr review was open, add the findings after the summary instead, by
  severity, each with a `path:line` and the comment ready to paste:

  ```
  ### Must fix
  - src/orders/checkout.py:212 — "can you check what happens here for pickup
    orders, i think `order.address` is empty for those so this would raise"

  ### Should fix
  ### Nits
  ### On the change as a whole
  ```

## 7. Afterwards

The reviewer may push back on a draft in the chat. When they dismiss one,
delete it: find its `id` with `tuicr review comments --session <slug>`, and
delete only comments whose `author` is `Claude`. When they reword one, delete
it and add the new wording. What they write or edit in tuicr is already there;
read it with `tuicr review comments` rather than asking them to repeat it.
