---
name: worktree-flow
description: Git worktrees the way they stay readable — a sibling directory named `<repo>-<branch-slug>`, so the folder name alone tells you which feature lives inside. Covers creating one off the right base with local untracked files carried over, listing and finding existing ones, and removing them behind a safety ladder (uncommitted work, unpushed commits, stashes, an open PR/MR, actually merged into the base — squash merges included). Load whenever a task needs an isolated workspace, or the user says worktree, wtne, "заведи ворктри", "снеси ворктри", "где мои ворктри". Stack- and OS-agnostic; plain git, no aliases required.
---

# Worktree flow

One branch, one directory, one name you can read. `myapp` checked out at `~/projects/myapp` gets its feature work at `~/projects/myapp-cards-bulk-delete` — a sibling, not a child, so the editor's recent-projects list and `cd ~/pro<tab>` both stay useful.

Everything below is plain git. It works whether or not the user has aliases for it, and whether the shell is bash, zsh, fish or PowerShell.

## 0. Are you already in a worktree? — run this first, always

```sh
git rev-parse --is-inside-work-tree      # must print true
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
git rev-parse --show-superproject-working-tree   # non-empty → submodule, not a worktree
```

- `GIT_DIR` ≠ `GIT_COMMON` **and** the superproject check printed nothing → **you are already in a linked worktree. Do not create another one.** Report the path and branch and get on with the task. A worktree that already exists was set up deliberately; nesting a second one inside it is how you end up with `myapp-cards/myapp-cards-fix`.
- `GIT_DIR` = `GIT_COMMON`, or you're in a submodule → normal checkout, creating one is on the table.

Eyeballing the path does not settle this. Harness-created workspaces and submodules both look like ordinary checkouts. Run the commands.

## 1. Naming

```sh
main_root=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
repo=$(basename "$main_root")
parent=$(dirname "$main_root")
```

Deriving `repo` from the **main** worktree, not from `--show-toplevel`, is what keeps names stable when this runs from inside another worktree.

Branch → slug:

1. Strip a leading workflow prefix: `feat/` `feature/` `fix/` `bugfix/` `hotfix/` `chore/` `refactor/` `release/` `docs/` `test/` `perf/` `ci/`, and a `users/<name>/` style prefix.
2. Remaining `/` → `-`.
3. Replace only what the filesystem or the shell can't take — whitespace and `< > : " \ | ? * ~ ^ [` — with `-`; collapse runs of `-`; trim leading and trailing `-`. **Letters stay, whatever the alphabet.** All three OSes handle UTF-8 directory names; stripping non-Latin letters instead turns `feature/фича` into an empty slug.
4. Keep the case as it is. `TSK-12345` reads better than `tsk-12345`.
5. Slug still empty after all that → don't invent a name. Report the branch name and ask.

| Branch | Directory |
| --- | --- |
| `cards-bulk-delete` | `myapp-cards-bulk-delete` |
| `feat/TSK-12345-cards` | `myapp-TSK-12345-cards` |
| `release/2025/q2` | `myapp-2025-q2` |
| `users/dg/spike-wasm` | `myapp-spike-wasm` |
| `fix/weird:name*here` | `myapp-weird-name-here` |

Destination: `$parent/$repo-$slug`. Already taken → append `-2`, `-3`, … and say so. **Never write into an existing directory** — that is how someone's unpushed work disappears.

## 2. Create

```sh
git fetch origin <base-short> --quiet
git worktree add "$dest" -b "<branch>" "origin/<base-short>"
```

**Base branch**, first hit wins: what the user asked for → `origin/dev` or `origin/develop` if either exists → `origin/HEAD` (`git symbolic-ref --short refs/remotes/origin/HEAD`) → first of `origin/main`, `origin/master` → ask.

A repo with a long-lived `dev` branches features off it even when `origin/HEAD` points at `main`, which is why `dev` gets checked first.

The branch already exists → drop `-b` and check it out (`git worktree add "$dest" "<branch>"`). It's already checked out somewhere else → that's a worktree that exists; go use it instead of forcing a second one.

### Carry over the local files git doesn't track

A fresh worktree has no `.env`, no `*.local.*`, no local certificates — and a project that needs them just fails on first run for reasons that look like a code problem.

```sh
git -C "$main_root" ls-files -o --exclude-standard                    # untracked, not ignored
git -C "$main_root" ls-files -o -i --exclude-standard --directory     # ignored
```

Copy those paths into the new worktree, preserving directory structure, **skipping the heavy generated stuff**:

```
node_modules  bower_components  vendor  .pnpm-store
dist  build  out  target  bin  obj  .output
.next  .nuxt  .svelte-kit  .astro  .turbo  .parcel-cache  .cache  .vite
coverage  .nyc_output  .pytest_cache  __pycache__  .mypy_cache  .ruff_cache
.venv  venv  env  .tox  .gradle  .m2  Pods  .terraform  .idea  .vs
```

Treat that list as a starting point, not a closed set — anything the project can regenerate belongs on it. Copy with `cp -a` where available, `Copy-Item -Recurse` on PowerShell-only systems. Report a one-line count of what was carried over.

### Then set the project up

Install from whatever lockfile is actually present (`pnpm-lock.yaml` → `pnpm i`, `package-lock.json` → `npm ci`, `yarn.lock` → `yarn`, `Cargo.toml` → `cargo build`, `go.mod` → `go mod download`, `poetry.lock` → `poetry install`, `uv.lock` → `uv sync`, `requirements.txt` → `pip install -r`, `*.sln` → `dotnet restore`, `Gemfile.lock` → `bundle install`, CMake → configure). Nothing recognised → skip it, don't improvise a build.

Finish by printing the `cd` command to the new directory on its own line, so it's one copy away.

## 3. Find

```sh
git worktree list --porcelain
```

Parse it into a table: directory · branch · state. For each worktree, state comes from:

```sh
git -C "$d" status --porcelain -uall | wc -l          # dirty file count
git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null # unpushed
git -C "$d" rev-list --count 'HEAD..@{u}' 2>/dev/null # behind
```

Match a user's request against the branch name, the task id inside it, and the directory name — any substring, case-insensitively. `prunable` in the porcelain output means the directory is gone and only the registration is left: `git worktree prune` clears those, and it is the one worktree operation that's safe unprompted.

## 4. Remove — the safety ladder

Each rung can stop the removal. Run them in order and report which one stopped you; don't collapse them into one "looks fine".

1. **Uncommitted or untracked work** — `git -C "$d" status --porcelain -uall`. Non-empty → stop, show the list. These files exist nowhere else.
2. **Stashes** — `git -C "$d" stash list`. Non-empty → stop. Stashes are easy to forget and easy to lose.
3. **Unpushed commits** — `git -C "$d" rev-list --count '@{u}..HEAD'` > 0 → stop. No upstream at all (`git -C "$d" rev-parse --abbrev-ref '@{u}'` fails) and commits ahead of the base → also stop: nothing has left this machine.
4. **An open PR/MR** — `gh pr list --head "<branch>" --state open` / `glab mr list --source-branch "<branch>" --state opened`. Open → stop. Review feedback gets fixed in that worktree.
5. **Actually merged into the base** — three checks, strongest first:
   - The forge says so: a **merged** PR/MR for this branch. Authoritative, and the only thing that reliably proves a squash merge.
   - `git merge-base --is-ancestor "<branch>" "origin/<base>"` → true means a real merge or fast-forward landed it.
   - Squash heuristic, when neither of the above is available: the files the branch touched are byte-identical in the base.
     ```sh
     mb=$(git merge-base "origin/<base>" "<branch>")
     git diff --name-only -z "$mb" "<branch>" \
       | xargs -0 git diff --quiet "origin/<base>" "<branch>" --   # exit 0 → content already in base
     ```
     Use the `-z | xargs -0` form, not an unquoted `$(git diff --name-only …)` — a filename with a space in it otherwise turns the check into nonsense that still exits 0.
     Say out loud that this is a heuristic. It reads as merged for a branch whose work someone else reimplemented identically, and that is a real (if rare) way to lose work.

   Nothing confirms the merge → the branch is unmerged. Say so and ask before going further.

Only with the ladder clear:

```sh
cd "$main_root"                  # you cannot remove the worktree you are standing in
git worktree remove "$d"
git worktree prune
git branch -d "<branch>"         # -d, never -D
```

`git branch -d` refuses on a squash-merged branch because git can't see the merge. **`-D` is allowed only when the forge confirmed the merge** — say that's why you're using it. Any other refusal is information, not an obstacle to route around.

`git worktree remove` refusing with *contains modified or untracked files* means rung 1 or 2 was skipped or something appeared since. Go back and look. **Never `--force` on your own initiative** — it deletes files that exist nowhere else, permanently.

### Bulk cleanup

"Remove everything that's merged" is a reasonable ask. Run the full ladder per worktree, print the verdict table, and remove only the rows that came out clean — then show what was left behind and why. One shared confirmation for the whole list is fine; a blanket force-remove loop is not.

## 5. Quick reference

| Situation | Action |
| --- | --- |
| `GIT_DIR` ≠ `GIT_COMMON`, not a submodule | Already isolated — work here, create nothing |
| Branch has a workflow prefix | Strip it for the directory name, keep it on the branch |
| Directory name already taken | Suffix `-2`, `-3`; never reuse |
| Branch already checked out elsewhere | Use that worktree |
| No lockfile recognised | Skip install, don't improvise |
| `prunable` entry in `worktree list` | `git worktree prune` — safe unprompted |
| Dirty tree / stash / unpushed / open PR | Stop, report which rung |
| Merge confirmed only by the file heuristic | Say it's a heuristic, ask before deleting the branch |
| `worktree remove` refuses | Re-run the ladder; never `--force` yourself |
| Squash-merged, forge confirmed | `-D` is fine — state that's why |

## What NOT to do

- ❌ Don't create a worktree from inside a worktree.
- ❌ Don't `--force` anything — not `worktree remove --force`, not `branch -D` without a confirmed merge, not `push --force`.
- ❌ Don't `rm -rf` a worktree directory. `git worktree remove` exists so the registration goes with it.
- ❌ Don't touch worktrees you weren't asked about, however stale they look. Somebody put them there.
- ❌ Don't copy the heavy generated directories across — that's minutes of I/O to reproduce something a lockfile reproduces better.
- ❌ Don't assume the base is `main`. Check.
