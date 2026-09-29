# dry-ci

Shared CI and automatic releases for the dry packages: dry3, oak, dry-ecommerce, dry-mollie,
dry-dbi and the rest.

Every package that uses dry-ci:

- **runs the same checks** on each pull request: Composer, Prettier, PHPStan and Pest;
- **releases itself** when a pull request is merged: the next semantic version is computed from
  the pull request titles, tagged and pushed, with no manual step and no beta tags;
- **keeps a `CHANGELOG.md`**, one entry per merged pull request, written by the release.

The logic lives in this repository once. A package only carries a small caller file, pinned to
a dry-ci version, and works the same whether it is hosted on GitHub or Bitbucket.

## Documentation

| Read this                                 | When you want to                                                                                               |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [Setting up a package](docs/setup.md)     | Switch a package to dry-ci: settings, secrets and the pull request, step by step, with a checklist per package |
| [Setting up a project](docs/projects.md)  | Run the checks in a project (a site), without releases                                                         |
| [How it works](docs/how-it-works.md)      | Know what the checks do, how a PR title becomes a version, and how the changelog is written                    |
| [Maintaining dry-ci](docs/maintaining.md) | Change dry-ci itself: layout, local runs, tests and releasing a new version                                    |

## In a package, in short

Pull request titles are [Conventional Commits](https://www.conventionalcommits.org), and they
decide the release (see the [cheatsheet](#pr-title-cheatsheet)). Merge with a **merge commit**.
The release follows on its own.

A GitHub package calls the reusable workflow ([example](examples/github-ci.yml)):

```yaml
jobs:
  dry-ci:
    uses: TallieuTallieu/dry-ci/.github/workflows/php-package.yml@v1
    permissions:
      contents: write
    secrets: inherit
```

A Bitbucket package copies [`bitbucket/bitbucket-pipelines.yml`](bitbucket/bitbucket-pipelines.yml),
which fetches the same scripts at `v1`. [Setting up a package](docs/setup.md) has every step.

A dry project (a site) isn't versioned: it copies
[`bitbucket/project-pipelines.yml`](bitbucket/project-pipelines.yml), which runs only the
checks, on pull requests. See [Setting up a project](docs/projects.md).

## PR title cheatsheet

`<type>(<optional scope>): <description> [<optional marker>]`. The scope is shown in bold in
the changelog.

The type picks the release and the changelog section:

| PR title                                              | Release | Changelog section               |
| ----------------------------------------------------- | ------- | ------------------------------- |
| `feat(admin)!: drop the legacy sidebar`               | major   | Breaking changes                |
| `fix(api)!: remove the v1 routes`                     | major   | Breaking changes                |
| `feat(orm): add record subpages`                      | minor   | Features                        |
| `fix: keep 2FA trust on logout`                       | patch   | Fixes                           |
| `perf(orm): cache the schema`                         | patch   | Fixes                           |
| `refactor`, `docs`, `test`, `ci`, `chore`, `revert`   | patch   | Other changes                   |
| `build:`, `style:`, `chore(build):`, `chore(format):` | patch   | left out ("No notable changes") |

A marker at the end of the title overrides the release. The section still comes from the type:

| PR title                                  | Release                          | Changelog section |
| ----------------------------------------- | -------------------------------- | ----------------- |
| `fix(api): reject an empty limit [major]` | major                            | Breaking changes  |
| `fix(api): accept a limit [minor]`        | minor                            | Fixes             |
| `feat(admin): add CSV export [patch]`     | patch                            | Features          |
| `docs: explain the setup [no release]`    | none; goes out with the next one | Other changes     |

- **The highest bump wins** among the pull requests merged since the last release. A marker
  only sets its own pull request's bump: `[patch]` next to a plain `feat:` still makes a minor
  release.
- **`[no release]`** holds a pull request back. Nothing is tagged; it is in the changelog of
  the next release and counts towards that release's bump. Every other merge releases.
- **One marker, at the end, in lower case.** `[major]` is the same as `!`; `!` with `[minor]`
  or `[patch]` is rejected.
- **`!` before the colon** means breaking. Only the title counts: a `BREAKING CHANGE:` footer
  in a branch commit is not read.
- **`sc-1234`** in the title (or, on Bitbucket, in the branch name) becomes a Shortcut link.

More in [How it works](docs/how-it-works.md#the-version-bump).

## Why this repository is public

It holds only generic scripts and configuration, never secrets. Being public lets GitHub
Actions and Bitbucket Pipelines both fetch it without credentials.

## Decisions

Made on 2026-09-28 in Shortcut epic 7219
([sc-11671](https://app.shortcut.com/tallieu--tallieu/story/11671)):

- **One engine on both hosts**: [git-cliff](https://git-cliff.org) plus the scripts in `bin/`.
  release-please only works on GitHub; semantic-release needs Node in every PHP package and
  cannot backfill a changelog.
- **Release on every merge** to the default branch, only after the checks pass. No pre-release
  (beta) tags and no long-lived `dev` branch.
- **Merge commits, not squash**: each merged pull request is one changelog entry, read from the
  PR title in its merge commit, and the default branch keeps the branch history. (This replaced
  an earlier squash-only plan.)
- **Tag format stays per package**: dry3 `vX.Y.Z`, the GitHub packages bare `X.Y.Z`. Composer
  treats both the same.
- **The release commits `CHANGELOG.md`** to the default branch; each package's history was
  backfilled once by hand.
- **PHP 8.4 only**; each package keeps its own PHPStan level.
