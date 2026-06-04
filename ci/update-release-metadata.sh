#!/usr/bin/env bash
set -euo pipefail

PROJECT_FILE="${PROJECT_FILE:-NightFlix.xcodeproj/project.pbxproj}"
LATEST_VERSION_FILE="${LATEST_VERSION_FILE:-latest-version.txt}"
REPO_JSON_FILE="${REPO_JSON_FILE:-repo.json}"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-FrizzleM.NightFlix}"
TAG_NAME="${TAG_NAME:-}"
SOURCE_REF="${SOURCE_REF:-}"
RELEASE_DOWNLOAD_URL="${RELEASE_DOWNLOAD_URL:-}"
RELEASE_ASSET_SIZE="${RELEASE_ASSET_SIZE:-}"
RELEASE_PUBLISHED_AT="${RELEASE_PUBLISHED_AT:-}"
COMMIT_CHANGES="${COMMIT_CHANGES:-false}"
PUSH_BRANCH="${PUSH_BRANCH:-}"

extract_marketing_version() {
  awk -F= '
    /MARKETING_VERSION[[:space:]]*=/ {
      value=$2
      gsub(/[[:space:];]/, "", value)
      if (value != "") {
        print value
        exit
      }
    }
  '
}

if ! command -v jq > /dev/null 2>&1; then
  echo "::error::jq is required to update $REPO_JSON_FILE."
  exit 1
fi

if [[ -n "$TAG_NAME" ]]; then
  git fetch --force origin "refs/tags/${TAG_NAME}:refs/tags/${TAG_NAME}" || git fetch --force --tags origin
fi

if [[ -z "$SOURCE_REF" && -n "$TAG_NAME" ]]; then
  SOURCE_REF="refs/tags/$TAG_NAME"
fi

release_json=""
if [[ -n "$TAG_NAME" && ( -z "$RELEASE_DOWNLOAD_URL" || -z "$RELEASE_ASSET_SIZE" || -z "$RELEASE_PUBLISHED_AT" ) ]]; then
  if command -v gh > /dev/null 2>&1 && [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    if ! release_json="$(gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${TAG_NAME}" 2> /dev/null)"; then
      echo "::warning::Could not fetch GitHub release metadata for $TAG_NAME; keeping existing download metadata."
      release_json=""
    fi
  fi
fi

if [[ -z "$RELEASE_DOWNLOAD_URL" && -n "$release_json" ]]; then
  RELEASE_DOWNLOAD_URL="$(
    jq -r 'first(.assets[]? | select(.name | test("\\.ipa$"; "i")) | .browser_download_url) // empty' <<< "$release_json"
  )"
fi

if [[ -z "$RELEASE_ASSET_SIZE" && -n "$release_json" && -n "$RELEASE_DOWNLOAD_URL" ]]; then
  RELEASE_ASSET_SIZE="$(
    jq -r --arg url "$RELEASE_DOWNLOAD_URL" 'first(.assets[]? | select(.browser_download_url == $url) | .size) // empty' <<< "$release_json"
  )"
fi

if [[ -z "$RELEASE_PUBLISHED_AT" && -n "$release_json" ]]; then
  RELEASE_PUBLISHED_AT="$(jq -r '.published_at // empty' <<< "$release_json")"
fi

if [[ -n "${APP_VERSION:-}" ]]; then
  app_version="$APP_VERSION"
elif [[ -n "$SOURCE_REF" ]]; then
  app_version="$(git show "${SOURCE_REF}:${PROJECT_FILE}" | extract_marketing_version)"
else
  app_version="$(extract_marketing_version < "$PROJECT_FILE")"
fi

if [[ -z "$app_version" ]]; then
  echo "::error::Could not find MARKETING_VERSION in $PROJECT_FILE."
  exit 1
fi

if [[ ! "$app_version" =~ ^[0-9]+[.][0-9]+([.][0-9]+)?$ ]]; then
  echo "::error::Unsupported MARKETING_VERSION '$app_version'. Expected a semantic version like 1.2.0."
  exit 1
fi

if ! jq -e --arg bundle "$APP_BUNDLE_IDENTIFIER" \
  'any(.apps[]?; .bundleIdentifier == $bundle and (.versions | type == "array") and (.versions | length > 0))' \
  "$REPO_JSON_FILE" > /dev/null; then
  echo "::error::Could not find an app entry with at least one version for bundle $APP_BUNDLE_IDENTIFIER."
  exit 1
fi

asset_size_json="null"
if [[ -n "$RELEASE_ASSET_SIZE" && "$RELEASE_ASSET_SIZE" != "null" ]]; then
  if [[ ! "$RELEASE_ASSET_SIZE" =~ ^[0-9]+$ ]]; then
    echo "::error::Release asset size '$RELEASE_ASSET_SIZE' is not numeric."
    exit 1
  fi

  asset_size_json="$RELEASE_ASSET_SIZE"
fi

printf "%s\n" "$app_version" > "$LATEST_VERSION_FILE"

tmp_repo_json="$(mktemp)"
trap 'rm -f "$tmp_repo_json"' EXIT

jq \
  --arg bundle "$APP_BUNDLE_IDENTIFIER" \
  --arg version "$app_version" \
  --arg downloadURL "$RELEASE_DOWNLOAD_URL" \
  --arg publishedAt "$RELEASE_PUBLISHED_AT" \
  --argjson assetSize "$asset_size_json" \
  '(.apps[] | select(.bundleIdentifier == $bundle) | .versions[0]) |= (
    .version = $version
    | if $downloadURL != "" then .downloadURL = $downloadURL else . end
    | if $publishedAt != "" then .date = $publishedAt else . end
    | if $assetSize != null then .size = $assetSize else . end
  )' \
  "$REPO_JSON_FILE" > "$tmp_repo_json"
mv "$tmp_repo_json" "$REPO_JSON_FILE"
trap - EXIT

echo "Updated $LATEST_VERSION_FILE to $app_version."
if [[ -n "$RELEASE_DOWNLOAD_URL" ]]; then
  echo "Updated $REPO_JSON_FILE download URL to $RELEASE_DOWNLOAD_URL."
else
  echo "Left $REPO_JSON_FILE download URL unchanged."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "app_version=$app_version"
    echo "download_url=$RELEASE_DOWNLOAD_URL"
  } >> "$GITHUB_OUTPUT"
fi

if [[ "$COMMIT_CHANGES" == "true" ]]; then
  if git diff --quiet -- "$LATEST_VERSION_FILE" "$REPO_JSON_FILE"; then
    echo "Release metadata is already up to date."
    exit 0
  fi

  git config user.name "${GIT_AUTHOR_NAME:-github-actions[bot]}"
  git config user.email "${GIT_AUTHOR_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
  git add "$LATEST_VERSION_FILE" "$REPO_JSON_FILE"
  git commit -m "Update release metadata for v$app_version"

  if [[ -n "$PUSH_BRANCH" ]]; then
    git push origin "HEAD:$PUSH_BRANCH"
  else
    git push
  fi
fi
