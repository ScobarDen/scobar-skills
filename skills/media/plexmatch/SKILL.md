---
name: plexmatch
description: Make Plex match a folder of TV series or movies exactly — writes `.plexmatch` hint files for series (title, year, `tvdbid`, `pattern:` / `ep:` lines for filenames Plex cannot parse, specials into Season 0) and renames movie folders to `Title (Year) {tmdb-ID}`, since `.plexmatch` is a series-only feature. Every ID is confirmed by the user before anything is written, every rename is planned and approved first and comes with undo commands. Load when the user attaches a media folder and asks to fix Plex matching, posters or episode order, or says plexmatch, «Plex криво матчит», «разметь для Plex».
---

# plexmatch

Plex matches by folder and file names. When those are release junk (`Show.S01.1080p-GROUP`, `[SubsPlease] Show - 05.mkv`, `Начало.2010.BDRip`), it guesses and guesses wrong. This skill pins every title to a database ID so the guess never happens:

- **Series** get a `.plexmatch` file. Nothing is renamed.
- **Movies** get their folder renamed to `Title (Year) {tmdb-ID}`. Plex documents `.plexmatch` for TV series only; for movies the official hook is the ID in the folder name.

The scope is these two moves. Plex's API, file renames inside a folder, editions (`{edition-…}`), multi-part movies and collections stay out; mention one in the report if you see it, and leave it alone.

Sources: [Match Hinting for TV Series](https://support.plex.tv/articles/plexmatch/), [Naming and organizing your Movie files](https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/).

## 1. Read the folder

List the attached folder recursively and classify each item:

- **Series**: an `SxxEyy` / `1x05` / episode-number filename, or `Season N` / `S01` / `Specials` subfolders.
- **Movie**: a single main video (plus subtitles, audio tracks, samples, posters), or a loose video file in a movies root.
- **Level**: the attached folder is one title, one season of a title, or a library root holding many titles. A library root is processed title by title.

A root that mixes series and movies: tell the user Plex wants them in separate libraries, then carry on per title.

Skip, and list in the report: titles whose movie folder already carries `{tmdb-…}` / `{imdb-…}`, plus extras, trailers, featurettes, samples.

Done when every title in the folder sits in exactly one bucket: series, movie, or skipped.

## 2. Find the IDs

Search the web for each title: TheTVDB for series (`tvdbid`), TMDB for movies (`tmdbid`). Use the year, episode count and season count from the folder to tell remakes and namesakes apart.

Show one table and wait for the user's answer:

| # | Folder | Type | Matched title (year) | ID | Link |
|---|---|---|---|---|---|

Low-confidence rows (a remake, several titles with the same name, no year in the folder) go on top with ⚠️. The user corrects by row number; re-search those rows and show the table again.

Done when the user has approved every row.

## 3. Series: write `.plexmatch`

One `.plexmatch` in the series root:

```
title: Cool Show
year: 2018
tvdbid: 123456
```

`title` and `year` are there for the human reading the file; the ID is what Plex matches on, and it overrides both.

**Episodes.** Filenames with a clean `SxxEyy` need no hint. For the rest:

- A uniform group of bad names gets one `pattern:` line (PMS 1.30+): `{ep}` episode, `{s}` season (inferred from the folder when absent), `{sp}` special, `{see}` combined season+episode like `214`, `*` wildcard, `/` path separator. Parameters after a comma: a range `1-3`, an offset `+4` / `-2`, a max length `l2`. The first matching pattern wins, so put narrow patterns first.
  ```
  pattern: Season 1/[SubsPlease] Cool Show - {ep}*.mkv
  ```
- One-off files that no pattern catches get an `ep:` line, number first and the colon right after it: `ep: 05: Season 1/Some Weird Name.mkv`, `ep: S02E01-E02: Season 2/Double.mkv`.
- Specials and OVA go to Season 0: `{sp}` in a pattern, or `ep: SP01: Specials/OVA 1.mkv`.

Paths are relative to the series root and always use `/`, Windows included. A `.plexmatch` in a season folder only applies to files in that folder, so keep everything in the root one. The exception is a season attached on its own, with no series root: write `season: N` there too.

**Absolute numbering** (`Show - 1052.mkv`, anime): write the `tvdbid` and map the numbers as they are. Do not split them into seasons by hand. The report tells the user to set the show's *Episode ordering → TheTVDB (Absolute)* in Plex.

**An existing `.plexmatch`**: show the diff between it and the new content, and write only on the user's yes. They may have hand-edited it.

**Writing the file**: the name is exactly `.plexmatch`, with no `.txt`. UTF-8 without a BOM: a BOM glues onto the first hint name and Plex drops that line. In PowerShell 5, use `[IO.File]::WriteAllText($path, $text)`, not `Set-Content` / `Out-File`, which add a BOM.

Done when every series has a `.plexmatch` and every video file Plex cannot parse on its own is covered by a `pattern:` or `ep:` line.

## 4. Movies: rename the folder

The target name is `Title (Year) {tmdb-ID}`:

- `Title` stays in the language of the original folder name (`Начало`, not `Inception`). Plex pulls the display title from the ID anyway.
- Strip release junk: resolution, source, codec, group, dots used as spaces.
- Drop `\ / : * ? " < > |`, which Windows rejects in names.
- The files inside keep their names. One rename per movie, and subtitles stay paired with their video.
- A loose movie file gets a new folder with that name. Move the file in, along with the files that share its base name (`Movie.rus.srt`, `Movie.ac3`).

Show the plan before touching anything:

| # | Was | Will be |
|---|---|---|

Under the table, one line: renaming a folder breaks any torrent still seeding from it, so leave those rows out. Rename only after the user's yes, and only the rows they approved. For a row they reject, put the target name in the report so they can use it later.

Done when every approved row is renamed and nothing else on disk has changed.

## 5. Report

- `.plexmatch` files written, and the folders renamed.
- Undo commands for every change on disk, as a copy-paste block in the user's shell (`Move-Item -LiteralPath` on Windows, `mv` elsewhere): a renamed folder goes back to its old name; a loose file moves back out along with its companions, and the folder created for it is removed.
- What was skipped and why: already tagged, extras, rejected rows with their target names, editions or multi-part movies spotted.
- Next steps in Plex: *Refresh Metadata* on the library (or *Fix Match* on a stubborn title), *Episode ordering → TheTVDB (Absolute)* where absolute numbering was found, and PMS 1.30+ if any `pattern:` line was written.
