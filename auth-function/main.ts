// Discord OAuth -> Firebase Custom Token
// Deploy to Deno Deploy or run locally with: deno run --allow-net --allow-env --allow-read main.ts

import { encode as base64UrlEncode } from "https://deno.land/std@0.208.0/encoding/base64url.ts";

const PROJECT_ID = "watermarking-4a428";

// Discord OAuth config - set these environment variables
const DISCORD_CLIENT_ID = Deno.env.get("DISCORD_CLIENT_ID") || "";
const DISCORD_CLIENT_SECRET = Deno.env.get("DISCORD_CLIENT_SECRET") || "";
const DISCORD_REDIRECT_URI = Deno.env.get("DISCORD_REDIRECT_URI") || "";

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

let serviceAccount: ServiceAccount | null = null;
let accessToken: string | null = null;
let tokenExpiry = 0;

function loadServiceAccount() {
  if (serviceAccount) return;

  const serviceAccountPath = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (serviceAccountPath) {
    serviceAccount = JSON.parse(Deno.readTextFileSync(serviceAccountPath));
  } else {
    // Try loading from environment variable directly (for Deno Deploy)
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (serviceAccountJson) {
      serviceAccount = JSON.parse(serviceAccountJson);
    }
  }

  if (!serviceAccount) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_JSON required");
  }
}

// Create a signed JWT for Google OAuth (for Firestore access)
async function createSignedJwt(scopes: string): Promise<string> {
  loadServiceAccount();
  if (!serviceAccount) throw new Error("Service account not initialized");

  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: expiry,
    scope: scopes,
  };

  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  const pemContents = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signatureB64 = base64UrlEncode(new Uint8Array(signature));
  return `${unsignedToken}.${signatureB64}`;
}

// Get OAuth access token for Firestore (with caching)
async function getAccessToken(): Promise<string> {
  if (accessToken && Date.now() < tokenExpiry - 60000) {
    return accessToken;
  }

  const jwt = await createSignedJwt("https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit");

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to get access token: ${error}`);
  }

  const data = await response.json();
  accessToken = data.access_token;
  tokenExpiry = Date.now() + data.expires_in * 1000;

  return accessToken!;
}

// Create Firebase Custom Token (for client-side signInWithCustomToken)
async function createCustomToken(uid: string): Promise<string> {
  loadServiceAccount();
  if (!serviceAccount) throw new Error("Service account not initialized");

  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // 1 hour

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
    iat: now,
    exp: expiry,
    uid: uid,
    claims: {
      provider: "discord",
    },
  };

  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const unsignedToken = `${headerB64}.${payloadB64}`;

  const pemContents = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signatureB64 = base64UrlEncode(new Uint8Array(signature));
  return `${unsignedToken}.${signatureB64}`;
}

// Firestore: Get document
async function firestoreGetDocument(
  collection: string,
  docId: string
): Promise<Record<string, unknown> | null> {
  const token = await getAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (response.status === 404) return null;
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Firestore get failed: ${error}`);
  }

  const doc = await response.json();
  return fromFirestoreFields(doc.fields || {});
}

// Firestore: Set document
async function firestoreSetDocument(
  collection: string,
  docId: string,
  data: Record<string, unknown>
): Promise<void> {
  const token = await getAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;

  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Firestore set failed: ${error}`);
  }
}

// Create Firebase Auth user
async function createFirebaseUser(
  uid: string,
  discordId: string,
  discordUsername: string,
  avatarUrl?: string
): Promise<void> {
  const token = await getAccessToken();
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      localId: uid,
      displayName: discordUsername,
      photoUrl: avatarUrl,
      customAttributes: JSON.stringify({
        discordId,
        provider: "discord",
      }),
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create Firebase user: ${error}`);
  }
}

// Firestore field conversion helpers
function toFirestoreValue(value: unknown): Record<string, unknown> {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === "boolean") return { booleanValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (value === "SERVER_TIMESTAMP") {
    return { timestampValue: new Date().toISOString() };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFirestoreFields(value as Record<string, unknown>) } };
  }
  return { stringValue: String(value) };
}

function toFirestoreFields(obj: Record<string, unknown>): Record<string, unknown> {
  const fields: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

function fromFirestoreValue(value: Record<string, unknown>): unknown {
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return parseInt(value.integerValue as string, 10);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return new Date(value.timestampValue as string);
  if ("arrayValue" in value) {
    const arr = value.arrayValue as { values?: Record<string, unknown>[] };
    return (arr.values || []).map(fromFirestoreValue);
  }
  if ("mapValue" in value) {
    const map = value.mapValue as { fields?: Record<string, Record<string, unknown>> };
    return fromFirestoreFields(map.fields || {});
  }
  return null;
}

function fromFirestoreFields(fields: Record<string, Record<string, unknown>>): Record<string, unknown> {
  const obj: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    obj[key] = fromFirestoreValue(value);
  }
  return obj;
}

// Discord OAuth: exchange code for token
async function exchangeDiscordCode(code: string): Promise<{ accessToken: string }> {
  const response = await fetch("https://discord.com/api/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: DISCORD_CLIENT_ID,
      client_secret: DISCORD_CLIENT_SECRET,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: DISCORD_REDIRECT_URI,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Discord token exchange failed: ${error}`);
  }

  const data = await response.json();
  return { accessToken: data.access_token };
}

// Discord: get user info
async function getDiscordUser(accessToken: string): Promise<{
  id: string;
  username: string;
  avatar: string | null;
}> {
  const response = await fetch("https://discord.com/api/users/@me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Discord user fetch failed: ${error}`);
  }

  return await response.json();
}

// Get or create Firebase user for Discord account
async function getOrCreateFirebaseUser(
  discordId: string,
  discordUsername: string,
  avatarUrl?: string
): Promise<string> {
  // Check if user already exists
  const existingDoc = await firestoreGetDocument("discordUsers", discordId);
  if (existingDoc?.firebaseUid) {
    return existingDoc.firebaseUid as string;
  }

  // Create new user
  const uid = crypto.randomUUID();

  await createFirebaseUser(uid, discordId, discordUsername, avatarUrl);

  // Store mappings
  await firestoreSetDocument("users", uid, {
    discordId,
    discordUsername,
    createdAt: "SERVER_TIMESTAMP",
    provider: "discord",
  });

  await firestoreSetDocument("discordUsers", discordId, {
    firebaseUid: uid,
    discordUsername,
  });

  console.log(`Created Firebase user ${uid} for Discord user ${discordUsername} (${discordId})`);
  return uid;
}

// CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// Main handler
async function handler(req: Request): Promise<Response> {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // GET /auth/discord/url - return Discord OAuth URL for redirect
  if (req.method === "GET" && url.pathname === "/auth/discord/url") {
    const state = crypto.randomUUID();
    const discordUrl = new URL("https://discord.com/api/oauth2/authorize");
    discordUrl.searchParams.set("client_id", DISCORD_CLIENT_ID);
    discordUrl.searchParams.set("redirect_uri", DISCORD_REDIRECT_URI);
    discordUrl.searchParams.set("response_type", "code");
    discordUrl.searchParams.set("scope", "identify");
    discordUrl.searchParams.set("state", state);

    return new Response(JSON.stringify({ url: discordUrl.toString(), state }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // POST /auth/discord - exchange code for Firebase custom token
  if (req.method === "POST" && url.pathname === "/auth/discord") {
    try {
      const body = await req.json();
      const { code } = body;

      if (!code) {
        return new Response(JSON.stringify({ error: "Missing code" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Exchange Discord code for access token
      const { accessToken: discordToken } = await exchangeDiscordCode(code);

      // Get Discord user info
      const discordUser = await getDiscordUser(discordToken);

      // Build avatar URL
      const avatarUrl = discordUser.avatar
        ? `https://cdn.discordapp.com/avatars/${discordUser.id}/${discordUser.avatar}.png`
        : null;

      // Get or create Firebase user
      const firebaseUid = await getOrCreateFirebaseUser(
        discordUser.id,
        discordUser.username,
        avatarUrl || undefined
      );

      // Create Firebase custom token
      const customToken = await createCustomToken(firebaseUid);

      return new Response(JSON.stringify({ customToken }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Auth error:", error);
      return new Response(JSON.stringify({ error: String(error) }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  // Health check
  if (req.method === "GET" && url.pathname === "/") {
    return new Response("OK", { headers: corsHeaders });
  }

  return new Response("Not found", { status: 404, headers: corsHeaders });
}

// Start server
Deno.serve({ port: 8000 }, handler);
