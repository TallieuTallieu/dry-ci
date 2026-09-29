# Setting up a project

A dry project (a site, such as torck_2025) runs dry-ci's checks, but not its releases: projects
aren't versioned, so nothing is tagged and no `CHANGELOG.md` is written. PR titles aren't
checked either, and merge settings are up to the project.

On each pull request, [`bitbucket/project-pipelines.yml`](../bitbucket/project-pipelines.yml)
runs the same `bin/check` subcommands as a package (see
[How it works](how-it-works.md#on-a-pull-request)):

| Step           | Runs                                                             |
| -------------- | ---------------------------------------------------------------- |
| PHPStan + Pest | `check composer`, `check phpstan`, `check pest`                  |
| composer audit | `check composer`, `check audit`                                  |
| Prettier       | `check prettier`: the whole repository, with the locked Prettier |

Checks a project has on top of these, such as ESLint, stay in the project's own pipeline as
extra steps.

## Before you start

1. **Prettier passes on the whole repository.** The check runs `prettier --check .`, not only
   the globs in the project's `format` script. Run it locally and format the files, or list
   generated ones (`rev-manifest.json`, `app/revision_control/*.json`, MJML templates) in
   `.prettierignore`.
2. **PHPStan is in `require-dev`** and the project has a `phpstan.neon`. Without them the step
   passes with a warning.
3. **The repository SSH key can read dry3.** Projects pull `tallieutallieu/dry` from
   `git@bitbucket.org:tallieu/dry3.git`. Repository settings → Pipelines → SSH keys: the
   project's key must have read access to every private repository in `composer.json`. A
   project whose current pipeline already runs `composer install` has this.

## The switch pull request

On a new branch from the default branch:

1. **Replace `bitbucket-pipelines.yml`** with
   [`bitbucket/project-pipelines.yml`](../bitbucket/project-pipelines.yml). Keep the project's
   own steps (ESLint) in the `parallel` block.
2. **Delete `.bitbucket/prettier-check.sh` and `.bitbucket/phpstan-check.sh`**; `bin/check`
   replaces them.
3. **Fix what Prettier reports** on the whole repository, as above.
4. **Open the pull request.** Its pipeline is the first run of the new checks.

Composer runs with `--no-scripts`: a project's post-install scripts (`dry publish:assets`)
expect a configured site. Composer installs from `composer.lock`, and the CI image has the
`gd`, `exif`, `imagick` and `zip` extensions, so `--ignore-platform-req` isn't needed.
