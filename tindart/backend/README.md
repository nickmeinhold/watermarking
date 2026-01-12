# Tindart Backend API

Node.js API for watermarking, encryption, IPFS upload, and NFT minting.

## Endpoints

### Public

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/api/verify/:tokenId` | Get token verification info |
| GET | `/api/verify/:tokenId/history` | Get detection history |
| GET | `/api/verify/check/:imageHash` | Check if image is registered |

### Authenticated (SIWE)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/mint` | Watermark + encrypt + mint NFT |
| GET | `/api/mint/price` | Get minting prices |
| GET | `/api/mint/license/:type` | Get license agreement text |
| POST | `/api/detect` | Run watermark detection |

## Setup

```bash
npm install
cp .env.example .env
# Edit .env with your configuration
```

## Prerequisites

1. **Watermark binaries** - Compile from `../watermarking-functions/`:
   ```bash
   cd ../watermarking-functions
   # Follow compilation instructions
   ```

2. **Firebase** - Service account JSON in `keys/firebase-service-account.json`

3. **Pinata** - Create account at pinata.cloud, get JWT

4. **Polygon wallet** - Fund with MATIC for gas

5. **Smart contract** - Deploy TindartNFT and set address in .env

## Run

```bash
# Development
npm run dev

# Production
npm start
```

## Authentication

Uses Sign-In with Ethereum (SIWE). Client must:

1. Create SIWE message
2. Sign with wallet
3. Send as Bearer token: `base64({ message, signature })`

Example:
```javascript
const message = new SiweMessage({
  domain: 'tindart.com',
  address: wallet.address,
  statement: 'Sign in to Tindart',
  uri: 'https://api.tindart.com',
  version: '1',
  chainId: 137
});

const signature = await wallet.signMessage(message.prepareMessage());

const token = btoa(JSON.stringify({
  message: message.prepareMessage(),
  signature
}));

// Use in requests
fetch('/api/mint', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

## Minting Flow

```
POST /api/mint
Content-Type: multipart/form-data
Authorization: Bearer <siwe-token>

- image: <file>
- name: "Artwork Title"
- description: "Optional description"
- licenseType: "display" | "commercial" | "transfer"
- licenseSignature: <wallet signature of license text>

Response:
{
  "success": true,
  "tokenId": 42,
  "transactionHash": "0x...",
  "watermarkId": "TIND12345678",
  "encryptedBlobUri": "ipfs://...",
  "previewUri": "ipfs://...",
  "metadataUri": "ipfs://..."
}
```

## Architecture

```
src/
├── index.js              # Express app setup
├── middleware/
│   └── auth.js           # SIWE authentication
├── routes/
│   ├── mint.js           # Minting endpoints
│   ├── detect.js         # Detection endpoints
│   └── verify.js         # Public verification
└── services/
    ├── watermark.js      # C++ binary wrapper
    ├── encryption.js     # KMS/AES encryption
    ├── ipfs.js           # Pinata upload
    ├── blockchain.js     # Polygon contract interaction
    ├── firestore.js      # Firebase database
    └── duplicate.js      # Duplicate detection
```

## Cost Estimates

| Operation | Cost |
|-----------|------|
| Mint (Polygon gas) | ~$0.01 |
| IPFS pin (2 files) | ~$0.01 |
| KMS operation | ~$0.001 |
| **Total per mint** | ~$0.02 |
