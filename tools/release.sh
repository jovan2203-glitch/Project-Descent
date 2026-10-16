#!/usr/bin/env bash
# Publishes a release: tools/release.sh 0.0.16
# Needs: everything committed (patch notes included: docs/PATCH_NOTES_*.md) and
# the tests passing. Tags vX.Y.Z and pushes it; GitHub Actions
# (.github/workflows/release.yml) builds, zips and publishes the release.
# A version with a dash (0.0.16-rc1) is published as a pre-release.
set -eu
cd "$(dirname "$0")/.."
v="${1:?usage: tools/release.sh X.Y.Z}"
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Commit your changes first." >&2; exit 1
fi
tools/test.sh || { echo "Tests failed: no release." >&2; exit 1; }
git push origin HEAD
git tag -a "v$v" -m "Project Descent $v"
git push origin "v$v"
echo "Tagged v$v. GitHub Actions is building it: https://github.com/jovan2203-glitch/Project-Descent/actions"
