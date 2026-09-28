# Setting up a package

Step by step: what to change in a package, and in its settings, so it runs dry-ci. Do the
settings first, then open one pull request with the code changes. Merging that pull request
with a merge commit produces the package's first automatic release.

- [Before you start](#before-you-start)
- [GitHub packages](#github-packages)
- [Bitbucket packages (dry3)](#bitbucket-packages-dry3)
- [Per-package checklist](#per-package-checklist)
- [After the switch](#after-the-switch)

## Before you start

Check these in the package, on an up-to-date checkout of its default branch:

1. **A stable version tag exists.** dry-ci bumps from the latest `X.Y.Z` (or `vX.Y.Z`) tag
   and refuses to run without one. Tag the first release by hand if there is none.
2. **The latest release is on the default branch.** `git merge-base --is-ancestor <latest tag>
   origin/<default branch>` must succeed. dry-internal-api fails this: its 3.x tags live only
   on the `dry3` branch, so merge that branch first.
3. **`composer install` can resolve every dependency.** A package that requires
   `tallieutallieu/dry` needs the dry3 repository in `composer.json`:

   ```json
   "repositories": [{ "type": "vcs", "url": "git@bitbucket.org:tallieu/dry3.git" }]
   ```

4. **Prettier passes on the whole repository.** dry-ci runs `yarn prettier --check .`, not only
   `src` and `tests`. Run it locally, then either format the files or list them in
   `.prettierignore`. A package without Prettier in `package.json` skips the check with a
   warning.
5. **`CHANGELOG.md` is up to date.** Its newest section must be the latest tag. If the old
   release workflow tagged a version the changelog doesn't list, add that section below the
   header in the switch pull request (see the [checklist](#per-package-checklist)). Don't push
   the fix straight to the default branch: the old workflow would tag yet another version.

## GitHub packages

### 1. Merge settings

Settings → General → Pull Requests:

- ✅ **Allow merge commits**, with "Default commit message" left on **Default message** ("Pull
  request title" works too).
- ❌ **Allow squash merging**
- ❌ **Allow rebase merging**

dry-ci makes one changelog entry per merged pull request and reads it from the merge commit.
Squash and rebase merges leave no merge commit, so that pull request would get no entry.

### 2. Secrets

Only for packages that list the dry3 Bitbucket repository in `composer.json` (see the
[checklist](#per-package-checklist)):

- **`BITBUCKET_SSH_KEY`**: the private half of an SSH key that can read `tallieu/dry3`. Add
  the public half on Bitbucket under dry3 → Repository settings → Access keys (read-only). On
  GitHub, add it as an organisation secret (Organization settings → Secrets and variables →
  Actions) available to the packages that need it, or as a repository secret. dry-ecommerce,
  dry-mollie and dry-sendcloud already use one in their current workflows; check it is still
  set.

`RELEASE_TOKEN` is **not needed** today. The release job pushes its commit and tag with the
workflow's own `GITHUB_TOKEN`, which works because no package protects its default branch
against direct pushes. (dry-dbi and dry-sendcloud have rules against deleting the branch and
force-pushing, which the release doesn't do.) If you later add "Require a pull request before
merging", create a fine-grained token with Contents: read and write on the package, allowed to
bypass that rule, and store it as the `RELEASE_TOKEN` secret.

### 3. The switch pull request

On a new branch from the default branch:

1. **Delete the old workflows**: `.github/workflows/ci.yml` and `.github/workflows/release.yml`,
   if they exist.
2. **Add `.github/workflows/ci.yml`**, copied from
   [`examples/github-ci.yml`](../examples/github-ci.yml). Set the branch under `push:` to the
   package's default branch, and the inputs from the [checklist](#per-package-checklist):

   ```yaml
   name: CI

   on:
     pull_request:
       types: [opened, edited, synchronize, reopened]
     push:
       branches: [master]

   jobs:
     dry-ci:
       uses: TallieuTallieu/dry-ci/.github/workflows/php-package.yml@v1
       permissions:
         contents: write
       with:
         php-extensions: imagick, gd, exif
       secrets: inherit
   ```

   Leave out `with:` entries you don't need. Add `tag-prefix: v` for a package with `vX.Y.Z`
   tags.
3. **Add `CHANGELOG.md` to `.prettierignore`** (create the file if there is none). Releases
   write it.
4. **Fix what the pre-flight checks found**: Prettier, the dry3 repository entry, a missing
   changelog section.
5. **Remove release notes that the workflow no longer produces**, such as a stale
   `docs/release-process.md` (dry-dbi).
6. **Open the pull request with a Conventional Commit title**, e.g. `ci: switch to dry-ci`. The
   PR-title check and the package checks run on it; make them pass.

### 4. Merge it

Merge with **Create a merge commit**. On the default branch, the checks run again, then the
release job:

- commits `chore(release): X.Y.Z [skip ci]` with the new `CHANGELOG.md` section,
- tags it `X.Y.Z` and pushes both,
- creates a GitHub Release with the same notes.

The first release is a patch (`ci:` is not a feature). Check it under Actions and Releases.

### 5. Optional: require the checks

Settings → Rules → Rulesets (or Branches → Branch protection rules) on the default branch →
"Require status checks to pass": add `dry-ci / pr-title`, `dry-ci / phpstan`, `dry-ci / pest`
and `dry-ci / prettier`. They only exist after the first run.

## Bitbucket packages (dry3)

### 1. Merge settings

Repository settings → Workflow → Merge strategies (or the project's settings, if the repository
inherits them):

- Default: **Merge commit**.
- Allowed: only **Merge commit**. Turn off fast-forward, squash and rebase.

### 2. Access token

Repository settings → Security → Access tokens → **Create repository access token**:

- Name: `dry-ci`
- Scopes: **Repositories: Write** (push the release commit and tag) and **Pull requests:
  Read** (read the PR title for the title check)

Copy the token; Bitbucket shows it once.

### 3. Pipeline variable

Repository settings → Pipelines → Repository variables:

- Name `DRY_CI_BITBUCKET_TOKEN`, value the token, **Secured** ✅

Optional, only if some tests can't run in CI: `DRY_CI_PEST_ARGS`, e.g. `--filter='/^(?!.*Slow).*$/'`.
dry3 needs none: all its tests pass in dry-ci's CI image, which has `gd`, `exif`, `imagick` and
`zip`.

### 4. Branch restrictions

Repository settings → Workflow → Branch restrictions → the rule for `main`: the release job
pushes to `main` as the access token's bot user (`dry-ci`). If the rule limits write access or
requires a pull request, add that user as an exception. Pipelines' built-in credentials can't
push to a restricted branch, which is why the template uses the token. Verify this before
merging: a missing exception makes the first release fail at `git push`.

### 5. The switch pull request

On a new branch from `main`:

1. **Replace `bitbucket-pipelines.yml`** with
   [`bitbucket/bitbucket-pipelines.yml`](../bitbucket/bitbucket-pipelines.yml). For dry3 the
   marked lines stay as they are: `--tag-prefix v`, branch `main`, and no extra PHP extensions
   (the CI image `ghcr.io/tallieutallieu/dry-ci-php:8.4` already has what dry needs). The `dev`
   branch pipeline goes away.
2. **Delete `.bitbucket/tag.sh`, `.bitbucket/prettier-check.sh` and
   `.bitbucket/phpstan-check.sh`**; `bin/check` and `bin/release` replace them.
3. **Check `CHANGELOG.md`** against the latest tag, as in [Before you start](#before-you-start).
   It is already in `.prettierignore`.
4. **Update the CI/CD section of `CLAUDE.md`/`AGENTS.md`**: no `dev` branch, no beta tags,
   releases on merge to `main`, PR titles as Conventional Commits.
5. **Open the pull request to `main`** with a title like `ci: switch to dry-ci`.

### 6. Merge it

Merge with **Merge commit**. The `main` pipeline runs PHPStan + Pest and Prettier, then the
release step tags `vX.Y.Z` and pushes the `CHANGELOG.md` commit. Then remove the `dev` branch
([sc-11674](https://app.shortcut.com/tallieu--tallieu/story/11674)).

Bitbucket can only block a merge on a failed check with the Premium plan: a bad PR title shows
as a failed "PR title" step, but does not stop the merge.

## Per-package checklist

State on 2026-09-28. "Extensions" is the `php-extensions` input; every package that requires
dry (directly or through dry-ecommerce) needs dry's `imagick`, `gd` and `exif`.

| Package | Host | Branch | Tag prefix | Extensions | `BITBUCKET_SSH_KEY` | Changelog to add | Also |
| --- | --- | --- | --- | --- | --- | --- | --- |
| dry3 | Bitbucket | `main` | `v` | in the CI image | – | v4.2.1, if the old pipeline tagged it | Remove `.bitbucket/` scripts; then drop `dev` |
| oak | GitHub | `master` | – | – | – | 4.2.1 | |
| oak-wishlist | GitHub | `master` | – | `imagick, gd, exif` | yes | – | No workflows yet |
| dry-accounts | GitHub | `master` | – | `imagick, gd, exif` | yes | – | No tests: Pest is skipped |
| dry-crm | GitHub | `main` | `v` | – | yes | – | No PHPStan or tests |
| dry-datalist | GitHub | `master` | – | – | – | 3.1.1 | |
| dry-dbi | GitHub | `master` | – | – | – | 3.13.2 | Remove `docs/release-process.md` |
| dry-ecommerce | GitHub | `master` | – | `imagick, gd, exif` | yes (current workflow uses it) | 3.13.2 | |
| dry-external-api | GitHub | `master` | – | `imagick, gd, exif` | yes | – | Add the dry3 repository to `composer.json`; no PHPStan, tests or Prettier |
| dry-mollie | GitHub | `master` | – | `imagick, gd, exif` | yes (current workflow uses it) | 5.0.2 | |
| dry-redirects | GitHub | `master` | – | `imagick, gd, exif` | yes | – | No PHPStan, tests or Prettier |
| dry-sendcloud | GitHub | `master` | – | `imagick, gd, exif` | yes (current workflow uses it) | 3.0.3 | |
| dry-internal-api | GitHub | `master` | – | | | | Not ready: merge the `dry3` branch first |

The changelog sections to add are for versions the old workflow tagged when the backfilled
changelogs were merged. Each contains only `docs: backfill CHANGELOG.md`, so the section is:

```markdown
## 4.2.1 - 2026-09-28

No notable changes.
```

dry-sendcloud 3.0.3 also shipped two CI commits:

```markdown
## 3.0.3 - 2026-09-28

### Other changes

- Update the release action runtime
- Make auto-release reruns safe ([sc-9973](https://app.shortcut.com/tallieu--tallieu/story/9973))
```

## After the switch

- **Pull request titles** decide the release: `feat:` → minor, `fix:`/anything else → patch,
  `!` before the colon → major. See [How it works](how-it-works.md).
- **Don't create tags or edit version numbers by hand.** Past `CHANGELOG.md` entries may be
  edited; new ones come from the merged titles.
- **A package without PHPStan, tests or Prettier** passes with a warning for each. Adding them
  later needs no workflow change: dry-ci picks up `phpstan.neon`, `tests/` and Prettier in
  `package.json` by themselves.
