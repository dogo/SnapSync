#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
catalog="$project_dir/Sources/SnapSyncApp/Resources/Localizable.xcstrings"

mkdir -p "$project_dir/Sources/SnapSyncApp/Generated"
xcrun xcstringstool generate-symbols "$catalog" \
    --output-directory "$project_dir/Sources/SnapSyncApp/Generated" \
    --language swift
xcrun xcstringstool compile "$catalog" \
    --output-directory "$project_dir/Sources/SnapSyncApp/Resources"
