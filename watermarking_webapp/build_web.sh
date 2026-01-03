#!/bin/bash
flutter build web --release --source-maps \
  --dart-define=DISCORD_CLIENT_ID=1454401130611216507 \
  --dart-define=AUTH_FUNCTION_URL=https://watermarking-auth.deno.dev
