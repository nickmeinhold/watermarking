/**
 * Blockchain Service
 * Handles NFT minting on Polygon
 */

const { ethers } = require('ethers');

// Contract ABI (minimal, just what we need)
const TINDART_ABI = [
  'function mint(address to, string uri, uint8 licenseType, bytes32 imageHash, bytes32 licenseHash, string encryptedBlobUri) returns (uint256)',
  'function ownerOf(uint256 tokenId) view returns (address)',
  'function tokenURI(uint256 tokenId) view returns (string)',
  'function getTokenData(uint256 tokenId) view returns (address creator, address currentOwner, uint8 licenseType, bytes32 imageHash, bytes32 licenseHash, uint256 mintedAt, string encryptedBlobUri, string uri)',
  'function isImageRegistered(bytes32 imageHash) view returns (bool)',
  'function totalSupply() view returns (uint256)',
  'event Minted(uint256 indexed tokenId, address indexed creator, uint8 licenseType, bytes32 imageHash)'
];

const RPC_URL = process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com';
const CONTRACT_ADDRESS = process.env.TINDART_CONTRACT_ADDRESS;
const MINTER_PRIVATE_KEY = process.env.MINTER_PRIVATE_KEY;

let provider = null;
let wallet = null;
let contract = null;

function getProvider() {
  if (!provider) {
    provider = new ethers.JsonRpcProvider(RPC_URL);
  }
  return provider;
}

function getWallet() {
  if (!wallet) {
    if (!MINTER_PRIVATE_KEY) {
      throw new Error('MINTER_PRIVATE_KEY environment variable required');
    }
    wallet = new ethers.Wallet(MINTER_PRIVATE_KEY, getProvider());
  }
  return wallet;
}

function getContract() {
  if (!contract) {
    if (!CONTRACT_ADDRESS) {
      throw new Error('TINDART_CONTRACT_ADDRESS environment variable required');
    }
    contract = new ethers.Contract(CONTRACT_ADDRESS, TINDART_ABI, getWallet());
  }
  return contract;
}

/**
 * Mint a new NFT
 * @param {string} to - Recipient wallet address
 * @param {string} uri - Token metadata URI (IPFS)
 * @param {number} licenseType - 0=Display, 1=Commercial, 2=Transfer
 * @param {string} imageHash - SHA-256 hash of original image (0x prefixed)
 * @param {string} licenseHash - SHA-256 hash of license document (0x prefixed)
 * @param {string} encryptedBlobUri - IPFS URI of encrypted original
 * @returns {Promise<{tokenId: number, transactionHash: string}>}
 */
async function mint(to, uri, licenseType, imageHash, licenseHash, encryptedBlobUri) {
  const tindart = getContract();

  console.log('Minting NFT...');
  console.log('  To:', to);
  console.log('  URI:', uri);
  console.log('  License:', licenseType);

  // Estimate gas first
  const gasEstimate = await tindart.mint.estimateGas(
    to,
    uri,
    licenseType,
    imageHash,
    licenseHash,
    encryptedBlobUri
  );

  console.log('  Gas estimate:', gasEstimate.toString());

  // Send transaction with 20% gas buffer
  const tx = await tindart.mint(
    to,
    uri,
    licenseType,
    imageHash,
    licenseHash,
    encryptedBlobUri,
    {
      gasLimit: gasEstimate * 120n / 100n
    }
  );

  console.log('  Transaction hash:', tx.hash);

  // Wait for confirmation
  const receipt = await tx.wait();

  // Parse Minted event to get tokenId
  const mintedEvent = receipt.logs
    .map(log => {
      try {
        return tindart.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find(event => event?.name === 'Minted');

  if (!mintedEvent) {
    throw new Error('Minted event not found in transaction receipt');
  }

  const tokenId = Number(mintedEvent.args.tokenId);

  console.log('  Token ID:', tokenId);
  console.log('  Block:', receipt.blockNumber);

  return {
    tokenId,
    transactionHash: tx.hash,
    blockNumber: receipt.blockNumber
  };
}

/**
 * Check if a wallet owns a specific token
 */
async function isOwner(tokenId, walletAddress) {
  const tindart = getContract();
  const owner = await tindart.ownerOf(tokenId);
  return owner.toLowerCase() === walletAddress.toLowerCase();
}

/**
 * Get token data
 */
async function getTokenData(tokenId) {
  const tindart = getContract();
  const data = await tindart.getTokenData(tokenId);

  return {
    creator: data.creator,
    currentOwner: data.currentOwner,
    licenseType: Number(data.licenseType),
    imageHash: data.imageHash,
    licenseHash: data.licenseHash,
    mintedAt: new Date(Number(data.mintedAt) * 1000),
    encryptedBlobUri: data.encryptedBlobUri,
    uri: data.uri
  };
}

/**
 * Check if an image hash is already registered
 */
async function isImageRegistered(imageHash) {
  const tindart = getContract();
  return tindart.isImageRegistered(imageHash);
}

/**
 * Get total supply
 */
async function totalSupply() {
  const tindart = getContract();
  return Number(await tindart.totalSupply());
}

module.exports = {
  mint,
  isOwner,
  getTokenData,
  isImageRegistered,
  totalSupply
};
