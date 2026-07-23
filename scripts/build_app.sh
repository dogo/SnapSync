#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
app_dir="$project_dir/dist/SnapSync.app"
contents_dir="$app_dir/Contents"
signing_identity=${SNAPSYNC_SIGNING_IDENTITY:--}

cd "$project_dir"
swift build -c release --product SnapSyncApp
bin_dir=$(swift build -c release --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
install -m 755 "$bin_dir/SnapSyncApp" "$contents_dir/MacOS/SnapSync"
install -m 644 "$project_dir/Packaging/Info.plist" "$contents_dir/Info.plist"
install -m 644 "$project_dir/Sources/SnapSyncApp/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"

for resource_bundle in "$bin_dir"/*.bundle(N); do
    ditto "$resource_bundle" "$contents_dir/Resources/${resource_bundle:t}"
done

plutil -lint "$contents_dir/Info.plist"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --sign - "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$signing_identity" "$app_dir"
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

print "Built $app_dir"
print "Signed with $signing_identity"
