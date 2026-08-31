import re


CODE_EXTENSION = (
    r"py|pyi|js|jsx|ts|tsx|mjs|cjs|c|h|cc|cpp|cxx|hh|hpp|go|rs|java|"
    r"kt|kts|swift|rb|php|cs|lua|sh|bash|zsh|fish|vim|sql|html|htm|"
    r"css|scss|sass|less|vue|svelte|md|markdown|txt|json|jsonc|yaml|"
    r"yml|toml|xml|ini|cfg|conf|proto|graphql|gql|ex|exs|erl|hrl|"
    r"clj|cljs|scala|dart|r|hs|zig|sol|tf|hcl"
)

REFERENCE = re.compile(
    rf"(?P<path>[A-Za-z0-9_./-]+\.(?:{CODE_EXTENSION}))(?![A-Za-z0-9_])"
    r"(?:(?::|\s+around\s+line\s+)(?P<line>[0-9]+)(?:-[0-9]+)?)?"
)


def mark(text, args, Mark, extra_cli_args, *unused):
    """Mark bare paths, path:line ranges, and prose-style line references."""
    for index, match in enumerate(REFERENCE.finditer(text)):
        start, end = match.span()
        matched_text = text[start:end].replace("\n", "").replace("\0", "")
        yield Mark(
            index,
            start,
            end,
            matched_text,
            {
                "path": match.group("path"),
                "line": match.group("line") or "1",
            },
        )


def handle_result(args, data, target_window_id, boss, extra_cli_args, *unused):
    """Open every selected reference in a fresh Kitty tab."""
    source_window = boss.window_id_map.get(target_window_id)
    if source_window is None:
        return

    for selected, reference in zip(data["match"], data["groupdicts"]):
        if not selected:
            continue
        boss.call_remote_control(
            source_window,
            (
                "launch",
                "--type=tab",
                "--cwd=current",
                "/Users/mg/dev_config/bin/kitty-code-open",
                f"path={reference['path']}",
                f"line={reference['line']}",
            ),
        )
