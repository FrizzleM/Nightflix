#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-NightFlix.xcodeproj}"
SCHEME="${SCHEME:-NightFlix}"
CONFIGURATION="${CONFIGURATION:-Release}"
PRODUCT_NAME="${PRODUCT_NAME:-NightFlix}"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-FrizzleM.NightFlix}"
EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"
BUILD_ROOT="${BUILD_ROOT:-${RUNNER_TEMP:-$PWD/build}}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_ROOT/$PRODUCT_NAME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$PWD/dist}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$BUILD_ROOT/ExportOptions.plist}"
IPA_NAME="${IPA_NAME:-$PRODUCT_NAME.ipa}"

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
  if [[ -n "${PROVISIONING_PROFILE_NAME:-}" ]]; then
    : "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required when PROVISIONING_PROFILE_NAME is set.}"

    cat > "$EXPORT_OPTIONS_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>method</key>
	<string>$EXPORT_METHOD</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>$BUNDLE_IDENTIFIER</key>
		<string>$PROVISIONING_PROFILE_NAME</string>
	</dict>
	<key>signingStyle</key>
	<string>manual</string>
	<key>teamID</key>
	<string>$DEVELOPMENT_TEAM</string>
</dict>
</plist>
PLIST
  else
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
	<string>automatic</string>
</dict>
</plist>
PLIST
  fi
}

write_export_options

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

if [[ -n "${PROVISIONING_PROFILE_NAME:-}" ]]; then
  archive_args+=(
    "CODE_SIGN_STYLE=Manual"
    "PROVISIONING_PROFILE_SPECIFIER=$PROVISIONING_PROFILE_NAME"
  )
else
  archive_args+=(-allowProvisioningUpdates)
fi

xcodebuild "${archive_args[@]}"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

ipa_path="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name "*.ipa" -print -quit)"

if [[ -z "$ipa_path" ]]; then
  echo "::error::xcodebuild completed but no IPA was produced in $EXPORT_PATH."
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
