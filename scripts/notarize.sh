#!/bin/zsh

set -euo pipefail

: "${SNAPSYNC_SIGNING_IDENTITY:?Set SNAPSYNC_SIGNING_IDENTITY to your Developer ID Application identity}"
: "${SNAPSYNC_NOTARY_PROFILE:?Set SNAPSYNC_NOTARY_PROFILE to your notarytool Keychain profile}"

if [[ "$SNAPSYNC_SIGNING_IDENTITY" == "-" ]]; then
    print -u2 "Developer ID Application is required; ad hoc signing cannot be notarized"
    exit 1
fi

script_dir=${0:A:h}
project_dir=${script_dir:h}
dmg_path="$project_dir/dist/SnapCompanion.dmg"

security find-identity -v -p codesigning | grep -Fq "$SNAPSYNC_SIGNING_IDENTITY"
"$script_dir/build_dmg.sh"
xcrun notarytool submit "$dmg_path" --keychain-profile "$SNAPSYNC_NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose "$dmg_path"

print "Notarized $dmg_path"
