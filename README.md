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
| [How it works](docs/how-it-works.md)      | Know what the checks do, how a PR title becomes a version, and how the changelog is written                    |
| [Maintaining dry-ci](docs/maintaining.md) | Change dry-ci itself: layout, local runs, tests and releasing a new version                                    |

## In a package, in short

Pull request titles are [Conventional Commits](https://www.conventionalcommits.org), and they
decide the release:

| Title                                   | Release |
| --------------------------------------- | ------- |
| `feat(admin)!: drop the legacy sidebar` | major   |
| `feat(orm): add record subpages`        | minor   |
| `fix: keep 2FA trust on logout`         | patch   |

Merge with a **merge commit**. The release follows on its own.

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
