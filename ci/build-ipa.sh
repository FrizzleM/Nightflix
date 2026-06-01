#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-NightFlix.xcodeproj}"
SCHEME="${SCHEME:-NightFlix}"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCT_NAME="${PRODUCT_NAME:-NightFlix}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-FrizzleM.NightFlix}"
EXPORT_METHOD="${EXPORT_METHOD:-debugging}"
BUILD_ROOT="${BUILD_ROOT:-${RUNNER_TEMP:-$PWD/build}}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_ROOT/$PRODUCT_NAME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$PWD/dist}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$BUILD_ROOT/ExportOptions.plist}"
IPA_NAME="${IPA_NAME:-$PRODUCT_NAME.ipa}"
SIGNING_STYLE="automatic"

if [[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
  PROVISIONING_PROFILE_NAME="$PROVISIONING_PROFILE_SPECIFIER"
fi

if [[ -n "${PROVISIONING_PROFILE_NAME:-}" || -n "${PROVISIONING_PROFILE_UUID:-}" ]]; then
  SIGNING_STYLE="manual"
fi

case "$EXPORT_METHOD" in
  ad-hoc)
    EXPORT_METHOD="release-testing"
    ;;
  app-store)
    EXPORT_METHOD="app-store-connect"
    ;;
  development)
    EXPORT_METHOD="debugging"
    ;;
esac

mkdir -p "$BUILD_ROOT" "$EXPORT_PATH"
rm -f "$EXPORT_PATH"/*.ipa "$EXPORT_PATH"/*.dSYM.zip

write_export_options() {
  local team_id_entry=""
  local provisioning_profiles_entry=""

  if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    team_id_entry=$'	<key>teamID</key>\n	<string>'"$DEVELOPMENT_TEAM"$'</string>\n'
  fi

  if [[ "$SIGNING_STYLE" == "manual" ]]; then
    local profile_specifier="${PROVISIONING_PROFILE_NAME:-${PROVISIONING_PROFILE_UUID:-}}"

    if [[ -z "$profile_specifier" ]]; then
      echo "::error::Manual signing requires PROVISIONING_PROFILE_NAME or PROVISIONING_PROFILE_UUID."
      exit 1
    fi

    provisioning_profiles_entry=$'	<key>provisioningProfiles</key>\n	<dict>\n		<key>'"$BUNDLE_IDENTIFIER"$'</key>\n		<string>'"$profile_specifier"$'</string>\n	</dict>\n'
  fi

  cat > "$EXPORT_OPTIONS_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>method</key>
	<string>$EXPORT_METHOD</string>
	<key>signingStyle</key>
	<string>$SIGNING_STYLE</string>
${team_id_entry}
${provisioning_profiles_entry}
</dict>
</plist>
PLIST
}

write_export_options

package_archive_as_ipa() {
  local app_path="$ARCHIVE_PATH/Products/Applications/$PRODUCT_NAME.app"
  local payload_dir="$BUILD_ROOT/Payload"
  local target_ipa_path="$EXPORT_PATH/$IPA_NAME"

  if [[ ! -d "$app_path" ]]; then
    echo "::error::Archive exists, but $app_path was not found."
    return 1
  fi

  rm -rf "$payload_dir" "$target_ipa_path"
  mkdir -p "$payload_dir"
  ditto "$app_path" "$payload_dir/$PRODUCT_NAME.app"
  ditto -c -k --keepParent "$payload_dir" "$target_ipa_path"

  echo "IPA packaged from signed archive app at $target_ipa_path"
}

archive_args=(
  archive
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  archive_args+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  archive_args+=("CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION")
fi

if [[ -n "${MARKETING_VERSION:-}" ]]; then
  archive_args+=("MARKETING_VERSION=$MARKETING_VERSION")
fi

if [[ "$SIGNING_STYLE" == "manual" ]]; then
  archive_args+=("CODE_SIGN_STYLE=Manual")

  if [[ -n "${PROVISIONING_PROFILE_NAME:-}" ]]; then
    archive_args+=("PROVISIONING_PROFILE_SPECIFIER=$PROVISIONING_PROFILE_NAME")
  elif [[ -n "${PROVISIONING_PROFILE_UUID:-}" ]]; then
    archive_args+=("PROVISIONING_PROFILE=$PROVISIONING_PROFILE_UUID")
  fi
else
  archive_args+=(
    "CODE_SIGN_STYLE=Automatic"
    -allowProvisioningUpdates
  )
fi

xcodebuild "${archive_args[@]}"

if [[ "$EXPORT_METHOD" == "debugging" ]]; then
  package_archive_as_ipa
else
  export_args=(
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  )

  if [[ "$SIGNING_STYLE" == "automatic" ]]; then
    export_args+=(-allowProvisioningUpdates)
  fi

  if ! xcodebuild "${export_args[@]}"; then
    exit 1
  fi
fi

ipa_path="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name "*.ipa" -print -quit)"

if [[ -z "$ipa_path" ]]; then
  echo "::error::No IPA was produced in $EXPORT_PATH."
  exit 1
fi

target_ipa_path="$EXPORT_PATH/$IPA_NAME"

if [[ "$ipa_path" != "$target_ipa_path" ]]; then
  mv "$ipa_path" "$target_ipa_path"
fi

if compgen -G "$ARCHIVE_PATH/dSYMs/*.dSYM" > /dev/null; then
  ditto -c -k --keepParent "$ARCHIVE_PATH/dSYMs" "$EXPORT_PATH/${IPA_NAME%.ipa}.dSYM.zip"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf "ipa_path=%s\n" "$target_ipa_path" >> "$GITHUB_OUTPUT"
  printf "export_path=%s\n" "$EXPORT_PATH" >> "$GITHUB_OUTPUT"
fi

echo "IPA exported to $target_ipa_path"
