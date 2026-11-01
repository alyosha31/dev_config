---
name: walkthrough
description: Walk the user through how some code works — save the stops worth reading, in order, as a titled quickfix list they step through in Neovim (`:qflist`, then ]q and [q), and explain each numbered stop in the chat. Use when asked to walk through, explain the flow of, give a tour of, or show how some code, feature or change works.
---

# Walk through code with a quickfix list

The user reads the code themselves in Neovim, one stop at a time. You choose
the stops, put them in the order that makes the code make sense, save them as a
quickfix list, and explain each one in the chat under the same number.

Read only: never edit the code you are walking through.

## 1. Work out the path

Read the code before choosing anything. Every stop is a line you have read in
this checkout, as it is now; never guess a line number.

- Start where the behaviour starts: the route, button, RPC method, CLI command,
  scheduled job or test that triggers it.
- Follow the main flow through the calls that matter, and stop at the decision
  points: the condition that picks a branch, the filter that drops records, the
  place where data changes shape.
- Include the edge case that explains the behaviour the user asked about, if
  there is one.
- Leave out plumbing: imports, getters, logging, glue they can skim past.
- Usually 5 to 15 stops. One stop is one line worth looking at: the `def` line,
  the condition, the call. Not the top of a long function when the point is
  forty lines down.

## 2. Save the list

The list goes in the checkout's own git folder, so it is never committed, each
worktree keeps its own, and removing the worktree removes them:

```bash
dir=$(git rev-parse --path-format=absolute --git-path qf) && mkdir -p "$dir" && echo "$dir"
```

Name it `<YYYY-MM-DD>-<topic-slug>.qf`. When the user asks about the same topic
again, overwrite that file rather than adding a near-duplicate. Write it with a
quoted heredoc:

```bash
cat > "<dir>/2026-11-02-checkout-discounts.qf" <<'QF'
# Checkout: how a discount code gets applied
/abs/path/src/api/checkout.py:42:5: 1. entry point, POST /checkout lands here
/abs/path/src/orders/pricing.py:118:9: 2. discounts go on before tax, note the order
/abs/path/src/orders/discounts.py:67:5: 3. why an expired code is skipped without an error
QF
```

- The first line is `# ` and the title: a few words naming the topic, the way
  the user would look for it later. It is what the picker shows.
- One stop per line: absolute path, line, column, then the note. Absolute paths
  load from any directory Neovim is in.
- The column is where the thing to look at starts on that line; 1 if the whole
  line is the point.
- The note is one line, under about 80 characters, numbered to match the chat.
  It says what to look at here; the explanation goes in the chat.

## 3. Explain it in the chat

```
## Checkout: how a discount code gets applied

Open it with `:qflist` (or `<leader>fq`) and pick this title, then `]q` and
`[q` to step through the 3 stops.

### 1. checkout.py:42 — entry point
Two to four sentences: what this code does, why it matters to the question,
and what to notice on this line.

### 2. pricing.py:118 — discounts go on before tax
Tie each stop to the ones before it: "the order from stop 1 is priced
here", "this is the total stop 2 computed".

### The flow in one paragraph
The whole path from the trigger to the outcome, now that they have seen each
piece.
```

- The numbers and short labels match the notes in the list, so the "(2 of 9)"
  Neovim shows tells them which section they are on.
- If they ask a follow-up about one stop, answer it by its number. If the answer
  needs stops the list doesn't have, save an updated list over the old one and
  say which numbers changed.
