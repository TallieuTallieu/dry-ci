#!/usr/bin/env bash
# Scenario tests for bin/release against throwaway git repos.
# Usage: GIT_CLIFF=/path/to/git-cliff tests/release.test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE="$ROOT/bin/release"
export GIT_CLIFF="${GIT_CLIFF:-git-cliff}"

work="$(mktemp -d "${TMPDIR:-/tmp}/dry-ci-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
failures=0

# new_repo NAME FIRST_TAG: a repo with one commit tagged FIRST_TAG, plus a bare
# "origin" so pushes can be checked.
new_repo() {
  local dir="$work/$1"
  git init -q --bare "$dir.origin.git"
  git init -q -b main "$dir"
  cd "$dir"
  git config user.email test@example.com
  git config user.name test
  git remote add origin "$dir.origin.git"
  commit "feat: initial"
  git tag "$2"
  git push -q origin main "$2"
}

commit() {
  echo "$RANDOM" >> file
  git add file
  git commit -q -m "$1"
}

# merge_pr BRANCH TITLE [COMMIT...]: a real merge commit in Bitbucket's format.
merge_pr() {
  local branch="$1" title="$2"
  shift 2
  git checkout -q -b "$branch"
  for msg in "$@"; do commit "$msg"; done
  git checkout -q main
  git merge -q --no-ff "$branch" -m "Merged in $branch (pull request #1)" -m "$title"
}

expect_version() {
  local name="$1" want="$2"
  shift 2
  local got
  got="$("$RELEASE" --dry-run "$@" 2>/dev/null | head -n 1 || true)"
  if [[ "$got" == "$want" ]]; then
    echo "ok   $name ($got)"
  else
    echo "FAIL $name: want '$want', got '$got'"
    failures=$((failures + 1))
  fi
}

expect_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: missing '$needle' in:"
    echo "$haystack" | sed 's/^/     /'
    failures=$((failures + 1))
  fi
}

expect_absent() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: unexpected '$needle' in:"
    echo "$haystack" | sed 's/^/     /'
    failures=$((failures + 1))
  fi
}

# --- bump rules -------------------------------------------------------------

new_repo fix 1.2.3
commit "fix: correct a thing"
expect_version "fix bumps patch" 1.2.4

new_repo feat 1.2.3
commit "fix: correct a thing"
commit "feat(orm): add a thing"
expect_version "feat bumps minor" 1.3.0

new_repo bang 1.2.3
commit "feat!: drop a thing"
commit "fix: correct a thing"
expect_version "! bumps major" 2.0.0
notes="$("$RELEASE" --dry-run 2>/dev/null)"
expect_contains "breaking change has its own section" "$notes" "### Breaking changes"
if [[ "$(grep -c 'Drop a thing' <<< "$notes")" == 1 ]]; then
  echo "ok   breaking change is listed once"
else
  echo "FAIL breaking change is listed once"
  failures=$((failures + 1))
fi

new_repo footer 1.2.3
commit "$(printf 'refactor: rework a thing\n\nBREAKING CHANGE: the thing is gone')"
expect_version "BREAKING CHANGE footer bumps major" 2.0.0

new_repo zero 0.4.1
commit "feat!: drop a thing"
expect_version "breaking bumps major below 1.0" 1.0.0

new_repo chore 1.2.3
commit "chore: tidy up"
expect_version "chore bumps patch" 1.2.4

new_repo unconventional 1.2.3
commit "Add a feature without a type"
expect_version "unconventional bumps patch" 1.2.4

new_repo skipped 1.2.3
commit "chore(build): rebuild admin assets"
expect_version "skipped-only changes still release a patch" 1.2.4
notes="$("$RELEASE" --dry-run 2>/dev/null)"
expect_contains "skipped-only release says so" "$notes" "No notable changes."

# --- tags -------------------------------------------------------------------

new_repo prefix v4.1.1
commit "feat: add a thing"
expect_version "tag prefix is kept" v4.2.0 --tag-prefix v

new_repo betas v4.1.1
commit "feat: add a thing"
git tag v4.2.0-beta.1
commit "fix: correct a thing"
git tag v4.2.0-beta.2
expect_version "beta tags are ignored" v4.2.0 --tag-prefix v

new_repo mixed 3.1.0
git tag v9.9.9
commit "fix: correct a thing"
expect_version "tags with another prefix are ignored" 3.1.1

# --- Bitbucket merges -------------------------------------------------------

new_repo bbfeat v1.0.0
merge_pr feature/sc-123--add-thing "feat(admin): add a thing" "wip" "fix typo"
expect_version "PR title decides the bump" v1.1.0 --tag-prefix v --unit pr
notes="$("$RELEASE" --dry-run --tag-prefix v --unit pr 2>/dev/null)"
expect_contains "per-PR entry uses the title" "$notes" "**admin:** Add a thing"
expect_contains "per-PR entry links the story" "$notes" "[sc-123](https://app.shortcut.com/tallieu--tallieu/story/123)"
expect_absent "per-PR hides branch commits" "$notes" "Wip"

new_repo bbsquash v1.0.0
commit "$(printf 'Merged in bug/sc-9--fix-thing (pull request #7)\n\nfix(orm): correct a thing\n\n* wip\n* more')"
notes="$("$RELEASE" --dry-run --tag-prefix v 2>/dev/null)"
expect_contains "Bitbucket squash commit bumps from its title" "$notes" "v1.0.1"
expect_contains "Bitbucket squash entry uses the title" "$notes" "**orm:** Correct a thing"

new_repo ghsquash 3.0.14
commit "$(printf 'fix(session): harden cookies (#10)\n\n* feat(cookie): support SameSite\n\nBREAKING CHANGE: CookieInterface gains delete()\n\n* docs: document it')"
expect_version "BREAKING CHANGE in a squashed commit bumps major" 4.0.0

# --- releasing --------------------------------------------------------------

new_repo release 2.0.0
commit "feat: add a thing"
"$RELEASE" >/dev/null 2>&1
expect_contains "release tags HEAD" "$(git tag --points-at HEAD)" "2.1.0"
expect_contains "release commit message" "$(git log -1 --format=%s)" "chore(release): 2.1.0 [skip ci]"
expect_contains "changelog has header" "$(cat CHANGELOG.md)" "# Changelog"
expect_contains "changelog has section" "$(cat CHANGELOG.md)" "## 2.1.0 - "
expect_contains "tag was pushed" "$(git ls-remote --tags origin)" "refs/tags/2.1.0"
expect_contains "branch was pushed" "$(git ls-remote origin main)" "$(git rev-parse HEAD)"
expect_version "rerun on released HEAD is a no-op" ""

commit "fix: correct a thing"
"$RELEASE" >/dev/null 2>&1
changelog="$(cat CHANGELOG.md)"
expect_contains "second release prepends" "$changelog" "## 2.1.1 - "
expect_contains "first release is kept" "$changelog" "## 2.1.0 - "
if [[ "$(grep -c '^# Changelog' CHANGELOG.md)" == 1 ]]; then
  echo "ok   header written once"
else
  echo "FAIL header written once"
  failures=$((failures + 1))
fi
expect_absent "release commit is not an entry" "$changelog" "Release"

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
