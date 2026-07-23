#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
staging_dir="$project_dir/dist/dmg-root"
dmg_path="$project_dir/dist/SnapCompanion.dmg"
signing_identity=${SNAPSYNC_SIGNING_IDENTITY:--}

"$script_dir/build_app.sh"

rm -rf "$staging_dir"
mkdir -p "$staging_dir"
ditto "$project_dir/dist/SnapCompanion.app" "$staging_dir/SnapCompanion.app"
ln -sfn /Applications "$staging_dir/Applications"
hdiutil create -volname SnapCompanion -srcfolder "$staging_dir" -format UDZO -ov "$dmg_path"
hdiutil verify "$dmg_path"

if [[ "$signing_identity" != "-" ]]; then
    codesign --force --timestamp --sign "$signing_identity" "$dmg_path"
    codesign --verify --verbose=2 "$dmg_path"
fi

print "Built $dmg_path"
