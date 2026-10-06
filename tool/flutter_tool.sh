#!/usr/bin/env bash
# Runs a flutter_tools command from WSL against the Windows Flutter SDK.
#
# The SDK's own `flutter` wrapper is a bash script with CRLF line endings, so bash
# chokes on it from Linux. The Dart entry point works; it just has to be reached
# through a Windows path, because the SDK is a Windows one.
set -euo pipefail

DART='/mnt/c/develop/flutter/bin/cache/dart-sdk/bin/dart.exe'
PACKAGES='C:\develop\flutter\packages\flutter_tools\.dart_tool\package_config.json'
TOOLS='C:\develop\flutter\packages\flutter_tools\bin\flutter_tools.dart'

cd /mnt/d/kiosk_mind
exec "$DART" --packages="$PACKAGES" "$TOOLS" "$@"