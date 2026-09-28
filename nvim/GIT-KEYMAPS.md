# Git keymaps

Leader is `<Space>`. Everything git-related hangs off `<leader>g`.
`<leader>g?` reopens this file. `g?` inside diffview or fugitive shows that
buffer's own help.

## Entry points — from any buffer

| Key | Does |
| --- | --- |
| `<leader>gg` | Fugitive status — stage, commit, stash |
| `<leader>gL` | Log graph (`git log --graph`) |
| `<leader>gd` | Diffview: working tree vs index |
| `<leader>gl` | Diffview: repo commit log — the tree you browse |
| `<leader>gh` | Diffview: history of this file (visual: of the selected lines) |
| `<leader>gm` | Diffview: this whole branch vs the branch it was cut from |
| `<leader>gc` | Diffview: one commit, by hash/tag/`HEAD~2` (prompts) |
| `<leader>gq` | Close the diffview — panel and every split, in one go |
| `<leader>gD` | Fugitive: split-diff this file against a revision (prompts) |
| `<leader>gE` | Fugitive: open this file as it was at a revision (prompts) |
| `<leader>gB` | Point gitsigns at another revision (prompts, empty = reset) |
| `<leader>g?` | This file |

## Hunks in an ordinary buffer — gitsigns

These are the ones to lean on day to day; they work in the real file, so LSP
and treesitter are intact.

| Key | Does |
| --- | --- |
| `]h` / `[h` | Next / previous hunk |
| `<leader>gi` | **Inline diff in the file** — changed lines green, removed lines back in place in red. Toggles |
| `<leader>gp` | Preview the hunk in a float |
| `<leader>gP` | Preview one hunk inline, without turning the whole mode on |
| `<leader>gs` | Stage the hunk — in visual mode, only the selected lines |
| `<leader>gr` | Reset the hunk — in visual mode, only the selected lines |
| `<leader>gS` | Stage the whole file |
| `<leader>gu` | Undo the last stage |
| `<leader>gb` | Full blame for this line, in a float — sha and PR number are clickable |
| `<leader>go` | Open the commit that touched this line in Diffview |
| `<leader>gO` | Open that commit's PR on GitHub — the commit page if it had none |
| `<leader>gA` | Blame the whole file in a side window |
| `<leader>gt` | Toggle inline blame on every line |
| `<leader>gw` | Toggle word-level diff highlighting |
| `<leader>gQ` | Every hunk in the repo into the quickfix list |
| `dih` `yah` `vih` | Hunk as a text object |

`<leader>gB` is the review mode: give it a revision (it pre-fills your branch
base) and the diff against it shows as signs across your real files. `]h`,
`<leader>gp` and `<leader>gQ` then walk a whole branch's changes without ever
opening a diff split. Empty input resets to the index.

`<leader>gi` draws that diff in the buffer instead of the gutter: line
backgrounds for what changed, brighter word-level highlights inside them, and
the removed lines put back as red virtual lines where they used to be. With no
base set it compares against `HEAD~1`; with one set by `<leader>gB` it follows
that instead, and toggling off restores whatever base you had. It's a real
buffer the whole time, so `gd`, `gr` and folds keep working.

## Blame

`<leader>gb` floats the full commit for the line: sha, PR number, author, the
message and the hunk it came from. Press it again to step into the float,
`q` to close it. With `gh` installed the sha and the `#1234` are real
hyperlinks — cmd+click opens them in the browser.

From the line itself, without the float: `<leader>go` opens that commit in
Diffview, `<leader>gO` opens its PR on GitHub. Both blame the buffer as it is
now, so unsaved edits don't throw the line off, and on any line that already
shows a hash — fugitive's log or blame, diffview's log panel — they act on
that hash instead.

`q` closes what `<leader>go` opens — from the panel or either diff window, the
whole tab at once. `<leader>gq` does the same from anywhere else.

`<leader>gA` blames the whole file in a window scrollbound to it:

| Key | Does |
| --- | --- |
| `<CR>` | Menu of everything below |
| `s` / `S` / `e` | Show the commit under the cursor — vsplit / tab / this window |
| `r` / `R` | Reblame from that commit / from its parent — walk back through rewrites |
| `d` | Diff that commit in a new tab |
| `q` | Close |

## Diffview — file panel (left)

| Key | Does |
| --- | --- |
| `j` `k` | Move between entries |
| `<cr>` `o` `l` `2×click` | Open the diff for this entry |
| `<tab>` / `<s-tab>` | Next / previous file |
| `[F` / `]F` | First / last file |
| `h` `zc` / `zo` `za` | Collapse / open a folder; `zR` `zM` for all |
| `i` | Toggle tree ↔ flat list |
| `f` | Flatten empty directories |
| `-` `s` | Stage / unstage this entry |
| `S` / `U` | Stage all / unstage all |
| `X` | Restore the file to the left side's state |
| `L` | Commit message for this entry |
| `gf` | Jump to the real file on disk |
| `gF` | Same, and point gitsigns at this diff's base |
| `<C-w><C-f>` / `<C-w>gf` | Real file in a split / new tab |
| `<C-r>` | Refresh entries |
| `<leader>b` | Hide/show this panel |
| `<C-b>` / `<C-f>` | Scroll the panel |
| `q` | Close the whole diffview |
| `g?` | Help |

## Diffview — inside a diff

| Key | Does |
| --- | --- |
| `]c` / `[c` | Next / previous hunk |
| `]h` / `[h` | Same, kept centred |
| `zM` | Collapse to hunks only |
| `zR` / `zi` | Back to the whole file / toggle folds |
| `<tab>` / `<s-tab>` | Next / previous file |
| `gf` | The real file, same line — where `gd` and `gr` work |
| `gF` | The real file, and gitsigns keeps showing these same hunks |
| `<leader>b` | Toggle the file panel |
| `g<C-x>` | Cycle layout (side-by-side ↔ stacked) |
| `q` | Close everything |
| `g?` | Help |

Folds are open by default so each hunk sits in its whole file. `zM` gets you
the compact hunks-only view back.

In a **working tree** diff (`<leader>gd`) the left window is the index and the
right one is the real file, and both are editable — so native diff-mode
`do`/`dp` work: `do` on a hunk in the right window drops it back to the index
version, `dp` pushes it into the index. Write the buffer (`<leader>w`) to make
it stick. In commit and history views both sides are read-only git blobs — no
LSP, no editing; that's what `gf` and `gF` are for.

## Diffview — commit log panel (bottom)

| Key | Does |
| --- | --- |
| `j` `k` | Move between commits |
| `za` `zo` / `zc` | Fold a commit open to see the files it touched |
| `zR` / `zM` | Expand / collapse every commit |
| `<cr>` `o` | Open the diff |
| `D` | Open this commit as its own file tree |
| `y` | Copy the hash |
| `L` | Full commit message |
| `X` | Restore the file to this commit's version |
| `g!` | Options panel — filter the log by author, `-G`, path, range |
| `<tab>` / `<s-tab>` | Next / previous file within the commit |
| `gf` / `gF` | Real file / real file with this base |
| `q` | Close |
| `g?` | Help |

## Fugitive status (`<leader>gg`)

| Key | Does |
| --- | --- |
| `s` / `u` / `-` | Stage / unstage / toggle the file or hunk under the cursor |
| `U` | Unstage everything |
| `X` | Discard the change under the cursor (echoes an undo command) |
| `=` | Toggle an inline diff of the file under the cursor |
| `I` | Interactive `add --patch` on that file |
| `dd` / `dv` / `ds` | Open it in a diff split (auto / vertical / horizontal) |
| `dq` | Close all the diff splits |
| `cc` | Commit |
| `ca` / `ce` | Amend with / without editing the message |
| `cw` | Reword the last commit |
| `cf` / `cs` | `fixup!` / `squash!` for the commit under the cursor |
| `crc` | Revert the commit under the cursor |
| `coo` | Check out the commit under the cursor |
| `czz` / `czw` | Stash / stash the work tree |
| `gI` | Add the file under the cursor to `.git/info/exclude` |
| `<cr>` | Open the file or object under the cursor |
| `gD` | Open the commit under the cursor in Diffview |
| `gq` | Close the status buffer |
| `g?` | Fugitive's own help |

`gD` works on any fugitive line carrying a hash — status, `<leader>gL`'s graph,
blame — so the graph is a browsable index into Diffview.

## Recipes

**Review a branch or a PR.** `<leader>gm` → the tree lists everything the
branch touched → `<cr>` on a file → `]h` through the hunks in full context →
`<tab>` to the next file → `q` when done.

**Understand one commit properly.** `<leader>gl` → `za` on the commit to see
its files → `<cr>` → `gF` on anything you want to chase → you're in the real
file with the same hunks marked, so `gd`, `gr`, `K` all work → `<leader>gB`,
empty, to reset when you're done.

**Read your own work before committing.** `<leader>gd`, walk it with `<tab>`
and `]h`, stage from the panel with `-`, then `<leader>gg` and `cc`.

**Commit part of a change.** Visual-select the lines and `<leader>gs`. Or
`<leader>gg` then `I` for `git add -p`.

**Why is this line here.** `<leader>gb` for the commit that touched it →
`<leader>go` to read that commit in full → `<leader>gO` when the commit
message isn't enough and you want the PR discussion. `<leader>gA` when the
first commit is a rename or a reformat: `R` there reblames past it. Or
`<leader>gh` for the file's whole history — visual-select first to follow just
those lines.

**Drop one hunk.** `<leader>gr` in the buffer, or `X` on an entry in the
diffview panel to throw away the whole file's changes.
