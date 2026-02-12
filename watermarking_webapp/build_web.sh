#!/bin/bash
flutter build web --release --source-maps \
  --dart-define=DISCORD_CLIENT_ID=1454401130611216507 \
  --dart-define=AUTH_FUNCTION_URL=https://watermarking-auth.deno.dev \
  --dart-define=WATERMARKING_API_KEY=${WATERMARKING_API_KEY} \
  --dart-define=WATERMARKING_API_URL=https://watermarking-api-78940960204.us-central1.run.app
