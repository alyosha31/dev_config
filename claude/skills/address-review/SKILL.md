---
name: address-review
description: Work through the review comments left in tuicr on this checkout's changes — drafts from a review agent's /review-pr and the reviewer's own — fixing each in the code or explaining why not, then report what happened to every comment. Use when asked to address, apply, fix or go through review comments, or to pick up a review from tuicr.
---

# Address review comments from tuicr

The reviewer, and usually a review agent running `/review-pr`, left comments on
this checkout's changes in tuicr. Read them all, fix what should be fixed, and
report back on each one. The comments stay in tuicr: they are the reviewer's to
check against your fixes and then delete or post.

Never add, edit or delete tuicr comments, and never `:submit`. Don't commit or
push unless asked: leave the fixes in the working tree, where the reviewer sees
them in tuicr and in `git diff`.

## 1. Find the review

If the argument is a tuicr slug or a PR number, use that. Otherwise look in
both places tuicr keeps reviews.

Local reviews are listed under the checkout:

```bash
tuicr review list
```

PR reviews are listed under the repo the PR is opened against, which in a fork
is the parent:

```bash
gh repo view --json nameWithOwner,parent \
  --jq 'if .parent then "\(.parent.owner.login)/\(.parent.name)" else .nameWithOwner end'
tuicr review list --repo <repo>
```

Pick the review with comments that belongs to this checkout:

- a local review whose `anchor` is the current branch
  (`git branch --show-current`). Its slug names the commits it covered, so
  after a new commit the review you want may be an older row: take the newest
  one with `comment_count` above 0
- a PR review `gh:<repo>/pr/N` for the PR of this branch
  (`gh pr list --repo <repo> --head <branch>`). If that PR's author is not the
  reviewer (`gh api user --jq .login`), its comments are for someone else to
  address: stop and say so

If more than one fits, or none does, list what you found and ask.

## 2. Read the comments

```bash
tuicr review comments --session <slug>
```

Each comment has:

- `path`, `start_line`, `end_line`: where it points. No `path` means it is
  about the change as a whole
- `side`: `new` is the line in the changed file; `old` is a line the change
  removed
- `comment_type`: `issue` must be fixed, `suggestion` should be, `nit` is
  optional, `question` wants an answer, `praise` needs nothing
- `author`: `Claude` is the review agent's draft; anything else is the
  reviewer's own
- `content`: the comment

Line numbers are where the code was when the comment was written. If the file
has changed since, find the spot by what the comment describes, not by the
number.

The reviewer saw the drafts before you did. A draft still there is one they
kept; one they deleted is gone, and one they reworded says what they want now.
Their own comments carry the most weight.

## 3. Work through them

Go issues first, then suggestions, questions and nits; skip praise.

- Check the claim against the code before changing anything. A comment can be
  wrong: one that doesn't hold gets an explanation, not a change.
- When it holds, fix it the way the comment suggests, or a better way if there
  is one, and say which.
- Answer a question from the code. If the answer shows a problem, fix that too.
- Follow the repo's conventions as for any other change: the `AGENTS.md`,
  `CLAUDE.md` and docs on the path of each file you touch.
- When a comment asks for something large or ambiguous, such as a redesign or a
  choice between approaches, ask about it and carry on with the rest.
- When done, run the tests that cover what you changed, if the repo's workflow
  lets you run them here.

## 4. Report

One entry per comment, grouped by outcome, each with where it points, its type,
the gist of the comment, and what you did:

```
### Fixed
- src/orders/checkout.py:212 [issue] empty address on pickup orders →
  skipped the shipping quote for pickup orders, with a test for it
- review [suggestion] add a test for `b()` → added test_b_returns_three

### Not changed
- src/orders/checkout.py:240 [nit] rename `qty` → kept: every caller and the
  API payload use `qty`

### Answered
- src/orders/models.py:1 [question] what uses `x`? → the export job in
  jobs/export.py:58

### Needs you
- src/orders/pricing.py:30 [suggestion] move rounding into the model → a
  bigger change than this fix; want it here or separately?
```

End with what changed on disk (`git diff --stat`) and the tests you ran. The
reviewer can reopen the same tuicr review to check each fix against its
comment.
