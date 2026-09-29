# Maintaining dry-ci

How to change dry-ci itself: where things are, how to test, and how to release a new version
to the packages.

## Layout

| Path                                                                   | What                                                                  |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------- |
| [`bin/release`](../bin/release)                                        | Next version, `CHANGELOG.md` section, release commit, tag, push       |
| [`bin/check`](../bin/check)                                            | The checks: `composer`, `prettier`, `phpstan`, `pest`, `audit`        |
| [`bin/lint-pr-title`](../bin/lint-pr-title)                            | PR-title check (a title argument, or `--bitbucket` via the API)       |
| [`bin/install-git-cliff`](../bin/install-git-cliff)                    | Downloads the pinned git-cliff and checks its checksum                |
| [`cliff.toml`](../cliff.toml)                                          | git-cliff config: parsing, grouping, noise filters, changelog layout  |
| [`.github/workflows/php-package.yml`](../.github/workflows/php-package.yml) | The reusable workflow GitHub packages call                        |
| [`bitbucket/bitbucket-pipelines.yml`](../bitbucket/bitbucket-pipelines.yml) | The template Bitbucket packages copy                              |
| [`bitbucket/project-pipelines.yml`](../bitbucket/project-pipelines.yml) | The checks-only template Bitbucket projects copy                  |
| [`examples/github-ci.yml`](../examples/github-ci.yml)                  | The thin caller a GitHub package copies                               |
| [`docker/php/Dockerfile`](../docker/php/Dockerfile)                    | The CI image Bitbucket steps run in                                   |
| [`tests/release.test.sh`](../tests/release.test.sh)                    | Scenario tests for `bin/release` and `cliff.toml`                     |

Everything a package runs is in `bin/`, so both hosts run the same commands. The workflow and
the template only install tools and call these scripts.

## Run it locally

```sh
export GIT_CLIFF="$(bin/install-git-cliff)"      # pinned git-cliff into .bin/
cd ../some-package
../dry-ci/bin/release --dry-run --unit pr --tag-prefix v
```

`--dry-run` prints the next version and its changelog section, and changes nothing. Leave out
`--tag-prefix` for packages with bare tags. Run it against a throwaway clone if you also want to
try a real release: without `--dry-run` it commits, tags and pushes.

## Test

```sh
GIT_CLIFF="$(bin/install-git-cliff)" tests/release.test.sh
shellcheck bin/* tests/*.sh
```

The tests build throwaway git repositories for each scenario: bump rules, tag prefixes, beta
tags, Bitbucket and GitHub merge commits, noise filtering, and a real commit/tag/push into a
local bare remote. A change to `cliff.toml` or `bin/release` needs a scenario here; start with
one that fails without the change. The [test workflow](../.github/workflows/test.yml) runs both
commands on every push and pull request.

## Release a new version

Packages pin `@v1` (GitHub) or the `v1` tarball (Bitbucket), so a push to `main` changes
nothing for them until `v1` moves. After merging to `main`:

```sh
git tag v1.2.0 && git tag -f v1 v1.2.0
git push origin v1.2.0 && git push -f origin v1
```

- **Patch** (`v1.1.x`): a fix that doesn't change what a package sees, apart from the fix.
- **Minor** (`v1.x.0`): new inputs or options, or a changed default that packages don't set
  explicitly.
- **Major** (`v2.0.0`): a removed or renamed input or option, or a change to the bump rules.
  Change `dry-ci-ref`'s default in `php-package.yml` and the tarball URL in the Bitbucket
  template to `v2` in the same change, then move each package over deliberately.

Moving `v1` affects every package at its next run, so check the change with `--dry-run`
against one or two packages first.

## The CI image

Bitbucket steps run in `ghcr.io/tallieutallieu/dry-ci-php:8.4`, built from
[`docker/php/Dockerfile`](../docker/php/Dockerfile): PHP 8.4 CLI with git, ssh, unzip, Composer,
`gd`, `exif`, `imagick` and `zip`. ssh is for projects, which pull dry3 over
`git@bitbucket.org`. Compiling those extensions on every run took about two minutes;
with the image, a step starts with the image pull. GitHub packages don't use it: `setup-php`
installs prebuilt extensions quickly.

The [image workflow](../.github/workflows/image.yml) builds it on a change to `docker/`, every
Monday for PHP and Debian security patches, and on demand (Actions → image → Run workflow). Each
build also gets an `8.4-<commit>` tag, to pin or roll back a package.

The package must stay **public** (GitHub → the organisation's Packages → `dry-ci-php` → Package
settings → Change visibility), so Bitbucket pulls it without credentials. A package that needs
one more extension installs it in its own step with `install-php-extensions <name>`, which the
image keeps.

## Updating git-cliff

`bin/install-git-cliff` pins a version and the SHA-512 of each platform's archive. To update,
change `VERSION` and the four checksums from the release's `.sha512` files on
[git-cliff's releases](https://github.com/orhun/git-cliff/releases), then run the tests.
