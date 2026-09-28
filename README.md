# dry-ci

Shared CI and automatic releases for the dry packages (dry3, oak, dry-ecommerce,
dry-mollie, …). Every package runs the same checks, releases itself when a pull
request is merged to its default branch, and keeps a `CHANGELOG.md`. The logic
lives here; each package only carries a thin caller.

This repository is public on purpose: it holds generic scripts and config and
never secrets, so both GitHub and Bitbucket can fetch it without credentials.

## What happens

On a pull request:

- The PR title must be a [Conventional Commit](https://www.conventionalcommits.org)
  subject (`bin/lint-pr-title`). With squash merges the title becomes the commit
  on main, so it decides the next version.
- `bin/check composer`, `prettier`, `phpstan` and `pest` run. PHPStan uses the
  package's own `phpstan.neon` (level and baseline); Pest is skipped when there
  is no `tests/` directory. PHP 8.4, Node LTS.

On a merge to the default branch, after the same checks pass, `bin/release`:

1. finds the latest stable tag (pre-release tags like `-beta.3` are ignored),
2. computes the next version from the commits since then,
3. prepends a section to `CHANGELOG.md` with [git-cliff](https://git-cliff.org),
4. commits `chore(release): X.Y.Z [skip ci]`, tags it, and pushes both.

On GitHub it also creates a GitHub Release with the same notes.

| Commits since the last tag                     | Release |
| ---------------------------------------------- | ------- |
| any `type!:` or a `BREAKING CHANGE:` footer    | major   |
| any `feat:`                                    | minor   |
| anything else, conventional or not             | patch   |

## Use it

### GitHub

Copy [`examples/github-ci.yml`](examples/github-ci.yml) to
`.github/workflows/ci.yml` and delete the old `ci.yml`/`release.yml`. Inputs of
[`php-package.yml`](.github/workflows/php-package.yml):

| Input            | Default  | Use                                           |
| ---------------- | -------- | --------------------------------------------- |
| `tag-prefix`     | `''`     | `v` for `vX.Y.Z` tags                         |
| `changelog-unit` | `commit` | `pr` for one entry per merged pull request    |
| `php-extensions` | `''`     | e.g. `imagick, gd`                            |
| `composer-args`  | `''`     | extra `composer install` arguments            |
| `pest-args`      | `''`     | extra Pest arguments                          |

Secrets (pass with `secrets: inherit`): `BITBUCKET_SSH_KEY` when the package
requires private dry3, and `RELEASE_TOKEN` when the default branch is protected
against pushes by `GITHUB_TOKEN`.

### Bitbucket

Copy [`bitbucket/bitbucket-pipelines.yml`](bitbucket/bitbucket-pipelines.yml)
to the package root, adjust the marked lines, and add the secured repository
variable `DRY_CI_BITBUCKET_TOKEN` (a repository access token that can read pull
requests and push to main).

### Repository settings

- Allow **squash merge only**. On GitHub, set the default squash message to
  "Pull request title and commit details"; on Bitbucket, keep the proposed
  squash message. Either way the PR title becomes the changelog entry, and a
  `BREAKING CHANGE:` footer in any squashed commit still forces a major release.
- Let the release bot push to the default branch (GitHub: `RELEASE_TOKEN` or a
  ruleset bypass; Bitbucket: the access token as a branch-restriction exception).
- Add `CHANGELOG.md` to `.prettierignore`; it is generated.

Bitbucket can only block a merge on a failing check with the Premium plan, so a
bad PR title shows as a failed build there but does not stop the merge.

## Changelog

`cliff.toml` groups entries into Breaking changes, Features, Fixes and Other
changes, links Shortcut stories (`sc-1234`), and skips noise such as rebuilt
assets, formatting and PHPStan baselines. Skipped commits still release a patch:
a rebuild of the admin assets is a change consumers need.

A package's first `CHANGELOG.md` is backfilled once from its history with this
config, edited by hand and committed
([sc-11672](https://app.shortcut.com/tallieu--tallieu/story/11672)); releases
then only prepend.

`--unit pr` makes each merged pull request one entry, reading the PR title from
Bitbucket's `Merged in … (pull request #N)` or GitHub's `Merge pull request #N`
commit. Use it for history made of merge commits (dry3); after the switch to
squash merges, `commit` and `pr` give the same result.

## Run it locally

```sh
export GIT_CLIFF="$(bin/install-git-cliff)"   # pinned git-cliff into .bin/
cd ../some-package
../dry-ci/bin/release --dry-run --tag-prefix v  # prints the next version and notes
```

Tests: `GIT_CLIFF="$(bin/install-git-cliff)" tests/release.test.sh`.

## Versioning dry-ci

Callers pin `@v1` (GitHub) or the `v1` tarball (Bitbucket). Tag each change
`v1.x.y` and move `v1` to it:

```sh
git tag v1.2.0 && git tag -f v1 v1.2.0 && git push origin v1.2.0 && git push -f origin v1
```

Breaking changes to inputs, scripts or bump rules get `v2`; update
`dry-ci-ref`'s default in `php-package.yml` and the tarball URL in the
Bitbucket template with it.

## Decisions

Made 2026-09-28 in Shortcut epic 7219 ([sc-11671](https://app.shortcut.com/tallieu--tallieu/story/11671)):

- One engine on both hosts: git-cliff plus these scripts. release-please is
  GitHub-only; semantic-release needs Node in every PHP repo and cannot backfill.
- Release on every merge to the default branch, only after CI is green; no
  pre-release (beta) tags.
- Tag format stays per repo: dry3 `vX.Y.Z`, the GitHub packages bare `X.Y.Z`.
  Composer treats both the same.
- Squash merges with a linted PR title are the source of truth for the bump.
- CI commits `CHANGELOG.md` to the default branch.
- PHP 8.4 only; each package keeps its own PHPStan level.
