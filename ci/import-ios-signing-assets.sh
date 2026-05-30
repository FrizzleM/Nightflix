#!/usr/bin/env bash
set -euo pipefail

missing=0

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing required secret/env var: ${name}"
    missing=1
  fi
}

decode_base64() {
  if base64 --help 2>&1 | grep -q -- "--decode"; then
    base64 --decode
  else
    base64 -D
  fi
}

emit_env() {
  local name="$1"
  local value="$2"

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    printf "%s=%s\n" "$name" "$value" >> "$GITHUB_ENV"
  else
    printf "export %s=%q\n" "$name" "$value"
  fi
}

require_env IOS_BUILD_CERTIFICATE_BASE64
require_env IOS_P12_PASSWORD
require_env IOS_PROVISION_PROFILE_BASE64
require_env IOS_KEYCHAIN_PASSWORD

if [[ "$missing" -ne 0 ]]; then
  echo "::error::Configure the iOS signing secrets before running an IPA release."
  exit 1
fi

runner_temp="${RUNNER_TEMP:-/tmp/nightflix-signing}"
mkdir -p "$runner_temp"

certificate_path="$runner_temp/build-certificate.p12"
profile_path="$runner_temp/build-profile.mobileprovision"
profile_plist_path="$runner_temp/build-profile.plist"
keychain_path="$runner_temp/nightflix-signing.keychain-db"

rm -f "$keychain_path"

printf "%s" "$IOS_BUILD_CERTIFICATE_BASE64" | decode_base64 > "$certificate_path"
printf "%s" "$IOS_PROVISION_PROFILE_BASE64" | decode_base64 > "$profile_path"

security create-keychain -p "$IOS_KEYCHAIN_PASSWORD" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$IOS_KEYCHAIN_PASSWORD" "$keychain_path"
security import "$certificate_path" \
  -P "$IOS_P12_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$keychain_path"
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$IOS_KEYCHAIN_PASSWORD" \
  "$keychain_path" > /dev/null
security list-keychains -d user -s "$keychain_path"

security cms -D -i "$profile_path" > "$profile_plist_path"
profile_uuid="$(/usr/libexec/PlistBuddy -c "Print UUID" "$profile_plist_path")"
profile_name="$(/usr/libexec/PlistBuddy -c "Print Name" "$profile_plist_path")"
profile_team_id="$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" "$profile_plist_path")"

profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_dir"
cp "$profile_path" "$profile_dir/$profile_uuid.mobileprovision"

emit_env PROVISIONING_PROFILE_NAME "$profile_name"
emit_env DEVELOPMENT_TEAM "${IOS_DEVELOPMENT_TEAM:-$profile_team_id}"

echo "Imported provisioning profile: $profile_name"
