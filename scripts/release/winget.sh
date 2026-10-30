#!/bin/bash
# The winget package (`winget install lollipopkit.serverbox`, #1572), from the
# manifests in .github/winget/.
#
#   winget.sh render <dir>   VERSION, URL, SHA256, RELEASE_DATE, RELEASE_NOTES_URL
#   winget.sh check <dir>    against the schema of their ManifestVersion
#   winget.sh submit <dir>   GH_TOKEN: a classic `public_repo` token of the
#                            account holding the winget-pkgs fork
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/.github/winget"
PACKAGE_ID=lollipopkit.serverbox
UPSTREAM=microsoft/winget-pkgs
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

check() {
  local dir=$1 f type version
  local schemas="https://raw.githubusercontent.com/microsoft/winget-cli/$SCHEMA_REF/schemas/JSON/manifests/v$MANIFEST_VERSION"
  version="$(field PackageVersion "$dir/$PACKAGE_ID.yaml")"
  for f in "$dir"/*.yaml; do
    # shellcheck disable=SC2016 # a literal `${`
    if grep -n '\${' "$f"; then
      echo "::error file=$f::left unrendered"
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
    "${CHECK_JSONSCHEMA[@]}" --schemafile "$schemas/manifest.$type.$MANIFEST_VERSION.json" "$f"
  done
}

submit() {
  local dir=$1 version path existing owner fork base base_tree tree commit branch
  version="$(field PackageVersion "$dir/$PACKAGE_ID.yaml")"
  path="manifests/${PACKAGE_ID:0:1}/${PACKAGE_ID//.//}/$version"

  if gh api "repos/$UPSTREAM/contents/$path" --silent 2>/dev/null; then
    echo "::notice::$PACKAGE_ID $version is already in $UPSTREAM"
    return
  fi
  existing="$(gh api -X GET search/issues \
    -f q="repo:$UPSTREAM is:pr is:open in:title \"$PACKAGE_ID\" \"$version\"" \
    --jq '.items[0].html_url // empty')"
  if [[ -n "$existing" ]]; then
    echo "::notice::$PACKAGE_ID $version is already proposed: $existing"
    return
  fi

  owner="$(gh api user --jq .login)"
  fork="$owner/winget-pkgs"
  gh api -X POST "repos/$fork/merge-upstream" -f branch=master --silent
  base="$(gh api "repos/$fork/git/ref/heads/master" --jq .object.sha)"
  base_tree="$(gh api "repos/$fork/git/commits/$base" --jq .tree.sha)"

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
  # Unique, so a rerun after a failed pull request does not find it taken.
  branch="$PACKAGE_ID-$version-$(date +%s)"
  gh api "repos/$fork/git/refs" -f ref="refs/heads/$branch" -f sha="$commit" --silent

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
  *)
    echo "usage: $0 render|check|submit <dir>" >&2
    exit 2
    ;;
esac
