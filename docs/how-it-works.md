# How it works

What dry-ci does in a package once it is [set up](setup.md): the checks, how a merge becomes a
release, and how the changelog is written.

## On a pull request

- **PR title.** The title must be a [Conventional Commit](https://www.conventionalcommits.org)
  subject: `<type>(<optional scope>): <description>`, e.g. `feat(orm): add record subpages`.
  Types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`,
  `revert`. `bin/lint-pr-title` checks it. On GitHub the check re-runs when the title is
  edited.
- **Checks**, one `bin/check` subcommand each, identical on both hosts:

  | Check      | Runs                                          | Skipped when                        |
  | ---------- | --------------------------------------------- | ----------------------------------- |
  | `composer` | `composer validate`, then `composer install`  | never                               |
  | `prettier` | `yarn install`, `yarn prettier --check .`     | no `prettier` in `package.json`     |
  | `phpstan`  | PHPStan with the package's own `phpstan.neon` | no `phpstan.neon`                   |
  | `pest`     | Pest                                          | no `tests/` directory               |

  PHP 8.4, Node LTS. PHPStan's level and baseline stay per package. A skipped check shows a
  warning, not a failure.

## On a merge to the default branch

The same checks run. When they pass, `bin/release`:

1. finds the latest stable tag, `X.Y.Z` (or `vX.Y.Z` with `tag-prefix: v`). Pre-release tags
   such as `v4.1.0-beta.3` are ignored;
2. reads the pull requests merged since then and computes the next version;
3. prepends a section for it to `CHANGELOG.md`, with [git-cliff](https://git-cliff.org) and
   [`cliff.toml`](../cliff.toml);
4. commits `chore(release): X.Y.Z [skip ci]`, tags that commit, and pushes both. `[skip ci]`
   keeps the release commit from starting another run.

On GitHub it also creates a GitHub Release with the same notes. When there is nothing to
release, or the commit is already tagged, it stops without changing anything, so a re-run is
safe.

### The version bump

| PR titles merged since the last tag | Release |
| ----------------------------------- | ------- |
| any `type!:`, e.g. `feat(api)!:`     | major   |
| any `feat:`                          | minor   |
| anything else, conventional or not   | patch   |

The highest bump wins: one `feat:` among ten `fix:` titles makes a minor release.

- **Only the PR title counts.** A `BREAKING CHANGE:` footer in one of the branch's commits is
  not read. Put the `!` in the title.
- **A direct push** to the default branch (no pull request) still releases a patch, but gets no
  changelog entry.
- **Merges only.** Each pull request is read from its merge commit, which carries the PR title:
  Bitbucket writes `Merged in <branch> (pull request #N)` with the title below it, GitHub
  `Merge pull request #N from <branch>` with the title below it. Squash and rebase merges leave
  no merge commit, so they are turned off (see [setup](setup.md)).

## The changelog

Each release adds one section below the header of `CHANGELOG.md`:

```markdown
## 4.2.0 - 2026-09-28

### Breaking changes

- **orm:** Drop the legacy picker ([sc-1234](https://app.shortcut.com/tallieu--tallieu/story/1234))

### Features

- **media:** Redesign the media library and the picker

### Fixes

- **orm:** Grey a picker's taken rows out after a reload

### Other changes

- Update the gateway docs
```

- **One entry per merged pull request**, written from its title: the scope in bold, the first
  letter capitalised. Branch commits and "sync" merges (`Merge branch 'main' into …`) are left
  out.
- **Groups:** Breaking changes (any `!`), Features (`feat`), Fixes (`fix`, `perf`), Other changes
  (everything else, including non-conventional titles).
- **Shortcut stories** (`sc-1234`) become links. For a Bitbucket pull request, the story id in
  the branch name is added to the entry.
- **Bitbucket's default PR title** is the branch name ("Feature/sc 9788  dry3 restart …"); the
  `Feature/`, `sc 9788` and `dry3` parts are removed. A real title reads better, and the title
  check asks for one anyway.
- **Noise is left out**: release commits, `chore(build)`, `chore(format)`, `build:`, `style:`,
  and titles about rebuilt assets, Prettier or the PHPStan baseline. A release made only of such
  changes still happens (a patch with "No notable changes."), because rebuilt assets are a
  change consumers need.
- **Past entries may be edited by hand.** Releases only add new sections on top.

Each package's history before dry-ci was backfilled once, from its tags, and edited by hand
([sc-11672](https://app.shortcut.com/tallieu--tallieu/story/11672)).

## Tags and Composer

Composer reads versions from tags and ignores a leading `v`, so dry3's `v4.2.0` and a package's
`3.13.2` work the same way. Each package keeps the tag style it already had. A consumer on the
default `minimum-stability: stable` only ever sees the stable tags dry-ci creates.
