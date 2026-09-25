# Forge and tracker commands

Lookups for `pr-description`. Every command is read-only unless it sits under **Write**, and every write runs only after the user's explicit yes (SKILL.md §11).

## Open PR for the current branch

| Forge | Base branch and body |
| --- | --- |
| GitHub | `gh pr view --json number,baseRefName,title,body` |
| GitLab | `glab mr list --source-branch "$branch" -F json` → `iid`, `target_branch`, `title`, `description` |
| Gitea / Forgejo | `tea pulls list --output json` → match `head` against the branch |
| Bitbucket / unknown | no CLI → skip; rely on git |

No open PR → the command fails or returns nothing; that is not an error, move on.

## Task in the tracker

| Where the task lives | Read it with |
| --- | --- |
| GitHub issue (`#123`, `123-fix-…`) | `gh issue view 123 --json title,body` |
| GitLab issue | `glab issue view 123` |
| Jira | a Jira MCP server if the session has one, else `jira issue view TSK-123 --plain` (jira-cli) |
| Anything else | whatever MCP server or CLI the session has for it; none → skip |

## Write

| Forge | Update body | Open PR |
| --- | --- | --- |
| GitHub | `gh pr edit <n> --body-file -` (body on stdin) | `gh pr create --base <base> --title "<title>" --body-file -` |
| GitLab | `glab mr update <iid> --description "$body"` | `glab mr create --target-branch <base> --title "<title>" --description "$body"` |
| Gitea / Forgejo | no body edit in `tea` → chat only | `tea pulls create --base <base> --title "<title>" --description "$body"` |
| Bitbucket / unknown | chat only | chat only |

Replacing between markers: take the current body from the lookup above, swap the text between `<!-- pr-description:start -->` and `<!-- pr-description:end -->` in memory, and pass the whole result — the author's text around the block goes back unchanged.

## Clipboard

| Platform | Command |
| --- | --- |
| Windows (git-bash) | `clip` |
| Windows (PowerShell) | `Set-Clipboard` |
| macOS | `pbcopy` |
| Linux / Wayland | `wl-copy` |
| Linux / X11 | `xclip -selection clipboard` |
