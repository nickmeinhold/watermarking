# Tindart Smart Contracts

ERC-721 NFT contract with integrated marketplace for Tindart.

## Features

- **License Types**: Display, Commercial, Full Transfer
- **Duplicate Prevention**: Image hash uniqueness check
- **Integrated Marketplace**: List, delist, buy
- **Royalties**: 2.5% to creator on secondary sales (EIP-2981)
- **Platform Fee**: 2.5% on all sales

## Setup

```bash
npm install
cp .env.example .env
# Edit .env with your keys
```

## Commands

```bash
# Compile contracts
npm run compile

# Run tests
npm test

# Start local node
npm run node

# Deploy to local node (in separate terminal)
npm run deploy:local

# Deploy to Mumbai testnet
npm run deploy:mumbai

# Deploy to Polygon mainnet
npm run deploy:polygon
```

## Contract Functions

### Minting

```solidity
function mint(
    address to,
    string memory uri,
    LicenseType licenseType,    // 0=Display, 1=Commercial, 2=Transfer
    bytes32 imageHash,          // SHA-256 of original image
    bytes32 licenseHash,        // SHA-256 of signed license
    string memory encryptedBlobUri
) external returns (uint256 tokenId)
```

### Marketplace

```solidity
function list(uint256 tokenId, uint256 price) external
function delist(uint256 tokenId) external
function buy(uint256 tokenId) external payable
```

### View

```solidity
function getTokenData(uint256 tokenId) external view returns (...)
function getListing(uint256 tokenId) external view returns (...)
function isImageRegistered(bytes32 imageHash) external view returns (bool)
```

## Deployment Addresses

| Network | Address |
|---------|---------|
| Polygon Mumbai | TBD |
| Polygon Mainnet | TBD |
