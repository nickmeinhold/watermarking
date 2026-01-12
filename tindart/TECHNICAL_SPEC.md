# Tindart Technical Specification

AI art marketplace with verifiable provenance, watermark-based authentication, and clear copyright licensing.

## Problem Statement

1. **NFTs don't convey ownership** - buying an NFT doesn't transfer copyright or usage rights
2. **AI art has no provenance** - anyone can generate similar images, no way to prove who created first
3. **Stolen art is rampant** - images are re-minted without consequences
4. **Physical art lacks accessible authentication** - expensive gallery systems, easily forged certificates

## Solution

Combine invisible watermarking + NFT minting + legal licensing into a single $1 transaction.

```
Artist uploads image
       ↓
Watermark embedded (with unique ID)
       ↓
Image encrypted (artist keeps encrypted blob)
       ↓
NFT minted with license terms (signed by artist)
       ↓
Key stored in KMS (linked to tokenId)
       ↓
Listed on marketplace
       ↓
Buyer purchases → gets NFT + encrypted blob + clear legal rights
       ↓
Anyone can verify authenticity via watermark detection
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Tindart Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Frontend   │  │   Backend    │  │   Watermark Engine   │  │
│  │  (Flutter)   │  │  (Node.js)   │  │       (C++)          │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
│         └────────────┬────┴──────────────────────┘              │
│                      │                                          │
├──────────────────────┼──────────────────────────────────────────┤
│                      ▼                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Polygon    │  │  Cloud KMS   │  │        IPFS          │  │
│  │  Blockchain  │  │   (Keys)     │  │  (Encrypted Blobs)   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Watermark Engine (Existing)

Reuse `watermarking-functions/` C++ library:
- DFT-based Legendre sequence embedding
- Survives print-and-scan
- Non-blind detection (requires encrypted original)

### 2. Smart Contract (ERC-721)

```solidity
// Polygon deployment
contract TindartNFT is ERC721, ERC721URIStorage {
    struct TokenData {
        string licenseType;      // "display" | "commercial" | "transfer"
        bytes32 imageHash;       // SHA-256 of original
        bytes32 licenseHash;     // SHA-256 of signed license
        uint256 mintedAt;
    }

    mapping(uint256 => TokenData) public tokenData;

    function mint(
        address to,
        string memory uri,
        string memory licenseType,
        bytes32 imageHash,
        bytes32 licenseHash
    ) public returns (uint256);
}
```

### 3. Key Management

```
Cloud KMS (Google)
├── Master key (one, encrypts per-image keys)
└── Per-image keys (stored encrypted in Firestore)

Firestore: keys/{tokenId}
{
  encryptedKey: "base64...",    // Encrypted with master key
  imageHash: "sha256:...",      // Verify correct image
  created: timestamp
}
```

### 4. Encrypted Original Storage

```
IPFS (public, encrypted)
├── /encrypted/{tokenId}        // Encrypted original image
├── /previews/{tokenId}         // Visible preview/thumbnail
└── /licenses/{tokenId}         // Signed license document

NFT Metadata:
{
  "name": "Artwork Title",
  "image": "ipfs://Qm.../preview.jpg",
  "encrypted_original": "ipfs://Qm.../encrypted",
  "license": "ipfs://Qm.../license.pdf",
  "license_type": "commercial",
  "image_hash": "sha256:..."
}
```

### 5. License Types

| Type | Rights Granted | Price Modifier |
|------|----------------|----------------|
| `display` | Personal display, resale of NFT | Base ($1) |
| `commercial` | Monetization, merchandise, derivatives | +$4 ($5) |
| `transfer` | Full copyright transfer to buyer | +$9 ($10) |

### 6. Detection Service

```
POST /api/detect
{
  "tokenId": "4582",
  "capturedImage": "base64...",
  "wallet": "0x..."
}

Response:
{
  "detected": true,
  "confidence": 8.2,
  "message": "TIND4582",
  "owner": "0x...",
  "license": "commercial"
}
```

Access control:
- Anyone can request detection
- Results include current owner + license type
- Enables third-party verification

## User Flows

### Mint Flow

```
1. User connects wallet
2. Uploads image
3. System checks for duplicates (perceptual hash)
4. User selects license type
5. User signs license agreement (wallet signature)
6. System:
   a. Embeds watermark (unique ID)
   b. Computes image hash
   c. Encrypts original
   d. Generates per-image key
   e. Uploads encrypted blob to IPFS
   f. Uploads preview to IPFS
   g. Stores encrypted key in Firestore
   h. Mints NFT on Polygon
7. User receives:
   - NFT in wallet
   - Encrypted original (IPFS link)
   - Transaction receipt
```

### Purchase Flow

```
1. Buyer browses marketplace
2. Sees artwork + license type + price
3. Clicks "Buy"
4. Signs transaction (wallet)
5. NFT transfers on-chain
6. Buyer now:
   - Owns the NFT
   - Can download encrypted original from IPFS
   - Has rights per the license type
   - Can request detection to prove ownership
```

### Verification Flow

```
1. Anyone photographs suspected artwork
2. Uploads to Tindart verification page
3. System:
   a. Checks all registered images
   b. Runs watermark detection against matches
4. Returns:
   - Original registered owner
   - Current NFT owner
   - License type
   - Registration date
   - Confidence score
```

## Stolen Art Detection

### At Upload

```python
def check_stolen(image):
    # 1. Exact hash match
    if hash_exists(sha256(image)):
        return REJECT, "Exact duplicate exists"

    # 2. Perceptual hash match
    phash = compute_phash(image)
    matches = find_similar(phash, threshold=0.95)
    if matches:
        return REJECT, f"Too similar to #{matches[0].id}"

    # 3. Reverse image search (optional)
    external = reverse_search(image)
    if external:
        return FLAG, "Found online - verify ownership"

    return ALLOW
```

### At Detection Request

If watermark detected in commercial use:
1. Generate forensic report
2. Notify registered owner
3. Provide DMCA template

## Physical Art Support

```
Physical artwork
       ↓
Artist photographs (high-res)
       ↓
Standard mint flow
       ↓
Artist prints QR code sticker
       ↓
Attaches to back of artwork
       ↓
Anyone can scan → verify → see provenance

QR Code links to:
https://tindart.com/verify/{tokenId}

Page shows:
- Artwork image
- Artist info
- Current owner
- License type
- Full provenance history
```

## Database Schema

### Firestore Collections

```
/users/{walletAddress}
{
  displayName: string,
  email: string (optional),
  created: timestamp,
  totalMints: number,
  totalSales: number
}

/tokens/{tokenId}
{
  contractAddress: string,
  owner: walletAddress,
  creator: walletAddress,
  imageHash: string,
  encryptedBlobUrl: string,
  previewUrl: string,
  licenseType: "display" | "commercial" | "transfer",
  licenseHash: string,
  price: number (if listed),
  created: timestamp,
  lastTransfer: timestamp
}

/keys/{tokenId}
{
  encryptedKey: string,      // Encrypted with KMS master key
  imageHash: string,
  created: timestamp
}

/detections/{detectionId}
{
  tokenId: string,
  requester: walletAddress,
  capturedImageHash: string,
  result: boolean,
  confidence: number,
  timestamp: timestamp
}
```

## API Endpoints

### Public

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/tokens` | GET | List tokens (paginated) |
| `/api/tokens/{id}` | GET | Get token details |
| `/api/verify/{id}` | GET | Public verification page |
| `/api/detect` | POST | Run watermark detection |

### Authenticated (wallet signature required)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/mint` | POST | Mint new token |
| `/api/list` | POST | List token for sale |
| `/api/delist` | POST | Remove listing |
| `/api/my/tokens` | GET | User's tokens |
| `/api/my/sales` | GET | User's sales history |

## Revenue Model

| Service | Price | Margin |
|---------|-------|--------|
| Basic mint (display license) | $1 | ~$0.65 |
| Commercial license mint | $5 | ~$4.30 |
| Full transfer mint | $10 | ~$9.30 |
| Marketplace sale | 2.5% fee | 2.5% |
| Forensic report | $50 | ~$45 |
| Bulk copyright registration | $5/image | ~$4.90 |

### Cost Breakdown (per mint)

| Item | Cost |
|------|------|
| Polygon gas | ~$0.01 |
| IPFS pinning | ~$0.01 |
| KMS operation | ~$0.001 |
| Stripe fee (on $1) | ~$0.33 |
| Compute (watermark) | ~$0.01 |
| **Total** | ~$0.36 |

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter Web |
| Backend | Node.js (Cloud Run) |
| Watermarking | C++ (existing engine) |
| Blockchain | Polygon (ERC-721) |
| Wallet | WalletConnect / MetaMask |
| Storage | IPFS (Pinata) + Firestore |
| Key Management | Google Cloud KMS |
| Payments | Stripe |
| Auth | Wallet signature (SIWE) |

## Security Considerations

### Key Management
- Master key never leaves KMS HSM
- Per-image keys encrypted at rest
- Key access logged (Cloud Audit Logs)

### Encrypted Originals
- AES-256 encryption
- Stored on IPFS (public but useless without key)
- Decryption only via API (ownership verified)

### Wallet Authentication
- Sign-In with Ethereum (SIWE) standard
- Signatures verified server-side
- No password storage

### Smart Contract
- Use OpenZeppelin audited base contracts
- Professional audit before mainnet
- Upgradeable proxy pattern (optional)

## MVP Scope

### Phase 1: Core (8-12 weeks)
- [ ] Smart contract deployment (Polygon testnet)
- [ ] Basic mint flow (upload → watermark → encrypt → mint)
- [ ] Wallet connection (MetaMask)
- [ ] Token gallery view
- [ ] Basic detection endpoint

### Phase 2: Marketplace (4-6 weeks)
- [ ] List/buy functionality
- [ ] Payment integration (crypto only first)
- [ ] User profiles
- [ ] Search/filter

### Phase 3: Trust & Safety (4-6 weeks)
- [ ] Duplicate detection at upload
- [ ] Reporting system
- [ ] Forensic reports
- [ ] DMCA process

### Phase 4: Growth (ongoing)
- [ ] Fiat payments (Stripe)
- [ ] Mobile app
- [ ] Physical art QR codes
- [ ] Copyright registration integration
- [ ] API for third-party verification

## Open Questions

1. **Pricing strategy** - Is $1 too low? Should commercial licenses cost more?
2. **Chain choice** - Polygon vs Base vs Arbitrum?
3. **Detection access** - Free for everyone or paid/rate-limited?
4. **Dispute resolution** - How to handle conflicting ownership claims?
5. **AI detection** - Should we detect/flag AI-generated images (SynthID)?
