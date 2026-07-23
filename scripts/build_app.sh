#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir="$project_dir/dist/SnapCompanion.app"
derived_data="$project_dir/.build/tuist"
signing_identity=${SNAPSYNC_SIGNING_IDENTITY:--}

cd "$project_dir"
mise exec -- tuist generate --no-open
xcodebuild \
    -workspace SnapCompanion.xcworkspace \
    -scheme SnapCompanionApp \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

rm -rf "$app_dir"
mkdir -p "$project_dir/dist"
ditto "$derived_data/Build/Products/Release/SnapCompanion.app" "$app_dir"

plutil -lint "$app_dir/Contents/Info.plist"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$app_dir"
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

print "Built $app_dir"
print "Signed with $signing_identity"
