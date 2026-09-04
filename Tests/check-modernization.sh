#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fmodules -mmacosx-version-min=11.0 -framework Cocoa -framework PDFKit \
    -I Sources/Classes -I Sources/TextView -I Sources/LineNumbers -I Other \
    -include Sources/Classes/FRAStandardHeader.h Tests/check-modernization.m \
    Sources/Classes/FRAArchive.m Sources/Classes/FRAPasteboard.m Sources/Classes/FRAPrintTextView.m \
    -o "$test_dir/check-modernization"
"$test_dir/check-modernization" "$test_dir/print.pdf"
