#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Missing Vercel environment variable: SUPABASE_URL" >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing Vercel environment variable: SUPABASE_ANON_KEY" >&2
  exit 1
fi

FLUTTER_VERSION="3.47.7"
FLUTTER_ARCHIVE="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_EXECUTABLE="/tmp/flutter/bin/flutter"

if [[ ! -x "$FLUTTER_EXECUTABLE" ]]; then
  curl --fail --location --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    --output "$FLUTTER_ARCHIVE"
  tar -xf "$FLUTTER_ARCHIVE" -C /tmp
fi

# Flutter runs Git commands from its SDK checkout; Vercel extracts it with a
# different owner, so mark this exact SDK directory as trusted for the build.
git config --global --add safe.directory /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"
flutter --version
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
