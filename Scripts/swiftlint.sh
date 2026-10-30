#!/bin/sh
#
# Lints the repository against the root .swiftlint.yml. The SwiftLint build phase of every framework
# target runs it, so Xcode shows the violations and an error fails the build. Safe to run by hand
# from anywhere, after Scripts/swiftformat.sh:
#
#     Scripts/swiftlint.sh
#
# Arguments are passed on to `swiftlint lint`: `--strict` fails on warnings too.
# SKIP_SWIFTLINT=YES skips it, as CI does.
#
# The binary is downloaded from the pinned release on first use and cached outside the repository,
# as Scripts/swiftformat.sh does it.
#
# To update SwiftLint, change VERSION and CHECKSUM together; CHECKSUM is `shasum -a 256` of the
# release's portable_swiftlint.zip.

set -eu

if [ "${SKIP_SWIFTLINT:-}" = "YES" ]; then
  exit 0
fi

readonly VERSION="0.65.1"
readonly CHECKSUM="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"

readonly root_path="$(cd "$(dirname "$0")/.." && pwd)"

# Not `swiftlint/`: on a case-insensitive volume, that is SwiftLint's own result cache.
readonly cache_path="${XDG_CACHE_HOME:-$HOME/Library/Caches}/swiftlint-binary/${VERSION}"
readonly binary_path="${cache_path}/swiftlint"

if [ ! -x "${binary_path}" ]; then
  readonly temporary_path="$(mktemp -d)"
  trap 'rm -rf "${temporary_path}"' EXIT INT TERM

  echo "note: downloading SwiftLint ${VERSION}"
  curl -fsSL -o "${temporary_path}/swiftlint.zip" \
    "https://github.com/realm/SwiftLint/releases/download/${VERSION}/portable_swiftlint.zip"

  # Checked before unpacking: the checksum is all that vouches for the binary.
  echo "${CHECKSUM}  ${temporary_path}/swiftlint.zip" | shasum -a 256 -c - > /dev/null

  unzip -qo "${temporary_path}/swiftlint.zip" -d "${temporary_path}"
  chmod +x "${temporary_path}/swiftlint"
  mkdir -p "${cache_path}"

  # A rename, so a build running at the same time sees either no binary or the whole one.
  mv -f "${temporary_path}/swiftlint" "${binary_path}"

  rm -rf "${temporary_path}"
  trap - EXIT INT TERM
fi

# SwiftLint reads .swiftlint.yml, and resolves its `included` paths, from the working directory.
cd "${root_path}"
exec "${binary_path}" lint --quiet "$@"
