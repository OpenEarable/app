#!/bin/bash
# Archive on GitHub, then let Xcode sign and upload using the existing Apple API key.
set -euo pipefail

platform="$1"
app_dir="$2"
output_dir="$3"
case "$platform" in
  ios) destination='generic/platform=iOS' ;;
  macos) destination='generic/platform=macOS' ;;
  *) echo "Unsupported Apple platform: $platform" >&2; exit 1 ;;
esac

mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
cd "$app_dir"
# Three numeric components, each within Apple's digit limits. Reruns get a new
# increasing build number, including when a different workflow releases the tag.
build_number=$(date -u '+%y%m.%d%H.%M%S' | awk -F. '{printf "%d.%d.%d\n", $1, $2, $3}')
printf 'build_number=%s\n' "$build_number" >> "$GITHUB_OUTPUT"
printf 'Building %s from %s as %s\n' "$platform" "$(git rev-parse HEAD)" "$build_number"

config_args=("$platform" --release --config-only --build-number="$build_number")
if [[ "$platform" == ios ]]; then config_args+=(--no-codesign); fi
flutter build "${config_args[@]}"
(cd "$platform" && pod install)

xcodebuild archive -hideShellScriptEnvironment \
  -workspace "$platform/Runner.xcworkspace" -scheme Runner \
  -configuration Release -destination "$destination" \
  -archivePath "$output_dir/Runner.xcarchive" \
  -resultBundlePath "$output_dir/archive.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$output_dir/archive.log"

# Only the ephemeral runner sees this file. It is never included in artifacts.
key_dir=$(mktemp -d "$RUNNER_TEMP/apple-api.XXXXXX")
trap 'rm -rf "$key_dir"' EXIT
export APPLE_API_KEY_PATH="$key_dir/AuthKey.p8"
ruby -rbase64 -e '
  key = ENV.fetch("APP_STORE_CONNECT_PRIVATE_KEY").gsub("\\n", "\n").strip
  key = Base64.strict_decode64(key) unless key.include?("BEGIN")
  File.write(ENV.fetch("APPLE_API_KEY_PATH"), key, perm: 0600)
'
cat > "$output_dir/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>6DCQ69GP5G</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$output_dir/Runner.xcarchive" \
  -exportOptionsPlist "$output_dir/ExportOptions.plist" \
  -exportPath "$output_dir/export" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$APPLE_API_KEY_PATH" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" \
  2>&1 | tee "$output_dir/upload.log"
