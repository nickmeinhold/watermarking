# Auth Function

Deno edge function that handles Discord OAuth and returns Firebase custom tokens.

## Deployed URL

https://watermarking-auth.deno.dev

## Environment Variables

Configure these in the [Deno Deploy dashboard](https://dash.deno.com/projects/watermarking-auth/settings):

| Variable | Description |
|----------|-------------|
| `DISCORD_CLIENT_ID` | From Discord Developer Portal → OAuth2 |
| `DISCORD_CLIENT_SECRET` | From Discord Developer Portal → OAuth2 → Reset Secret |
| `DISCORD_REDIRECT_URI` | `https://watermarking-4a428.web.app/opening` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Paste the entire service account JSON |

## Firebase Service Account

The Firebase service account JSON is located at:
```
~/git/experiments/disrupt/firebase-service-account.json
```

Copy its contents into the `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable.

## Discord Developer Portal Setup

1. Go to https://discord.com/developers/applications
2. Select your application
3. OAuth2 → Add redirect URI: `https://watermarking-4a428.web.app/opening`

## Local Development

```bash
export DISCORD_CLIENT_ID="your_id"
export DISCORD_CLIENT_SECRET="your_secret"
export DISCORD_REDIRECT_URI="http://localhost:5000/opening"
export FIREBASE_SERVICE_ACCOUNT="/path/to/firebase-service-account.json"

deno task dev
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Health check |
| GET | `/auth/discord/url` | Get Discord OAuth URL |
| POST | `/auth/discord` | Exchange code for Firebase custom token |

## Flow

```
Web App                     Auth Function                    Discord
   │                             │                              │
   │── Click Discord Login ─────►│                              │
   │                             │                              │
   │◄─ Redirect to Discord ──────│                              │
   │                                                            │
   │─────────── OAuth consent ─────────────────────────────────►│
   │◄────────── ?code= ────────────────────────────────────────│
   │                             │                              │
   │── POST /auth/discord ──────►│                              │
   │                             │── Exchange code ────────────►│
   │                             │◄─ Discord user ID ──────────│
   │                             │                              │
   │                             │── Lookup discordUsers/{id} ─►│ Firestore
   │                             │◄─ firebaseUid ──────────────│
   │                             │                              │
   │◄─ Firebase Custom Token ───│                              │
   │                             │                              │
   │── signInWithCustomToken() ─►│ Firebase Auth                │
```
