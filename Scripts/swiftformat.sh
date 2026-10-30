#!/bin/sh
#
# Formats the repository in place against the root .swiftformat. The SwiftFormat pre-action of every
# shared scheme runs it before the build, so Scripts/swiftlint.sh and the compiler see formatted code.
# Safe to run by hand from anywhere:
#
#     Scripts/swiftformat.sh
#
# The binary is downloaded from the pinned release on first use and cached outside the repository.
# It is not committed: git drops the extended attributes, so a checked-out copy can be quarantined,
# and Gatekeeper blocks the release binary, which is signed ad hoc.
#
# To update SwiftFormat, change VERSION and CHECKSUM together; CHECKSUM is `shasum -a 256` of the
# release's swiftformat.zip.

set -eu

readonly VERSION="0.64.4"
readonly CHECKSUM="bb42fbfb0b9d5f1b8b83db3147087220ea414916fce8c5cf71abaea5ad5a3175"

readonly root_path="$(cd "$(dirname "$0")/.." && pwd)"

# Keyed by version, so checkouts and worktrees share one download, and an update never replaces it.
readonly cache_path="${XDG_CACHE_HOME:-$HOME/Library/Caches}/swiftformat/${VERSION}"
readonly binary_path="${cache_path}/swiftformat"

if [ ! -x "${binary_path}" ]; then
  readonly temporary_path="$(mktemp -d)"
  trap 'rm -rf "${temporary_path}"' EXIT INT TERM

  echo "note: downloading SwiftFormat ${VERSION}"
  curl -fsSL -o "${temporary_path}/swiftformat.zip" \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/${VERSION}/swiftformat.zip"

  # Checked before unpacking: the binary is signed ad hoc, so the checksum is all that vouches for it.
  echo "${CHECKSUM}  ${temporary_path}/swiftformat.zip" | shasum -a 256 -c - > /dev/null

  unzip -qo "${temporary_path}/swiftformat.zip" -d "${temporary_path}"
  chmod +x "${temporary_path}/swiftformat"
  mkdir -p "${cache_path}"

  # A rename, so a build running at the same time sees either no binary or the whole one.
  mv -f "${temporary_path}/swiftformat" "${binary_path}"

  rm -rf "${temporary_path}"
  trap - EXIT INT TERM
fi

exec "${binary_path}" "${root_path}"
