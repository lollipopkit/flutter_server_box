#!/bin/bash
# The winget package (`winget install lollipopkit.serverbox`, #1572), from the
# manifests in .github/winget/.
#
# Submitted by hand after a release: `release`, `check`, `submit`.
#
#   winget.sh release <version> <dir>  renders from the published release
#   winget.sh render <dir>   VERSION, URL, SHA256, RELEASE_DATE, RELEASE_NOTES_URL
#   winget.sh check <dir>    against the schema of their ManifestVersion
#   winget.sh submit <dir>   as the `gh` account holding the winget-pkgs fork
#                            (a token needs `public_repo` and `workflow`)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/.github/winget"
PACKAGE_ID=lollipopkit.serverbox
UPSTREAM=microsoft/winget-pkgs
REPO=lollipopkit/flutter_server_box
INSTALLER_PREFIX=ServerBox
# winget-pkgs refuses a deprecated ManifestVersion. The templates and this
# move together.
MANIFEST_VERSION=1.28.0
# microsoft/winget-cli, at a commit with the schemas of MANIFEST_VERSION.
SCHEMA_REF=dafe5e7795c6b36e2a8cea86aa9fddec898df795
CHECK_JSONSCHEMA=(pipx run --spec check-jsonschema==0.38.2 check-jsonschema)

# field <name> <file>
field() {
  sed -n "s/^$1: //p" "$2"
}

render() {
  local out=$1
  : "${VERSION:?}" "${URL:?}" "${SHA256:?}" "${RELEASE_DATE:?}" "${RELEASE_NOTES_URL:?}"
  mkdir -p "$out"
  for f in "$TEMPLATE_DIR"/*.yaml; do
    # shellcheck disable=SC2016,SC2094 # the names envsubst replaces; another file
    envsubst '${VERSION} ${URL} ${SHA256} ${RELEASE_DATE} ${RELEASE_NOTES_URL}' \
      < "$f" > "$out/$(basename "$f")"
  done
}

# release <version> <dir>
release() {
  local name
  VERSION=$1
  name="${INSTALLER_PREFIX}_v${VERSION}_windows_amd64.exe"
  URL="https://github.com/$REPO/releases/download/v$VERSION/$name"
  # From the release's own checksums rather than a second download.
  SHA256="$(gh release download "v$VERSION" --repo "$REPO" -p SHA256SUMS -O - |
    awk -v f="$name" '$2 == f || $2 == "*" f { print $1 }')"
  [[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || { echo "no checksum for $name" >&2; return 1; }
  RELEASE_DATE="$(gh api "repos/$REPO/releases/tags/v$VERSION" --jq '.published_at[:10]')"
  RELEASE_NOTES_URL="https://github.com/$REPO/releases/tag/v$VERSION"
  export VERSION URL SHA256 RELEASE_DATE RELEASE_NOTES_URL
  render "$2"
}

check() {
  local dir=$1 f type name version
  local schemas="https://raw.githubusercontent.com/microsoft/winget-cli/$SCHEMA_REF/schemas/JSON/manifests/v$MANIFEST_VERSION"
  version="$(field PackageVersion "$dir/$PACKAGE_ID.yaml")"
  for type in installer defaultLocale; do
    if [[ "$(grep -l "^ManifestType: $type$" "$dir"/*.yaml | wc -l)" -ne 1 ]]; then
      echo "::error::not exactly one $type manifest in $dir"
      return 1
    fi
  done
  for f in "$dir"/*.yaml; do
    # shellcheck disable=SC2016 # a literal `${`
    if grep -n '\${' "$f"; then
      echo "::error file=$f::left unrendered"
      return 1
    fi
    if [[ "$(field PackageIdentifier "$f")" != "$PACKAGE_ID" ]]; then
      echo "::error file=$f::PackageIdentifier is not $PACKAGE_ID"
      return 1
    fi
    if [[ "$(field ManifestVersion "$f")" != "$MANIFEST_VERSION" ]]; then
      echo "::error file=$f::ManifestVersion is not $MANIFEST_VERSION"
      return 1
    fi
    if [[ "$(field PackageVersion "$f")" != "$version" ]]; then
      echo "::error file=$f::PackageVersion is not $version"
      return 1
    fi
    type="$(field ManifestType "$f")"
    # The names winget-pkgs expects.
    case "$type" in
      version) name="$PACKAGE_ID.yaml" ;;
      installer) name="$PACKAGE_ID.installer.yaml" ;;
      defaultLocale | locale) name="$PACKAGE_ID.locale.$(field PackageLocale "$f").yaml" ;;
      *) name='' ;;
    esac
    if [[ "$(basename "$f")" != "$name" ]]; then
      echo "::error file=$f::a $type manifest is named ${name:-nothing}"
      return 1
    fi
    "${CHECK_JSONSCHEMA[@]}" --schemafile "$schemas/manifest.$type.$MANIFEST_VERSION.json" "$f"
  done
}

submit() {
  local dir=$1 version path out owner fork branch base base_tree tree commit existing
  version="$(field PackageVersion "$dir/$PACKAGE_ID.yaml")"
  path="manifests/${PACKAGE_ID:0:1}/${PACKAGE_ID//.//}/$version"

  if out="$(gh api "repos/$UPSTREAM/contents/$path" --silent 2>&1)"; then
    echo "::notice::$PACKAGE_ID $version is already in $UPSTREAM"
    return
  elif [[ "$out" != *"HTTP 404"* ]]; then
    echo "$out" >&2
    return 1
  fi

  owner="$(gh api user --jq .login)"
  fork="$owner/winget-pkgs"
  # One per version: a rerun finds the branch, and the pull request, of the
  # run before it.
  branch="$PACKAGE_ID-$version"
  existing="$(gh api -X GET "repos/$UPSTREAM/pulls" -f head="$owner:$branch" -f state=open \
    --jq '.[0].html_url // empty')"
  if [[ -n "$existing" ]]; then
    echo "::notice::$PACKAGE_ID $version is already proposed: $existing"
    return
  fi

  if out="$(gh api "repos/$fork/contents/$path?ref=$branch" 2>&1)"; then
    # Left by a run that stopped before its pull request: only good to
    # propose if it holds these manifests.
    if [[ "$(jq -r '[.[] | "\(.name) \(.sha)"] | sort | .[]' <<<"$out")" != \
      "$(for f in "$dir"/*.yaml; do echo "$(basename "$f") $(git hash-object "$f")"; done | sort)" ]]; then
      echo "::error::$fork has a branch $branch with other manifests; delete it and run again"
      return 1
    fi
  elif [[ "$out" != *"HTTP 404"* ]]; then
    echo "$out" >&2
    return 1
  else
    # On upstream's master, which the fork shares objects with; the fork's own
    # master is never read or synced.
    base="$(gh api "repos/$UPSTREAM/git/ref/heads/master" --jq .object.sha)"
    base_tree="$(gh api "repos/$UPSTREAM/git/commits/$base" --jq .tree.sha)"
    # One commit through the Git data API: no clone of winget-pkgs.
    tree="$(for f in "$dir"/*.yaml; do
        jq -n --arg path "$path/$(basename "$f")" --rawfile content "$f" \
          '{path: $path, mode: "100644", type: "blob", content: $content}'
      done | jq -s --arg base "$base_tree" '{base_tree: $base, tree: .}' |
      gh api "repos/$fork/git/trees" --input - --jq .sha)"
    commit="$(jq -n --arg message "New version: $PACKAGE_ID version $version" \
        --arg tree "$tree" --arg parent "$base" \
        '{message: $message, tree: $tree, parents: [$parent]}' |
      gh api "repos/$fork/git/commits" --input - --jq .sha)"
    gh api "repos/$fork/git/refs" -f ref="refs/heads/$branch" -f sha="$commit" --silent
  fi

  gh api "repos/$UPSTREAM/pulls" \
    -f title="New version: $PACKAGE_ID version $version" \
    -f head="$owner:$branch" -f base=master \
    -f body="Release notes: $(field ReleaseNotesUrl "$dir/$PACKAGE_ID.locale.en-US.yaml")" \
    --jq .html_url
}

case "${1:-}" in
  render | check | submit)
    [[ $# -eq 2 ]] || { echo "usage: $0 $1 <dir>" >&2; exit 2; }
    "$1" "$2"
    ;;
  release)
    [[ $# -eq 3 ]] || { echo "usage: $0 release <version> <dir>" >&2; exit 2; }
    release "$2" "$3"
    ;;
  *)
    echo "usage: $0 release <version> <dir> | render|check|submit <dir>" >&2
    exit 2
    ;;
esac
